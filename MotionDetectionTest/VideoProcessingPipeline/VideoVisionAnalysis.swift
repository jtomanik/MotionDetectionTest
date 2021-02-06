//
//  VideoVisionAnalysis.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 27/12/2020.
//

import Foundation
import Vision
import CoreImage

/// VNGenerateOpticalFlowRequest easily runs at ~ 10Hz on the device, with current shitty code
/// Looks like VNTranslationalImageRegistrationRequest is not worth the performance slump as camera movements can be picked up by the accelerometer as well
class VideoVisionAnalysis: VideoReceivingPipelineUnit {
    private var previousBuffer: CIImage?
    private var textureCache: CVMetalTextureCache?
    private let requestHandler = VNSequenceRequestHandler()

    override func handle(frame: CIImage) throws -> CIImage {
        whenBusy = .dropFrame

        guard let previousBuffer = self.previousBuffer else {
            self.previousBuffer = frame
            throw VideoPipelineError.noFrame
        }

        defer {
            self.previousBuffer = frame
        }

        let opticalFlowRequest = VNGenerateOpticalFlowRequest(targetedCIImage: frame, options: [:])
        // disabling translation
//        let translationRequest = VNTranslationalImageRegistrationRequest(targetedCIImage: frame, options: [:])

        try requestHandler.perform([opticalFlowRequest], on: previousBuffer)

        guard
            let opticalFlowResults = opticalFlowRequest.results,
//            let translationResults = translationRequest.results,
            let opticalFlowData = opticalFlowResults.first as? VNPixelBufferObservation
//            let translationData = translationResults.first as? VNImageTranslationAlignmentObservation
        else { throw VideoPipelineError.noFrame }

        let adjustedObservation = adjust(opticalFlow: opticalFlowData, translation: CGAffineTransform.identity)//translationData.alignmentTransform)
        let result = CIImage(cvPixelBuffer: adjustedObservation)
        return result
    }

    // this slows everything down 4 times!
    private func adjust(opticalFlow: VNPixelBufferObservation, translation: CGAffineTransform) -> CVPixelBuffer {
        guard !translation.isIdentity else { return opticalFlow.pixelBuffer }
        let opticalFlowDataMap: CVPixelBuffer = opticalFlow.pixelBuffer
        let width = CVPixelBufferGetWidth(opticalFlowDataMap)
        let height = CVPixelBufferGetHeight(opticalFlowDataMap)
        let lock = CVPixelBufferLockFlags(rawValue: 0)
        CVPixelBufferLockBaseAddress(opticalFlowDataMap, lock)
        guard let baseAddress = CVPixelBufferGetBaseAddress(opticalFlowDataMap) else {
            return opticalFlow.pixelBuffer
        }
        assert(kCVPixelFormatType_TwoComponent32Float == CVPixelBufferGetPixelFormatType(opticalFlowDataMap))
        let rawFlowData = baseAddress.assumingMemoryBound(to: Float32.self)

        for y in 0 ..< height {
            for x in 0 ..< width {
                rawFlowData[y * width * 2 + x * 2] += Float32(translation.tx)
                rawFlowData[y * width * 2 + x * 2 + 1] += Float32(translation.ty)
            }
        }
        CVPixelBufferUnlockBaseAddress(opticalFlowDataMap, lock)
        return opticalFlow.pixelBuffer
    }
}
