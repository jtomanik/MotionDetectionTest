//
//  CapturePreviewView.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 19/12/2020.
//

import AVFoundation
import UIKit

class CapturePreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
