//
//  VIdeoEditController.swift
//  TeachMe
//
//  Created by John Kim on 11/14/20.
//

import UIKit
import AVKit
import FloatingPanel
import SpriteKit
import ABVideoRangeSlider_SWIFT_5

class VideoEditController : UIViewController, UIScrollViewDelegate, FloatingPanelControllerDelegate {
    
    @IBOutlet weak var videoView: VideoView!
    @IBOutlet weak var videoRangeSlider: ABVideoRangeSlider!
    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    
    var isPlaying = false
    var isPaused = true
    var isHolding = false
    
    var fpc: FloatingPanelController!
    
    var videoUrl: URL!
    typealias Timestamp = (start: CMTime, end: CMTime)
    var allDetectedTimestamps = [Timestamp]()
    var detected = [Double : [Double : CGPoint]]()
    
    private var player: AVPlayer!
    private var playerLayer: AVPlayerLayer!
    private var videoDuration: Double!
    
    private var widgetAnimationsStandBy = [UIViewPropertyAnimator]()
    private var widgetAnimationsActive = [UIViewPropertyAnimator]()

    private var imageLayer: CALayer!
    private var videoLayer: CALayer!
    
    private var export: AVAssetExportSession!
    
    private var numberImages = [UIImage]()
    
    private var videoName = String()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fpc = FloatingPanelController()
        fpc.delegate = self
        fpc.addPanel(toParent: self)
        fpc.hide()

        for i in 1 ..< 11 {
            guard let image = UIImage(named: "\(i)") else {
                continue
            }
            numberImages.append(image)
        }
        //setupImages(numberImages)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let url = videoUrl else {
            return
        }
        self.videoView.bringSubviewToFront(videoRangeSlider)
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = videoView.frame
        videoView.layer.addSublayer(playerLayer)

        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main, using: { (time) in
            self.videoRangeSlider.updateProgressIndicator(seconds: time.seconds)
        })
        
        setupVideoEdit()
        
        videoRangeSlider.setVideoURL(videoURL: url)
        // Set the delegate
        videoRangeSlider.delegate = self
        videoRangeSlider.showProgressIndicator()
        
        let pan = UIPanGestureRecognizer.init(target: self, action: #selector(handlePan(recognizer:)))
        videoRangeSlider.addGestureRecognizer(pan)
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    @objc func handlePan(recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                isHolding = true
            case .cancelled:
                isHolding = false
            case .ended:
                isHolding = false
            default: break
        }
    }
    
    private func play() {
        isPlaying = true
        isPaused = false
        player.play()
        self.videoView.bringSubviewToFront(videoRangeSlider)
        let timing = UICubicTimingParameters(animationCurve: .linear)
        for animation in widgetAnimationsActive {
            animation.continueAnimation(withTimingParameters: timing, durationFactor: 1)
        }
    }
    
    private func pause() {
        isPlaying = false
        isPaused = true
        player.pause()
        for animation in widgetAnimationsActive {
            animation.pauseAnimation()
        }
    }
    
    /*
    private func setupImages(_ images: [UIImage]){

        for i in 0..<images.count {
            let imageView = UIImageView()
            imageView.image = images[i]
            let xPosition = UIScreen.main.bounds.width * CGFloat(i)
            imageView.frame = CGRect(x: xPosition, y: 0, width: widgetsArea.frame.width, height: widgetsArea.frame.height)
            imageView.contentMode = .scaleAspectFit

            widgetsArea.contentSize.width = widgetsArea.frame.width * CGFloat(i + 1)
            widgetsArea.addSubview(imageView)
            widgetsArea.delegate = self
        }
    }
 */
    
    @IBAction func handlePlayButton() {
        if isPlaying {
            playButton.setBackgroundImage(UIImage(systemName: "pause.fill"), for: UIControl.State.selected)
            pause()
        } else {
            playButton.setBackgroundImage(UIImage(systemName: "play.fill"), for: UIControl.State.selected)
            play()
        }
    }
    
    @IBAction func handleDoneButton() {
        export.exportAsynchronously {
          DispatchQueue.main.async {
            switch self.export.status {
            case .completed: break
                
            default:
              print("Something went wrong during export.")
                print(self.export.error ?? "unknown error")
              break
            }
          }
        }
    }
    
    private func setupVideoEdit() {
        let asset = AVURLAsset(url: videoUrl)
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let assetTrack = asset.tracks(withMediaType: .video).first else {
            return
        }
        
        do {
            let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            self.videoDuration = asset.duration.seconds
            try compositionTrack.insertTimeRange(timeRange, of: assetTrack, at: .zero)
        } catch {
            print(error)
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first else {
            return
        }

        let transformedVideoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let videoIsPortrait = abs(transformedVideoSize.width) < abs(transformedVideoSize.height)
        
        compositionTrack.preferredTransform = assetTrack.preferredTransform
        let videoInfo = orientation(from: assetTrack.preferredTransform)
        
        let videoSize: CGSize
        if videoInfo.isPortrait {
          videoSize = CGSize(
            width: assetTrack.naturalSize.height,
            height: assetTrack.naturalSize.width)
        } else {
          videoSize = assetTrack.naturalSize
        }
        
        print(videoInfo.isPortrait)
        
        videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
        
        imageLayer = CALayer()
        imageLayer.frame = CGRect(origin: .zero, size: videoSize)
        // Add images here
        for i in 0..<allDetectedTimestamps.count {
            let animator = addInsertSection(points: detected[allDetectedTimestamps[i].start.seconds]!, start: allDetectedTimestamps[i].start.seconds, end: allDetectedTimestamps[i].end.seconds, to: imageLayer)
            widgetAnimationsStandBy.insert(animator, at: i)
            animator.addCompletion { position in
                if position == .end {
                    self.widgetAnimationsActive.remove(at: i)
                }
            }
        }
        
        let outputLayer = CALayer()
        outputLayer.frame = CGRect(origin: .zero, size: videoSize)
        outputLayer.addSublayer(videoLayer)
        outputLayer.addSublayer(imageLayer)
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 60)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: outputLayer)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        videoComposition.instructions = [instruction]
        
        let layerInstruction = compositionLayerInstruction(
          for: compositionTrack,
          assetTrack: assetTrack)
        instruction.layerInstructions = [layerInstruction]
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Cannot create export session.")
            return
        }
        
        export = exportSession
        videoName = UUID().uuidString
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory())
          .appendingPathComponent(videoName)
          .appendingPathExtension("mov")
        
        export.videoComposition = videoComposition
        export.outputFileType = .mov
        export.outputURL = exportURL
    }
    
    private func addInsertSection(points: [Double: CGPoint], start: Double, end: Double, to layer: CALayer) -> UIViewPropertyAnimator {
        let imageView = UIImageView()
        let duration = end - start

        imageView.frame = CGRect(origin: points.first!.value, size: CGSize(width: 100, height: 100))
        imageView.layer.borderWidth = 10
        imageView.layer.borderColor = UIColor.yellow.cgColor
        //imageView.isHidden = true
        
        let animator = UIViewPropertyAnimator(duration: duration, curve: .linear)
            UIView.animateKeyframes(withDuration: duration, delay: 0, options: [.beginFromCurrentState], animations: {
                for point in points {
                    UIView.addKeyframe(withRelativeStartTime: point.key - start, relativeDuration: 0.1) {
                        imageView.center = point.value
                    }
                }
            })
        return animator
    }
    
    private func compositionLayerInstruction(for track: AVCompositionTrack, assetTrack: AVAssetTrack) -> AVMutableVideoCompositionLayerInstruction {
      let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
      let transform = assetTrack.preferredTransform
      
      instruction.setTransform(transform, at: .zero)
      
      return instruction
    }
    
    private func orientation(from transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
      var assetOrientation = UIImage.Orientation.up
      var isPortrait = false
      if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
        assetOrientation = .right
        isPortrait = true
      } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
        assetOrientation = .left
        isPortrait = true
      } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
        assetOrientation = .up
      } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
        assetOrientation = .down
      }
      
      return (assetOrientation, isPortrait)
    }
    
    private func exportVideo() {
        export.exportAsynchronously {
          DispatchQueue.main.async {
            switch self.export.status {
            case .completed: break
                // Add on completed
            default:
              print("Something went wrong during export.")
                print(self.export.error ?? "unknown error")
              break
            }
          }
        }
    }
}

extension VideoEditController: ABVideoRangeSliderDelegate {
    func didChangeValue(videoRangeSlider: ABVideoRangeSlider, startTime: Float64, endTime: Float64) {
        return
    }
    
  
    func indicatorDidChangePosition(videoRangeSlider: ABVideoRangeSlider, position: Float64) {
        let currentTime = position
        if (isHolding) {
            self.player.seek(to: CMTime(seconds: position, preferredTimescale: 1))
        }
        for i in 0..<allDetectedTimestamps.count {
            if allDetectedTimestamps[i].start.seconds >= currentTime && currentTime <= allDetectedTimestamps[i].end.seconds {
                if !widgetAnimationsStandBy[i].isRunning {
                    widgetAnimationsActive.insert(widgetAnimationsStandBy[i], at: i)
                    widgetAnimationsStandBy[i].startAnimation()
                }
            }
        }
    }
}
