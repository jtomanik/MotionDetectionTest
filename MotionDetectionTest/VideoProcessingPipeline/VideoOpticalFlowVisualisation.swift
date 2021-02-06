//
//  VideoOpticalFlowVisualisation.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 27/12/2020.
//

import Foundation
import CoreImage

class VideoOpticalFlowVisualisation: VideoReceivingPipelineUnit {
    let filter = OpticalFlowVisualizerFilter()

    override func handle(frame: CIImage) throws -> CIImage {
        filter.inputImage = frame
        guard let outImage = self.filter.outputImage else {
            throw VideoPipelineError.noFrame
        }
        return outImage
    }
}
