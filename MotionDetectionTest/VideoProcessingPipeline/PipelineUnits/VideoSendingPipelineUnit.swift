//
//  VideoSendingPipelineUnit.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 05/02/2021.
//

import Foundation
import CoreImage

class VideoSendingPipelineUnit: VideoPipelineUnit {
    override var resultQueue: DispatchQueue? {
        resultReceiver?.workingQueue
    }

    private(set) weak var resultReceiver:  VideoFrameReceiver?

    convenience init(workingQueue: DispatchQueue) {
        self.init(isActive: false, workingQueue: workingQueue, resultReceiver: nil)
    }

    init(isActive: Bool = false, workingQueue: DispatchQueue? = nil, resultReceiver: VideoFrameReceiver? = nil) {
        self.resultReceiver = resultReceiver
        super.init(isActive: isActive, workingQueue: workingQueue, resultQueue: resultReceiver?.workingQueue)
    }

    final func changeReceiver(to receiver: VideoFrameReceiver, andActivate: Bool = true) {
        self.resultReceiver = receiver
        if andActivate {
            activate()
        } else {
            deactivate()
        }
    }

    final func propagateResult(image: CIImage?) {
        runOnResult { [unowned self] in
            guard let receiver = self.resultReceiver else {
                throw VideoPipelineError.noReceiver
            }
            guard let outImage = image else {
                throw VideoPipelineError.noFrame
            }
            receiver.didReceive(frame: outImage)
        }
    }
}
