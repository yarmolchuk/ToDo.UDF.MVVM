//
//  Coordinator.swift
//  ToDo.UDF.MVVM
//

import Foundation

@MainActor
protocol Coordinator: AnyObject {
    var onComplete: (any Coordinator) -> Void { get }
    func start()
}

enum CoordinatorEffect: Equatable {
    case finishCreated
    case createTaskRequested
    case saveRequested(TaskSummary)
    case dismissForm
}
