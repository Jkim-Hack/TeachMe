//
//  CameraViewController.swift
//  TeachMe
//
//  Created by John Kim on 11/13/20.
//

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {

    @IBOutlet weak var recordButton: RecordButton!
    @IBOutlet weak var timerLabel: UILabel!
    
    private var counter = 0.0
    private var timer = Timer()
    private var isPlaying = false
    private var isStartRecording = false
    private var isRecording = false
    private var isDoneRecording = false
    private var hasStartedTimer = false
    private var isHolding = false
    private var isDetecting = false

    private var cameraView: CameraView { view as! CameraView }
    
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive) // Output thread
    private var cameraFeedSession: AVCaptureSession?    // Capture session
    private var handPoseRequest = VNDetectHumanHandPoseRequest()    // Hand pose stuff
    
    private let drawOverlay = CAShapeLayer()    // Overlay for drawing WILL NOT NEED FOR NOW
    private let drawPath = UIBezierPath()   // Draw path for drawing
    private var evidenceBuffer = [HandGestureProcessor.HandPoints]() // Used for confidence of hand detection
    private var lastDrawPoint: CGPoint?
    private var isFirstSegment = true
    private var lastObservationTimestamp = Date()
    
    private var gestureProcessor = HandGestureProcessor()
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var currentFilename = ""
    private var adapter: AVAssetWriterInputPixelBufferAdaptor?
    private var time: CMTime?
    
    private var startTimestamp: CMTime?
    private var startDetectTimestamp: CMTime?
    typealias Timestamp = (start: CMTime, end: CMTime)
    
    private var allDetectedTimestamps = [Timestamp]()
    private var detected = [Double : [Double : [CGPoint]]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.addSublayer(drawOverlay)
        // Detect two hands for dual hand detection
        handPoseRequest.maximumHandCount = 2
        // Add state change handler to hand gesture processor.
        gestureProcessor.didChangeStateClosure = { [weak self] state in
            self?.handleGestureStateChange(state: state)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                AppUtility.lockOrientation(.landscapeRight)
                cameraView.previewLayer.videoGravity = .resizeAspectFill
                try setupAVSession()
                cameraView.previewLayer.session = cameraFeedSession
                cameraView.previewLayer.connection?.videoOrientation = .landscapeRight
            }
            cameraFeedSession?.startRunning()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    func setupAVSession() throws {
        // Select a front facing camera, make an input.
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high
        
        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        let movieOutput = AVCaptureMovieFileOutput()
        
        if session.canAddOutput(dataOutput) && session.canAddOutput(movieOutput) {
            session.addOutput(dataOutput)

            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            
            
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video or movie data output to the session")
        }
        session.commitConfiguration()
        cameraFeedSession = session
}
    
    func processPoints(thumb: [CGPoint]?, index: [CGPoint]?, middle: [CGPoint]?, ring: [CGPoint]?, little: [CGPoint]?) {
        // Check that we have both points.
        guard let thumb = thumb, let index = index, let middle = middle, let ring = ring, let little = little else {
            // If there were no observations for more than 2 seconds reset gesture processor.
            if Date().timeIntervalSince(lastObservationTimestamp) > 2 {
                gestureProcessor.reset()
            }
            cameraView.showPoints([], color: .clear)
            return
        }
        
        var thumbPoints = [CGPoint]()
        var indexPoints = [CGPoint]()
        var middlePoints = [CGPoint]()
        var ringPoints =  [CGPoint]()
        var littlePoints = [CGPoint]()
        
        // Convert points from AVFoundation coordinates to UIKit coordinates.
        let previewLayer = cameraView.previewLayer
      
        for point in thumb {
            let thumbPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: point)
            thumbPoints.append(thumbPointConverted)
        }
        for point in index {
            let indexPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: point)
            indexPoints.append(indexPointConverted)
        }
        for point in middle {
            let middlePointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: point)
            middlePoints.append(middlePointConverted)
        }
        for point in ring {
            let ringPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: point)
            ringPoints.append(ringPointConverted)
        }
        for point in little {
            let littlePointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: point)
            littlePoints.append(littlePointConverted)
        }
        
        // Process new points
        gestureProcessor.processPoints((thumbPoints, indexPoints, middlePoints, ringPoints, littlePoints))
    }
    
    
    private func handleGestureStateChange(state: HandGestureProcessor.State) {
        let points = gestureProcessor.lastProcessedHandPoints
        var tipsColor: UIColor
        var pointGroup = [CGPoint]()
        pointGroup.append(contentsOf: points.thumb!)
        pointGroup.append(contentsOf: points.index!)
        pointGroup.append(contentsOf: points.middle!)
        pointGroup.append(contentsOf: points.ring!)
        pointGroup.append(contentsOf: points.little!)
        
        switch state {
        case .possibleOpenPalm, .possibleSidePalm:
            tipsColor = .orange
            if hasStartedTimer && (isDetecting || isHolding) {
                let timestamp = self.time! - self.startDetectTimestamp! - self.startTimestamp!
                if timestamp.seconds.remainder(dividingBy: 0.2) <= 0.02 {
                    print("DETECTED")
                    detected[startDetectTimestamp!.seconds] = [timestamp.seconds: pointGroup]
                }
            }
        case .openPalm:
            tipsColor = .green
            if !hasStartedTimer && isRecording {
                startTimer()
            } else if hasStartedTimer && isRecording {
                if counter < 3 && counter > 0 && !isHolding {
                    self.isHolding = true
                    self.timerLabel.textColor = UIColor.white
                    self.timerLabel.text = "Hold!"
                    self.timerLabel.backgroundColor = UIColor.orange
                    startDetectTimestamp = self.time! - self.startTimestamp!
                } else if counter > 3 && !isDetecting {
                    self.isDetecting = true
                    self.isHolding = false
                    self.timerLabel.textColor = UIColor.white
                    self.timerLabel.text = "Good!"
                    self.timerLabel.backgroundColor = UIColor.green
                    
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseOut, animations: {
                            self.timerLabel.alpha = 0.0
                        }, completion: { (finished: Bool) in
                            self.counter = 0.0
                            self.timerLabel.alpha = 1.0
                            self.timerLabel.isHidden = true
                        })
                    }
                }
                if isHolding || isDetecting {
                    let timestamp = self.time! - self.startDetectTimestamp! - self.startTimestamp!
                    if timestamp.seconds.remainder(dividingBy: 0.2) <= 0.02 {
                        print("DETECTED")
                        detected[startDetectTimestamp!.seconds] = [timestamp.seconds: pointGroup]
                    }
                }
            }
        case .sidePalm:
            tipsColor = .green
            if !hasStartedTimer && isRecording {
                startTimer()
            } else if hasStartedTimer && isRecording && !isHolding && !isDetecting {
                if counter < 3 && counter > 0 && !isHolding {
                    self.isHolding = true
                    self.timerLabel.textColor = UIColor.white
                    self.timerLabel.text = "Hold!"
                    self.timerLabel.backgroundColor = UIColor.orange
                    startDetectTimestamp = self.time! - self.startTimestamp!
                } else if counter > 3 && !isDetecting {
                    self.isDetecting = true
                    self.isHolding = false
                    self.timerLabel.textColor = UIColor.white
                    self.timerLabel.text = "Good!"
                    self.timerLabel.backgroundColor = UIColor.green
                    
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseOut, animations: {
                            self.timerLabel.alpha = 0.0
                        }, completion: { (finished: Bool) in
                            self.counter = 0.0
                            self.timerLabel.alpha = 1.0
                            self.timerLabel.isHidden = true
                        })
                    }
                }
                if isHolding || isDetecting {
                    let timestamp = self.time! - self.startDetectTimestamp! - self.startTimestamp!
                    if timestamp.seconds.remainder(dividingBy: 0.50) == 0 {
                        detected[startDetectTimestamp!.seconds] = [timestamp.seconds: pointGroup]
                    }
                }
            }
        case .unknown:
            tipsColor = .red
            if hasStartedTimer && isRecording {
                if isHolding && !isDetecting {
                    isHolding = false
                    self.timerLabel.text = "Failed!"
                    self.timerLabel.backgroundColor = UIColor.red
                    if detected[startDetectTimestamp!.seconds] != nil {
                        detected.remove(at: detected.index(forKey: startDetectTimestamp!.seconds)!)
                    }
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseOut, animations: {
                            self.timerLabel.alpha = 0.0
                        }, completion: { (finished: Bool) in
                            self.counter = 0.0
                            self.timerLabel.alpha = 1.0
                            self.timerLabel.isHidden = true
                        })
                    }
                    stopTimer()
                } else if isDetecting {
                    stopTimer()
                    let timestamp = Timestamp(start: startDetectTimestamp!, end: self.time! - self.startTimestamp!)
                    allDetectedTimestamps.append(timestamp)
                    isDetecting = false
                    isHolding = false
                }
            }
        }
        cameraView.showPoints(pointGroup, color: tipsColor)
    }
 
    @IBAction func handleRecord() {
        if !isRecording {
            recordButton.cornerRadiusChangeAnimation(reverse: false)
            startRecording()
        } else {
            recordButton.cornerRadiusChangeAnimation(reverse: true)
            isDetecting = false
            isHolding = false
            timerLabel.isHidden = true
            stopRecording()
        }
    }
    
    func startRecording() {
        print("Starting recording")
        isStartRecording = true
    }
    
    func stopRecording() {
        isRecording = false
        isDoneRecording = true
    }
 
    func startTimer() {
        if(isHolding) {
            return
        }
        hasStartedTimer = true
        timerLabel.isHidden = false
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateTimer), userInfo: nil, repeats: true)
    }
    
    func stopTimer() {
        hasStartedTimer = false
        timer.invalidate()
    }
    
    @objc func updateTimer() {
        counter = counter + 0.1
    }
    
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        connection.videoOrientation = .landscapeRight
        var thumb: [CGPoint]?
        var index: [CGPoint]?
        var middle: [CGPoint]?
        var ring: [CGPoint]?
        var little: [CGPoint]?
       
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        self.time = CMTime(seconds: timestamp, preferredTimescale: CMTimeScale(600))
        if isStartRecording {
            print("-------START RECORDING-------")
            let filename = UUID().uuidString
            let filePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(filename).mov")
            let writer = try! AVAssetWriter(outputURL: filePath, fileType: .mov)
            let output = cameraFeedSession?.outputs[0] as! AVCaptureVideoDataOutput
            let settings = output.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            
            input.mediaTimeScale = CMTimeScale(bitPattern: 600)
            input.expectsMediaDataInRealTime = true
            input.transform = CGAffineTransform(rotationAngle: .pi/2)
            let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
            if writer.canAdd(input) {
                writer.add(input)
            }
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            assetWriter = writer
            assetWriterInput = input
            self.adapter = adapter
            currentFilename = filename
            isRecording = true
            isStartRecording = false
            isDoneRecording = false
            startTimestamp = CMTime(seconds: timestamp, preferredTimescale: CMTimeScale(600))
        } else if isRecording {
            print("-------RECORDING-------")
            if assetWriterInput?.isReadyForMoreMediaData == true {
                let time = self.time! - self.startTimestamp!
                self.adapter?.append(CMSampleBufferGetImageBuffer(sampleBuffer)!, withPresentationTime: time)
            }
        } else if isDoneRecording {
            print("-------DONE RECORDING-------")
            guard assetWriterInput?.isReadyForMoreMediaData == true, assetWriter!.status != .failed else {
                print("-------FAILED RECORDING-------")
                return
            }
            isRecording = false
            isDoneRecording = false
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(currentFilename).mov")
            assetWriterInput?.markAsFinished()
            assetWriter?.finishWriting {
                print(url.relativePath)
                /*
                for timeStamp in self.allDetectedTimestamps {
                    print("Detected at: start: \(timeStamp.start.seconds)" + ", " + "end: \(timeStamp.end.seconds)")
                }
                */
                for detect in self.detected {
                    print("Detected: \(detect)")
                }
                print(self.detected.count)
                print(self.allDetectedTimestamps.count)
            }
        }
        
        defer {
            DispatchQueue.main.sync {
                self.processPoints(thumb: thumb, index: index, middle: middle, ring: ring, little: little)
            }
        }

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first else {
                return
            }
            // Get points for thumb and index finger.
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let indexPoints = try observation.recognizedPoints(.indexFinger)
            let middlePoints = try observation.recognizedPoints(.middleFinger)
            let ringPoints = try observation.recognizedPoints(.ringFinger)
            let littlePoints = try observation.recognizedPoints(.littleFinger)
         
         
            // Checks to make sure every point is recognized
            guard let thumbTip = thumbPoints[.thumbTip], let thumbIP = thumbPoints[.thumbIP], let thumbMP = thumbPoints[.thumbMP], let thumbCMC = thumbPoints[.thumbCMC], let indexTip = indexPoints[.indexTip], let indexDip = indexPoints[.indexDIP], let indexPIP = indexPoints[.indexPIP], let indexMCP = indexPoints[.indexMCP], let middleTip = middlePoints[.middleTip], let middleDip = middlePoints[.middleDIP], let middlePIP = middlePoints[.middlePIP], let middleMCP = middlePoints[.middleMCP],let littleTip = littlePoints[.littleTip], let littleDip = littlePoints[.littleDIP], let littlePIP = littlePoints[.littlePIP], let littleMCP = littlePoints[.littleMCP], let ringTip = ringPoints[.ringTip], let ringDip = ringPoints[.ringDIP], let ringPIP = ringPoints[.ringPIP], let ringMCP = ringPoints[.ringMCP] else {
                
                if isHolding {
                    if detected[startDetectTimestamp!.seconds] != nil {
                        detected.remove(at: detected.index(forKey: startDetectTimestamp!.seconds)!)
                    }
                    isHolding = false
                }
                
                if isDetecting {
                    stopTimer()
                    let timestamp = Timestamp(start: startDetectTimestamp!, end: self.time! - self.startTimestamp!)
                    allDetectedTimestamps.append(timestamp)
                    isDetecting = false
                    isHolding = false
                }
                return
            }
            
            // Must be more than 30% accurate
            guard thumbTip.confidence > 0.3 && thumbIP.confidence > 0.3 && thumbMP.confidence > 0.3 && thumbCMC.confidence > 0.3 && indexTip.confidence > 0.3 && indexDip.confidence > 0.3 && indexPIP.confidence > 0.3 && indexMCP.confidence > 0.3 && middleTip.confidence > 0.3 && middleDip.confidence > 0.3 && middlePIP.confidence > 0.3 && middleMCP.confidence > 0.3 && ringTip.confidence > 0.3 && ringDip.confidence > 0.3 && ringPIP.confidence > 0.3 && ringMCP.confidence > 0.3 && littleTip.confidence > 0.3 && littleDip.confidence > 0.3 && littlePIP.confidence > 0.3 && littleMCP.confidence > 0.3 else {
                
                if isHolding {
                    if detected[startDetectTimestamp!.seconds] != nil {
                        detected.remove(at: detected.index(forKey: startDetectTimestamp!.seconds)!)
                    }
                    isHolding = false
                }
                
                if isDetecting {
                    stopTimer()
                    let timestamp = Timestamp(start: startDetectTimestamp!, end: self.time! - self.startTimestamp!)
                    allDetectedTimestamps.append(timestamp)
                    isDetecting = false
                    isHolding = false
                }
                return
            }
            
            thumb = []
            index = []
            middle = []
            ring = []
            little = []
            
            for point in thumbPoints {
                thumb?.append(CGPoint(x: 1-point.value.location.x, y: point.value.location.y))
            }
            for point in indexPoints {
                index?.append(CGPoint(x: 1-point.value.location.x, y: point.value.location.y))
            }
            for point in middlePoints {
                middle?.append(CGPoint(x: 1-point.value.location.x, y: point.value.location.y))
            }
            for point in ringPoints {
                ring?.append(CGPoint(x: 1-point.value.location.x, y: point.value.location.y))
            }
            for point in littlePoints {
                little?.append(CGPoint(x: 1-point.value.location.x, y: point.value.location.y))
            }
            
        } catch {
            cameraFeedSession?.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }
}


