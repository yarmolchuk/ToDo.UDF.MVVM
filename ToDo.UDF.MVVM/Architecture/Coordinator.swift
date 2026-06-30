//
//  Coordinator.swift
//  ToDo.UDF.MVVM
//
//  Generic-ядро координатора (без посилань на presentation-типи застосунку).
//

import Foundation

@MainActor
protocol Coordinator: AnyObject {
    var onComplete: (any Coordinator) -> Void { get }
    func start()
}
