//
//  PlanCategory.swift
//  DailyFlightPlan
//
import SwiftData

@Model
class PlanCategory {

    var name: String = "Unknown"

    var items: [PlanItem]?

    init(name: String) {
        self.name = name
        self.items = []
    }
}
