//
//  ViewController.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 19/12/2020.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, VideoFrameReceiver {
    let workingQueue: DispatchQueue? = DispatchQueue.main

    // This shows live camera preview
    @IBOutlet var previewView: CapturePreviewView!
    // This shows processed frames
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var stopButton: UIButton!

    private var previewLayer: AVCaptureVideoPreviewLayer {
        self.previewView.layer as! AVCaptureVideoPreviewLayer
    }
    private var videoPipeline: VideoProcessingPipeline!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.imageView.alpha = 0.5
        self.videoPipeline = VideoProcessingPipeline(finalReceiver: self)

        // here we change how our processing pipeline will look like
        // and what it does
        self.videoPipeline.apply(configuration: .full(source: .live))

        videoPipeline.prepareForAcquisition() { (captureSession) in
            guard let captureSession = captureSession else {
                self.videoPipeline.start()
                return
            }
            let videoLayer = (self.previewView.layer as! AVCaptureVideoPreviewLayer)

            videoLayer.session = captureSession
            // You use the videoGravity property to influence how content is viewed relative to the layer bounds;
            // in this case setting it to full the screen while respecting the aspect ratio.
            videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            self.videoPipeline.start()
            self.updatePreviewLayer(layer: videoLayer.connection!, orientation: .landscapeRight)
        }
    }

    @IBAction func stopButtonPressed(_ sender: Any) {
        videoPipeline.stop()
    }

    // This method of outputting results is 🐌 as fuck
    // I think that most of the delay visible on screen is caused by the this
    // not by processing
    func didReceive(frame inBuffer: CIImage) {
        imageView.image = UIImage(ciImage: inBuffer)
    }

    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        previewLayer.frame = self.view.bounds
    }
}

