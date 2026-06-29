//
//  Coordinator.swift
//  ToDo.UDF.MVVM
//

import Foundation

@MainActor
protocol Coordinator: AnyObject {
    func handle(_ effect: CoordinatorEffect)
}

enum CoordinatorEffect: Equatable {
    case finishCreated
    case createTaskRequested
}
