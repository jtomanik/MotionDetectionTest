//
//  VideoReceivingPipelineUnit.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 05/02/2021.
//

import Foundation
import CoreImage

protocol VideoFrameReceiver: QueueProvider {
    func didReceive(frame inBuffer: CIImage)
}


class VideoReceivingPipelineUnit: VideoSendingPipelineUnit, VideoFrameReceiver {
    enum BusyBehaviour {
        case dropFrame
        case passFrame
    }

    var whenBusy: BusyBehaviour = .passFrame

    private var isBusy = false

    final func didReceive(frame inBuffer: CIImage) {
        guard isBusy == false else {
            logError(VideoPipelineError.unitBusy)
            switch whenBusy {
            case .passFrame:
                logMessage("passed frame")
                propagateResult(image: inBuffer)
            case .dropFrame:
                logMessage("dropped frame")
                break
            }
            return
        }

        let processingStartTime = Date()
        runOnWorking {  [unowned self] in
            if isActive {
                self.isBusy = true
                let result = try self.handle(frame: inBuffer)
                self.propagateResult(image: result)
                self.isBusy = false
                let processingTime = Date().timeIntervalSince(processingStartTime)
                logMessage("was processing for \(processingTime)")
            } else {
                self.propagateResult(image: inBuffer)
            }
        }
    }

    override func handleProcessing(error: Error) {
        isBusy = false
    }

    /// By default this function is running on Working Queue
    func handle(frame: CIImage) throws -> CIImage {
        throw VideoPipelineError.notImplemented
    }
}
