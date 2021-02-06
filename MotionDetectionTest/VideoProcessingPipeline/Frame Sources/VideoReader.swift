//
//  VideoReader.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 27/01/2021.
//

import Foundation
import AVFoundation
import CoreImage

class VideoReader: RunnablePipelineUnit {
    enum VideoReaderError: PipelineError {
        case errorReadingInputFile
        case errorCreatingReader
        case errorStartingReader
        case errorGeneratingTimestamps

        var description: String {
            switch self {
            case .errorReadingInputFile: return "errorReadingInputFile"
            case .errorCreatingReader: return "errorCreatingReader"
            case .errorStartingReader: return "errorStartingReader"
            case .errorGeneratingTimestamps: return "errorGeneratingTimestamps"
            }
        }
    }

    lazy var documentsPath = Bundle.main.path(forResource: generateFilename(), ofType: "mp4")!
    lazy var videoInputFullFileName = URL(fileURLWithPath: documentsPath)

    private lazy var timer = DispatchSource.makeTimerSource(flags: .strict, queue: self.workingQueue)
    private var videoAsset: AVAsset?
    private var videoTrack: AVAssetTrack?
    private var videoReader: AVAssetReader?
    private var videoReaderOutput: AVAssetReaderOutput?
    private var videoFrameGenerator: AVAssetImageGenerator?

    private var isPlaying = false
    private var frameTimestamps: [CMTime] = []
    private var currentFrameNumber = 0
    private var lastFramePlaybackTime: CMTime?

    override func createSource() throws -> Any? {
        let videoAsset = AVAsset(url: videoInputFullFileName)
        guard !videoAsset.tracks.isEmpty else {
            throw VideoReaderError.errorReadingInputFile
        }
        let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video)[0]
        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)

        guard
            let videoReader = try? AVAssetReader(asset: videoAsset)
        else {
            throw VideoReaderError.errorCreatingReader
        }

        videoReaderOutput.alwaysCopiesSampleData = false // possibly prevents unnecessary copying?

        if videoReader.canAdd(videoReaderOutput) {
            videoReader.add(videoReaderOutput)
        } else {
            throw VideoReaderError.errorCreatingReader
        }

        let videoFrameGenerator = AVAssetImageGenerator(asset: videoAsset)
        videoFrameGenerator.requestedTimeToleranceAfter =  CMTime.zero
        videoFrameGenerator.requestedTimeToleranceBefore = CMTime.zero
        videoFrameGenerator.maximumSize = .zero
        videoFrameGenerator.appliesPreferredTrackTransform = true

        self.videoAsset = videoAsset
        self.videoTrack = videoTrack
        self.videoReaderOutput = videoReaderOutput
        self.videoReader = videoReader
        self.videoFrameGenerator = videoFrameGenerator
        self.timer.isCancelled
        return nil
    }

    override func startUpSource() throws {
        isPlaying = true
        lastFramePlaybackTime = CMTime(seconds: 0.0, preferredTimescale: 600)
        runOnWorking { [unowned self] in
            self.frameTimestamps = try self.generateFrameTimestamps()
            try self.processFrame()
        }
    }

    override func breakDownSource() throws {
        isPlaying = false
    }

    private func processFrame() throws {
        guard
            let videoFrameGenerator = videoFrameGenerator,
            frameTimestamps.count > currentFrameNumber
        else { return }

        let requestedTime = frameTimestamps[currentFrameNumber]
        let delay = TimeInterval(requestedTime.seconds) - TimeInterval(lastFramePlaybackTime?.seconds ?? 0.0)
        runOnWorking(delay: delay) { [unowned self] in
            try self.processFrame()
        }
        var extractedTime = CMTime()
        let image = try videoFrameGenerator.copyCGImage(at: requestedTime, actualTime: &extractedTime)
        // that should throw an error
        guard let lastFramePlaybackTime = lastFramePlaybackTime,
              extractedTime >= lastFramePlaybackTime
        else { return }
        self.lastFramePlaybackTime = extractedTime
        self.currentFrameNumber += 1
        let frame = CIImage(cgImage: image)
        print(frame)
        print(Date())
        propagateResult(image: frame)
    }



    private func generateFilename() -> String {
        return "testvideo"
    }

    private func generateFrameTimestamps() throws -> [CMTime] {
        guard
            let videoReader = videoReader
        else { throw VideoReaderError.errorGeneratingTimestamps }
        videoReader.startReading()
        var timestamps: [CMTime] = []
        while let time = extractFrameTimestamp() {
            timestamps.append(time)
        }
        videoReader.cancelReading()
        return timestamps
    }

    private func extractFrameTimestamp() -> CMTime? {
        guard
            let videoReader = videoReader,
            let videoReaderOutput = videoReaderOutput,
            videoReader.status == .reading,
            let sampleBuffer = videoReaderOutput.copyNextSampleBuffer(),
            CMSampleBufferIsValid(sampleBuffer)
        //            CMSampleBufferGetTotalSampleSize(sampleBuffer) != 0
        else { return nil }

        let frameTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
        return frameTime
    }
}
