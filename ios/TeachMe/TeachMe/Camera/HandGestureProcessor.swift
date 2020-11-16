//
//  HandGestureProcessor.swift
//  TeachMe
//
//  Created by John Kim on 11/13/20.
//

import CoreGraphics

class HandGestureProcessor {
    enum State {
        case possibleOpenPalm
        case openPalm
        case possibleSidePalm
        case sidePalm
        case unknown
    }
    
    typealias HandPoints = (thumb: [CGPoint]?, index: [CGPoint]?, middle: [CGPoint]?, ring: [CGPoint]?, little: [CGPoint]?)
    
    private var state = State.unknown {
        didSet {
            didChangeStateClosure?(state)
        }
    }
    private var openPalmEvidenceCounter = 0
    private var sidePalmEvidenceCounter = 0
    private var generalTolerance: CGFloat
    // private var sidePalmTolerance: CGFloat
    private let evidenceCounterStateTrigger: Int
    
    var didChangeStateClosure: ((State) -> Void)?
    private (set) var lastProcessedHandPoints = HandPoints([.zero], [.zero], [.zero], [.zero], [.zero])
    
    init(generalTolerance: CGFloat = 75, evidenceCounterStateTrigger: Int = 3) {
        self.generalTolerance = generalTolerance
        self.evidenceCounterStateTrigger = evidenceCounterStateTrigger
    }
    
    func reset() {
        state = .unknown
        openPalmEvidenceCounter = 0
        sidePalmEvidenceCounter = 0
    }
    
    func processPoints(_ points: HandPoints) {
        lastProcessedHandPoints = points
        let index = points.index
        let middle = points.middle
        let ring = points.ring
        let little = points.little
        
        guard let indexPoints = index, let middlePoints = middle, let ringPoints = ring, let littlePoints = little else {
            return
        }
        
        var allPoints = [CGPoint]()
        allPoints.append(contentsOf: indexPoints)
        allPoints.append(contentsOf: middlePoints)
        allPoints.append(contentsOf: ringPoints)
        allPoints.append(contentsOf: littlePoints)
        
        let indexCollinear = CGPoint.collinear(p1: indexPoints[1], p2: indexPoints[2], p3: indexPoints[3])
        let middleCollinear = CGPoint.collinear(p1: middlePoints[1], p2: middlePoints[2], p3: middlePoints[3])
        let ringCollinear = CGPoint.collinear(p1: ringPoints[1], p2: ringPoints[2], p3: ringPoints[3])
        let littleCollinear = CGPoint.collinear(p1: littlePoints[1], p2: littlePoints[2], p3: littlePoints[3])
                
        if indexCollinear.inRange(tolerance: generalTolerance) && middleCollinear.inRange(tolerance: generalTolerance) && ringCollinear.inRange(tolerance: generalTolerance) && littleCollinear.inRange(tolerance: generalTolerance) {
            openPalmEvidenceCounter += 1
            sidePalmEvidenceCounter = 0
            state = (openPalmEvidenceCounter >= evidenceCounterStateTrigger) ? .openPalm : .possibleOpenPalm
        } else if littleCollinear.inRange(tolerance: generalTolerance) {
            openPalmEvidenceCounter = 0
            sidePalmEvidenceCounter += 1
            state = (sidePalmEvidenceCounter >= evidenceCounterStateTrigger) ? .sidePalm : .possibleSidePalm
        } else {
            reset()
        }
        
    }
    
}

// MARK: - CGPoint helpers

extension CGPoint {

    static func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
    
    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
    
    static func collinear(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        return 0.5 * (p1.x * (p2.y - p3.y) + p2.x * (p3.y - p1.y) + p3.x * (p1.y - p2.y))
    }
    
    static func isNotIntersecting(points: [CGPoint]) -> Bool {
        for point in points.dropFirst() {
            for i in 1 ..< points.count {
                if abs(point.x - points[i].x) <= 5 && abs(point.y - points[i].y) <= 5 {
                    return false
                }
            }
        }
        return true
    }
    
}

// MARK: CGFloat helpers

extension CGFloat {
    
    func inRange(tolerance: CGFloat) -> Bool {
        return self <= tolerance && self >= -tolerance
    }
    
}
