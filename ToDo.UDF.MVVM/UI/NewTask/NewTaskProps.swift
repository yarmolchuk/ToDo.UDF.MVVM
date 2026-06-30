//
//  NewTaskProps.swift
//  ToDo.UDF.MVVM
//
//  UDF-стан і події форми створення задачі. Props володіють власними
//  presentation-типами (Props.When/PriorityBadge) — View не знає про модельні енуми.
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
    }

    enum SyncEvent: Equatable {
        case titleChanged(String)
        case notesChanged(String)
        case whenChanged(Props.When)
        case timeChanged(Date)
        case priorityChanged(PriorityBadge)
        case timePickerOpened
        case timePickerClosed
        case backTapped
    }

    enum AsyncEvent: Equatable {
        case save
    }
}
