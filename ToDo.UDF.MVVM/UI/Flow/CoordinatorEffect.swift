//
//  CoordinatorEffect.swift
//  ToDo.UDF.MVVM
//
//  Ефекти, які екрани надсилають координатору потоку задач. Належить шару
//  потоку (UI/Flow), а не generic-ядру Architecture — несе presentation-тип TaskSummary.
//

import Foundation

enum CoordinatorEffect: Equatable {
    case finishCreated
    case createTaskRequested
    case saveRequested(TaskSummary)
    case dismissForm
}
