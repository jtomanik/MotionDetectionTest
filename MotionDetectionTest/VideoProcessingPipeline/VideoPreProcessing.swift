//
//  VideoPreProcessing.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 27/12/2020.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMedia

fileprivate typealias ImageFilterCallback = (CIImage) -> (CIImage?)

class VideoPreProcessing: VideoReceivingPipelineUnit {

    private let filters: [ImageFilterCallback]

    override init(isActive: Bool, workingQueue: DispatchQueue? = nil, resultReceiver:  VideoFrameReceiver? = nil) {
        self.filters = Self.makeFilters()
        super.init(isActive: isActive, workingQueue: workingQueue, resultReceiver: resultReceiver)
    }

    private static func makeFilters() -> [ImageFilterCallback] {
        let lanczos =  CIFilter.lanczosScaleTransform()
        let morphology = CIFilter.morphologyGradient()
        return [
            { inImage in
                guard inImage.cgImage != nil else { return nil }
                lanczos.inputImage = inImage
                lanczos.scale = inImage.cgImage!.height > 2000 ? 0.25 : 0.5
                let outImage = lanczos.outputImage
                return outImage
            },
            { inImage in
                morphology.inputImage = inImage
                morphology.radius = 2.0
                let outImage = morphology.outputImage
                return outImage
            }
        ]
    }

    override func handle(frame: CIImage) throws -> CIImage {
        let outImage = self.filters.reduce(frame) { (frame, filterCallback) -> CIImage in
            guard let result = filterCallback(frame) else { return frame }
            return result
        }
        return outImage
    }
}
