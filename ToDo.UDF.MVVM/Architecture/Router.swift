//
//  Router.swift
//  ToDo.UDF.MVVM
//
//  Навігаційний стек поверх NavigationPath (push/pop/popToRoot).
//

import SwiftUI

@MainActor
@Observable
final class Router {
    var path = NavigationPath()

    func push<R: Hashable>(_ route: R) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path = NavigationPath() }
}
