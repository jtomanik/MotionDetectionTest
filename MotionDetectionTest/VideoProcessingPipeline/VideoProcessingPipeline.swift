//
//  VideoProcessingPipeline.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 27/12/2020.
//

import Foundation
import AVFoundation

enum VideoSourceConfiguration {
    case live
    case liveWithRecording
    case playback
}

enum PipelineConfiguration {
    case none(source: VideoSourceConfiguration)
    case full(source: VideoSourceConfiguration)
    case onlyPreProcessing(source: VideoSourceConfiguration)
    case onlyOpticalFlow(source: VideoSourceConfiguration)

    var sourceConfiguration: VideoSourceConfiguration {
        switch self {
        case .none(let sourceConfiguration):
            return sourceConfiguration
        case .full(let sourceConfiguration):
            return sourceConfiguration
        case .onlyPreProcessing(let sourceConfiguration):
            return sourceConfiguration
        case .onlyOpticalFlow(let sourceConfiguration):
            return sourceConfiguration
        }
    }
}

struct VideoProcessingPipeline {
    private let finalReceiver: VideoFrameReceiver
    private var configuration: PipelineConfiguration?

    private var capture: VideoCapture!
    private var videoWriter: VideoWriter!
    private var videoReader: VideoReader!
    private var preProcessing: VideoPreProcessing!
    private var opticalAnalysis: VideoVisionAnalysis!
    private var opticalFlowVisualisation: VideoOpticalFlowVisualisation!

    init(finalReceiver: VideoFrameReceiver) {
        self.finalReceiver = finalReceiver
        self.capture = VideoCapture(workingQueue: DispatchQueue(label: "VideoCapture"))
        self.videoWriter = VideoWriter(workingQueue: DispatchQueue(label: "VideoWriter"))
        self.videoReader = VideoReader(workingQueue: DispatchQueue(label: "VideoReader"))
        self.preProcessing = VideoPreProcessing(workingQueue: DispatchQueue(label: "VideoPreProcessing"))
        self.opticalAnalysis = VideoVisionAnalysis(workingQueue: DispatchQueue(label: "VideoVisionAnalysis"))
        self.opticalFlowVisualisation = VideoOpticalFlowVisualisation(workingQueue: DispatchQueue(label: "VideoOpticalFlowVisualisation"), resultReceiver: finalReceiver)
    }

    mutating func apply(configuration: PipelineConfiguration) {
        switch configuration {
        case .none(let sourceConfiguration):
            wireSource(with: sourceConfiguration)
            preProcessing.changeReceiver(to: opticalFlowVisualisation, andActivate: false)
        case .full(let sourceConfiguration):
            wireSource(with: sourceConfiguration)
            preProcessing.changeReceiver(to: opticalAnalysis)
            opticalAnalysis.changeReceiver(to: opticalFlowVisualisation)
            opticalFlowVisualisation.activate()
        case .onlyPreProcessing(let sourceConfiguration):
            wireSource(with: sourceConfiguration)
            preProcessing.changeReceiver(to: opticalFlowVisualisation)
        case .onlyOpticalFlow(let sourceConfiguration):
            wireSource(with: sourceConfiguration)
            preProcessing.changeReceiver(to: opticalAnalysis, andActivate: false)
            opticalAnalysis.changeReceiver(to: opticalFlowVisualisation)
            opticalFlowVisualisation.activate()
        }
        self.configuration = configuration
    }

    private func wireSource(with configuration: VideoSourceConfiguration) {
        switch configuration {
        case .live:
            capture.changeReceiver(to: preProcessing)
        case .liveWithRecording:
            capture.changeReceiver(to: videoWriter)
            videoWriter.changeReceiver(to: preProcessing)
        case .playback:
            videoReader.changeReceiver(to: preProcessing)
        }
    }

    func prepareForAcquisition(completion: @escaping (AVCaptureSession?) -> Void) {
        guard
            let configuration = configuration
        else {
            fatalError("Configuration not present")
        }

        switch configuration.sourceConfiguration {
        case .live:
            capture.create { (object) in
                guard
                    let session = object as? AVCaptureSession
                else { return }

                if let queue = finalReceiver.workingQueue {
                    queue.async {
                        completion(session)
                    }
                } else {
                    completion(session)
                }
            }
        case .liveWithRecording:
            capture.create { (object) in
                guard
                    let session = object as? AVCaptureSession
                else { return }

                videoWriter.create(completion: nil)
                if let queue = finalReceiver.workingQueue {
                    queue.async {
                        completion(session)
                    }
                } else {
                    completion(session)
                }
            }
        case .playback:
            videoReader.create {_ in
                completion(nil)
            }
        }
    }

    func start() {
        guard
            let configuration = configuration?.sourceConfiguration
        else { return }

        switch configuration {
        case .live:
            capture.start()
        case .liveWithRecording:
            capture.start()
            videoWriter.start()
        case .playback:
            videoReader.start()
        }
        print("pipeline started")
    }

    func stop() {
        guard
            let configuration = configuration?.sourceConfiguration
        else { return }

        switch configuration {
        case .live:
            capture.stop()
        case .liveWithRecording:
            capture.start()
            videoWriter.stop()
        case .playback:
            videoReader.stop()
        }
        print("pipeline stopped")
    }
}
