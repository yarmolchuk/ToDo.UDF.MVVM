//
//  Coordinator.swift
//  ToDo.UDF.MVVM
//
//  Координатор навігації та ефекти, які йому передає ViewModel.
//

import Foundation

@MainActor
protocol Coordinator: AnyObject {
    func handle(_ effect: CoordinatorEffect)
}

enum CoordinatorEffect: Equatable {
    case finishCreated
}
