//
//  NewTaskProps.swift
//  ToDo.UDF.MVVM
//
//  UDF-стан і події форми створення задачі. Props володіють власними
//  presentation-типами (When/PriorityBadge) — View не знає про модельні енуми.
//  Колір пріоритету — у UI-розширенні (NewTaskView), щоб дані лишались без SwiftUI.
//

import Foundation

extension NewTaskView {
    struct Props: Equatable {
        var title: String
        var notes: String
        var when: When
        var time: Date
        var priority: PriorityBadge
        var isPickingTime: Bool
        var canSave: Bool

        // Власний presentation-тип форми «Коли». VM створює його з TaskWhen.
        enum When: CaseIterable, Equatable {
            case today
            case tomorrow
            case later

            var title: String {
                switch self {
                case .today: "Сьогодні"
                case .tomorrow: "Завтра"
                case .later: "Пізніше"
                }
            }
        }

        // Власний пріоритет форми. VM створює його з TaskPriority і повертає назад на save.
        enum PriorityBadge: Hashable, CaseIterable {
            case low
            case medium
            case high

            init(_ priority: TaskPriority) {
                switch priority {
                case .low: self = .low
                case .medium: self = .medium
                case .high: self = .high
                }
            }

            var domain: TaskPriority {
                switch self {
                case .low: .low
                case .medium: .medium
                case .high: .high
                }
            }

            var title: String {
                switch self {
                case .low: "Низький"
                case .medium: "Середній"
                case .high: "Високий"
                }
            }
        }
    }

    enum SyncEvent: Equatable {
        case titleChanged(String)
        case notesChanged(String)
        case whenChanged(Props.When)
        case timeChanged(Date)
        case priorityChanged(Props.PriorityBadge)
        case timePickerOpened
        case timePickerClosed
        case backTapped
    }

    enum AsyncEvent: Equatable {
        case save
    }
}
