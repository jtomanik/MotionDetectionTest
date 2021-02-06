//
//  VideoCapture.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 19/12/2020.
//

import Foundation
import AVFoundation
import CoreImage

class VideoCapture: RunnablePipelineUnit {
    static let desiredFrameRate = 30
    static let desiredVideoWidth = 3840
    static let desiredVideoHeight = 2160
    
    enum VideoCaptureError: PipelineError {
        case errorCreatingSession
        case errorCreatingDevice
        case errorCreatingDeviceInput
        case errorAddingInput
        case errorAddingOutput
        case sessionIsNotRunning
        case sessionIsRunning

        var description: String {
            switch self {
            case .errorCreatingSession: return "errorCreatingSession"
            case .errorCreatingDevice: return "errorCreatingDevice"
            case .errorCreatingDeviceInput: return "errorCreatingDeviceInput"
            case .errorAddingInput: return "errorAddingInput"
            case .errorAddingOutput: return "errorAddingOutput"
            case .sessionIsNotRunning: return "sessionIsNotRunning"
            case .sessionIsRunning: return "sessionIsRunning"
            }
        }
    }

    private(set) var captureSession: AVCaptureSession!
    private var videoDevice: AVCaptureDevice!
    private var videoConnection: AVCaptureConnection!
    private var videoOutput: AVCaptureOutput!

    override func createSource() throws -> Any? {
        let captureSession = AVCaptureSession()
        try configure(session: captureSession)
        self.captureSession = captureSession
        return captureSession
    }

    override func startUpSource() throws {
        guard !captureSession.isRunning else { throw VideoCaptureError.sessionIsRunning }
        captureSession.startRunning()
    }

    override func breakDownSource() throws {
        guard captureSession.isRunning else { throw VideoCaptureError.sessionIsNotRunning }
        captureSession.stopRunning()
    }

    private func configure(session: AVCaptureSession) throws {
        let videoInput = try createSessionInput()
        let videoOutput = createSessionOutput()

        session.beginConfiguration()
        session.sessionPreset = .inputPriority
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            throw VideoCaptureError.errorAddingInput
        }
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            let connection = videoOutput.connection(with: AVMediaType.video)
            connection?.videoOrientation = .landscapeRight
            connection?.preferredVideoStabilizationMode = .standard
        } else {
            throw VideoCaptureError.errorAddingOutput
        }
        session.commitConfiguration()
    }

    private func createSessionInput() throws -> AVCaptureInput {
        // Obtain access to the physical capture device and associated properties via the AVCaptureDevice
        let deviceType = AVCaptureDevice.DeviceType.builtInUltraWideCamera
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [deviceType], mediaType: .video, position: .back).devices

        guard let captureDevice = devices.first else {
            throw VideoCaptureError.errorCreatingDevice
        }

        try captureDevice.configureDesiredFrameRate(Self.desiredFrameRate)

        // Try and create a AVCaptureDeviceInput (sub-class of AVCaptureInput) to capture data from the camera (captureDevice)
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            throw VideoCaptureError.errorCreatingDeviceInput
        }
        return videoInput
    }

    private func createHDRSessionInput() throws -> AVCaptureInput {
        // Obtain access to the physical capture device and associated properties via the AVCaptureDevice
        let deviceType = AVCaptureDevice.DeviceType.builtInUltraWideCamera
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [deviceType], mediaType: .video, position: .back).devices

        guard
            let captureDevice = devices.first,
            captureDevice.formats.count > 49
        else {
            throw VideoCaptureError.errorCreatingDevice
        }

        try captureDevice.lockForConfiguration()
        captureDevice.activeFormat = captureDevice.formats[49]
        try captureDevice.configureDesiredFrameRate(Self.desiredFrameRate)
        captureDevice.unlockForConfiguration()

        // Try and create a AVCaptureDeviceInput (sub-class of AVCaptureInput) to capture data from the camera (captureDevice)
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            throw VideoCaptureError.errorCreatingDeviceInput
        }
        return videoInput
    }

    private func createSessionOutput() -> AVCaptureOutput {
        let videoOutput = AVCaptureVideoDataOutput()

        // Set pixel type (32bit RGBA, Grayscale etc)
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        ]
//        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: workingQueue)

        return videoOutput
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard
            let image = sampleBuffer.imageBuffer
        else { return }

        logMessage("Frame captured")
        let frame = CIImage(cvImageBuffer: image)
        propagateResult(image: frame)
    }

    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        logMessage("Frame dropped")
    }
}

extension AVCaptureDevice {
    /// http://stackoverflow.com/questions/21612191/set-a-custom-avframeraterange-for-an-avcapturesession#27566730
    func configureDesiredFrameRate(_ desiredFrameRate: Int) throws {
        var isFPSSupported = false
        let videoSupportedFrameRateRanges = activeFormat.videoSupportedFrameRateRanges
        for range in videoSupportedFrameRateRanges {
            if (range.maxFrameRate >= Double(desiredFrameRate) && range.minFrameRate <= Double(desiredFrameRate)) {
                isFPSSupported = true
                break
            }
        }

        if isFPSSupported {
            try lockForConfiguration()
            activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
            activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
            unlockForConfiguration()
        }
    }

}
