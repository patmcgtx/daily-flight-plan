//
//  PlanCategory.swift
//  DailyFlightPlan
//
import SwiftData

@Model
class PlanCategory {

    @Attribute(.unique)
    var name: String

    var items: [PlanItem]

    init(name: String) {
        self.name = name
        self.items = []
    }
}
