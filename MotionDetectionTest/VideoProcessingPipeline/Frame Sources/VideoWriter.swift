//
//  VideoWriter.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 05/01/2021.
//

import Foundation
import AVFoundation
import VideoToolbox
import CoreImage

class VideoWriter: RunnablePipelineUnit, VideoFrameReceiver {
    static let videoWidth = VideoCapture.desiredVideoWidth
    static let videoHeight = VideoCapture.desiredVideoHeight

    enum VideoWriterError: PipelineError {
        case errorCreatingWriter
        case errorStartingWriter

        var description: String {
            switch self {
            case .errorCreatingWriter: return "errorCreatingWriter"
            case .errorStartingWriter: return "errorStartingWriter"
            }
        }
    }

    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    lazy var videoOutputFullFileName = documentsPath.appendingPathComponent(generateFilename()).appendingPathExtension("mp4")

    private var videoWriterInput: AVAssetWriterInput?
    private var videoWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoWriter: AVAssetWriter?
    private var frameCount: Int64 = 0
    private var lastSampleTime = CMTime.zero

    override func createSource() throws -> Any? {
        guard
            let videoWriter = try? AVAssetWriter(outputURL: videoOutputFullFileName, fileType: AVFileType.mp4)
        else {
            throw VideoWriterError.errorCreatingWriter
        }

        let writerInput = createWriterInput()
        let inputAdapter = createInputAdapter(for: writerInput)

        if videoWriter.canAdd(writerInput) {
            videoWriter.add(writerInput)
        } else {
            throw VideoWriterError.errorCreatingWriter
        }
        self.videoWriter = videoWriter
        self.videoWriterInput = writerInput
        self.videoWriterInputPixelBufferAdaptor = inputAdapter
        return nil
    }

    override func startUpSource() throws {
        guard let videoWriter = videoWriter else { return }

        if videoWriter.startWriting() {
            self.videoWriter?.startSession(atSourceTime: lastSampleTime)
            print("DEBUG:::Have started writting on videoWriter, session at source time: \(self.lastSampleTime)")
        } else {
            throw VideoWriterError.errorStartingWriter
        }
    }

    override func breakDownSource() throws {
        finishRecordVideo()
    }

    final func didReceive(frame inBuffer: CIImage) {
        guard isActive else {
            propagateResult(image: inBuffer)
            return
        }

        runOnWorking {  [unowned self] in
            let result = try self.handle(frame: inBuffer)
            self.propagateResult(image: result)
        }
    }

    private func createWriterInput() -> AVAssetWriterInput {
        let videoOutputSettings = makeVideoSettings()
        let writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings)
        writerInput.expectsMediaDataInRealTime = true
        return writerInput
    }

    private func makeVideoSettings() -> [String:Any] {
        var videoOutputSettings: [String:Any] = [:]
        videoOutputSettings[AVVideoWidthKey] = Self.videoWidth
        videoOutputSettings[AVVideoHeightKey] = Self.videoHeight
        videoOutputSettings[AVVideoCodecKey] = AVVideoCodecType.h264
        videoOutputSettings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey: Self.videoWidth * Self.videoHeight * 10]
        return videoOutputSettings
    }

    private func makeHDRVideoSettings() -> [String:Any] {
        var videoOutputSettings: [String:Any] = [:]
        videoOutputSettings[AVVideoWidthKey] = Self.videoWidth
        videoOutputSettings[AVVideoHeightKey] = Self.videoHeight
        videoOutputSettings[AVVideoColorPropertiesKey] = [
            AVVideoColorPrimariesKey : AVVideoColorPrimaries_ITU_R_2020,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_SMPTE_ST_2084_PQ,
            AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_2020
        ]
        videoOutputSettings[AVVideoCodecKey] = AVVideoCodecType.hevc
        videoOutputSettings[AVVideoCompressionPropertiesKey] = [AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel]
        return videoOutputSettings
    }

    private func createInputAdapter(for input: AVAssetWriterInput) -> AVAssetWriterInputPixelBufferAdaptor {
        let sourcePixelBufferAttributes: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32ARGB),
            String(kCVPixelBufferWidthKey): Self.videoWidth,
            String(kCVPixelBufferHeightKey): Self.videoHeight
        ]

        let adapter = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        return adapter
    }

    private func handle(frame: CIImage) throws -> CIImage {
        guard
            let assetWriterAdapter = videoWriterInputPixelBufferAdaptor,
            assetWriterAdapter.assetWriterInput.isReadyForMoreMediaData,
            let buffer = frame.pixelBuffer
        else { return frame }
        let status = videoWriter?.status ?? .unknown
        print("status on frame: \(status.rawValue)")
        assetWriterAdapter.append(buffer, withPresentationTime: getPresentationTime())
        frameCount += 1
        return frame
    }

    private func getPresentationTime() -> CMTime {
        let fps: Int32 = 30
        let frameDuration = CMTimeMake(value: 1, timescale: fps)
        let lastFrameTime = CMTimeMake(value: self.frameCount, timescale: fps)
        let presentationTime = self.frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
        print("presentation time: \(presentationTime)")
        return presentationTime
    }

    private func finishRecordVideo() {
        guard
            let videoWriterInput = videoWriterInput,
            let videoWriter = videoWriter
        else { return }
        videoWriterInput.markAsFinished()
        videoWriter.finishWriting {
            if videoWriter.status == AVAssetWriter.Status.completed {
                print("DEBUG:::The videoWriter status is completed")
            } else {
                print("WARN:::The videoWriter status is not completed, stauts: \(self.videoWriter!.status)")
            }
        }
    }

    private func generateFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = dateFormatter.string(from: Date())
        return "video-\(dateString)"
    }
}
