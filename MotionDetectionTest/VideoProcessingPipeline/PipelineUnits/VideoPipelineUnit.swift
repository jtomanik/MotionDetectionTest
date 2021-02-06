//
//  VideoPipelineUnit.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 05/02/2021.
//

import Foundation

protocol QueueProvider: AnyObject {
    var workingQueue: DispatchQueue? { get }
}

class VideoPipelineUnit: NSObject, QueueProvider {
    let workingQueue: DispatchQueue?

    private(set) var resultQueue: DispatchQueue?
    private(set) var isActive: Bool

    init(isActive: Bool, workingQueue: DispatchQueue? = nil, resultQueue: DispatchQueue? = nil) {
        self.isActive = isActive
        self.workingQueue = workingQueue
        self.resultQueue = resultQueue
        super.init()
    }

    /// When Unit is active this function executes payload on a working queue if one was defined
    final func runOnWorking(delay: TimeInterval? = nil, payload: @escaping () throws -> ()) {
        let finalDelay = delay ?? 0
        runOn(workingQueue, delay: finalDelay, payload: payload)
    }

    /// When Unit is active this function executes payload on a result queue if one was defined
    final func runOnResult(payload: @escaping () throws -> ()) {
        runOn(resultQueue, delay: 0, payload: payload)
    }

    func handleProcessing(error: Error) {}

    private func runOn(_ queue: DispatchQueue?, delay: TimeInterval, payload: @escaping () throws -> ()) {
        let deadline: DispatchTime = .now() + delay
        if let queue = queue {
            queue.asyncAfter(deadline: deadline) {
                self.execute(payload)
            }
        } else {
            execute(payload)
        }
    }

    private func execute(_ payload: @escaping () throws -> ()) {
        do { try payload() }
        catch {
            handleProcessing(error: error)
            logError(error)
        }
    }

    func activate() {
        isActive = true
    }

    func deactivate() {
        isActive = false
    }

    final func logError(_ error: Error) {
        let pipelineError = error as? PipelineError ?? VideoPipelineError.unknownError(nil)
        print("\(String(describing: self)) error: \(pipelineError)")
    }

    final func logMessage(_ message: String) {
        print("\(String(describing: self)) : \(message)")
    }
}
