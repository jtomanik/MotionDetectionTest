//
//  VideoPipelineError.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 27/12/2020.
//

import Foundation

protocol PipelineError: Error, CustomStringConvertible {}

enum VideoPipelineError: PipelineError {
    case noReceiver
    case noFrame
    case sourceWasNotCreated
    case sourceWasAlreadyCreated
    case unitIsRunning
    case unitIsNotRunning
    case unknownError(String?)
    case notImplemented
    case unitBusy

    var description: String {
        switch self {
        case .noReceiver: return "Receiver for this Unit was not specified"
        case .noFrame: return "Received frame is nil"
        case .sourceWasNotCreated: return "sourceWasNotCreated"
        case .sourceWasAlreadyCreated: return "sourceWasAlreadyCreated"
        case .unitIsRunning: return "unitIsRunning"
        case .unitIsNotRunning: return "unitIsNotRunning"
        case .unknownError(let description): return "unknownError: \(description ?? ""))"
        case .notImplemented: return "notImplemented"
        case .unitBusy: return "unitBusy"
        }
    }
}
