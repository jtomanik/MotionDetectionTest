//
//  RunnablePipelineUnit.swift
//  VisionTest
//
//  Created by Jakub Tomanik on 05/02/2021.
//

import Foundation

class RunnablePipelineUnit: VideoSendingPipelineUnit {
    private(set) var isRunning = false
    private(set) var wasSourceCreated = false

    final func create(completion: ((Any?) -> Void)?) {
        runOnWorking { [unowned self] in
            guard !self.wasSourceCreated else {
                throw VideoPipelineError.sourceWasAlreadyCreated
            }
            let result = try self.createSource()
            completion?(result)
            self.wasSourceCreated = true
        }
    }

    final func start() {
        runOnWorking { [unowned self] in
            guard self.wasSourceCreated else {
                throw VideoPipelineError.sourceWasNotCreated
            }
            guard self.isActive && !self.isRunning else {
                throw VideoPipelineError.unitIsRunning
            }

            try self.startUpSource()
            self.isRunning = true
        }
    }

    final func stop() {
        runOnWorking { [unowned self] in
            guard self.isActive && self.isRunning else {
                throw VideoPipelineError.unitIsNotRunning
            }

            try self.breakDownSource()
            self.isRunning = false
        }
    }

    override func deactivate() {
        stop()
        super.deactivate()
    }

    func createSource() throws -> Any? {
        return nil
    }

    func startUpSource() throws {
    }

    func breakDownSource() throws {
    }
}
