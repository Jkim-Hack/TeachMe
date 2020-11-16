//
//  LandscapeAVPlayerController.swift
//  TeachMe
//
//  Created by John Kim on 11/15/20.
//

import AVKit

class LandscapeAVPlayerController: AVPlayerViewController {

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeRight
    }
}
