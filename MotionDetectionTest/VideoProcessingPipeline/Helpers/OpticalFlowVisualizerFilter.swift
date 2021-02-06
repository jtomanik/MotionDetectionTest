//
//  OpticalFlowVisualizerFilter.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 26/12/2020.
//

import Foundation
import CoreImage

class OpticalFlowVisualizerFilter: CIFilter {
    var inputImage: CIImage?

    let callback: CIKernelROICallback = {
        (index, rect) in
        return rect
    }

    static var kernel: CIKernel = { () -> CIKernel in
        let url = Bundle.main.url(forResource: "OpticalFlowVisualizer",
                                  withExtension: "cikernel")!
        let kernelString = try! String(contentsOf: url)

        return CIKernel(source: kernelString)!
    }()

    override var outputImage : CIImage? {
        get {
            guard let input = inputImage else {return nil}
            return OpticalFlowVisualizerFilter.kernel.apply(extent: input.extent, roiCallback: callback, arguments: [input, 0.0, 100.0, 10.0, 30.0])
        }
    }
}
