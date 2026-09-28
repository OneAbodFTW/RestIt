// swiftc RestIt/TickTickHabitService.swift Scripts/CheckWeeklyHistory.swift -o /tmp/restit-history-check
import Foundation

@main
struct CheckWeeklyHistory {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }
        func habits(at now: Date, progress: Double = 0.5, count: Int = 91) -> [TickTickHabit] {
            let days = (0..<count).reversed().map { offset in
                let day = calendar.date(byAdding: .day, value: -offset, to: now)!
                let parts = calendar.dateComponents([.year, .month, .day], from: day)
                return TickTickHabitDay(stamp: parts.year! * 10_000 + parts.month! * 100 + parts.day!,
                                       isScheduled: true, progress: progress)
            }
            return [TickTickHabit(id: "a", name: "Reading", goal: 1, step: 1, unit: "",
                                 colorHex: nil, repeatRule: nil, isScheduledToday: true,
                                 recentDays: days, currentValue: progress, isCompletedToday: progress == 1)]
        }
        let assignments: [String: HabitConsistencyCategory] = ["a": .religious]
        let sunday = date(2026, 11, 1) // DST ends on this day.
        let original = HabitWeekSnapshot.updating([], habits: habits(at: sunday), assignments: assignments,
                                                 now: sunday, calendar: calendar)
        precondition(original.count == 13)
        precondition(original.last!.startStamp == 20261026 && !original.last!.isFinal)
        precondition(original.last!.summary.dayStamps.count == 7)
        precondition(original.dropLast().allSatisfy { $0.isFinal && $0.isReconstructed })
        precondition(original.last!.summary.overallScore == 50)
        precondition(original.last!.summary.habitImpacts[0].missedGoalCount == 7)
        precondition(original.last!.summary.habitImpacts[0].zeroProgressDayCount == 0)
        precondition(abs(original.last!.summary.habitImpacts[0].unearnedPoints - 50) < 0.000001)

        let monday = date(2026, 11, 2)
        let advanced = HabitWeekSnapshot.updating(original, habits: habits(at: monday, progress: 1),
                                                 assignments: assignments, now: monday, calendar: calendar)
        let closed = advanced.first { $0.startStamp == 20261026 }!
        precondition(closed.isFinal && !closed.isReconstructed && closed.summary.overallScore == 100)
        precondition(advanced.last!.startStamp == 20261102 && advanced.last!.summary.dayStamps.count == 1)
        precondition(advanced.last!.summary.overallScore == 100)
        precondition(advanced.first == original.first, "Old snapshots must not be recalculated")
        precondition(calendar.component(.weekday, from: closed.startDate) == 2)
        precondition(calendar.component(.weekday, from: closed.endDate) == 2)
        precondition(closed.endDate.timeIntervalSince(closed.startDate) == 7 * 86400 + 3600)

        let changed = HabitWeekSnapshot.updating(advanced, habits: habits(at: monday, progress: 0),
                                                assignments: ["a": .selfCare], now: monday, calendar: calendar)
        precondition(changed.first { $0.id == closed.id } == closed, "Frozen data or category changed")
        precondition(changed.last!.summary.overallScore == 0)
        precondition(changed.last!.summary.habitImpacts[0].category == .selfCare)
        let decoded = try JSONDecoder().decode([HabitWeekSnapshot].self, from: JSONEncoder().encode(changed))
        precondition(decoded == changed, "Snapshot persistence lost detail")

        let empty = HabitWeekSnapshot.updating([], habits: [], assignments: assignments, now: monday, calendar: calendar)
        let unassigned = HabitWeekSnapshot.updating([], habits: habits(at: monday), assignments: [:], now: monday, calendar: calendar)
        precondition(empty.isEmpty && unassigned.isEmpty)
        let partial = HabitWeekSnapshot.updating([], habits: habits(at: sunday, count: 3), assignments: assignments,
                                                now: sunday, calendar: calendar)
        precondition(partial.isEmpty, "A truncated week must not become a snapshot")
        let january = date(2027, 1, 1)
        let newYear = HabitWeekSnapshot.updating([], habits: habits(at: january), assignments: assignments,
                                                now: january, calendar: calendar)
        precondition(newYear.last!.startStamp == 20261228 && newYear.last!.summary.dayStamps.count == 5)
        precondition(newYear.last!.summary.dayStamps.last == 20270101)
        print("Weekly history checks passed: Monday boundaries, DST, year rollover, partial weeks, finalization, immutable scores/categories, persistence, missing data, and habit score gaps.")
    }
}
