// Run: swiftc RestIt/TickTickHabitService.swift Scripts/CheckConsistency.swift -o /tmp/restit-consistency-check && /tmp/restit-consistency-check
import Foundation

@main
struct CheckConsistency {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        // The window crosses both a month boundary and the daylight-saving transition.
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
        func day(_ offset: Int, _ progress: Double, scheduled: Bool = true) -> TickTickHabitDay {
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return TickTickHabitDay(stamp: parts.year! * 10_000 + parts.month! * 100 + parts.day!,
                                   isScheduled: scheduled, progress: progress)
        }
        func habit(_ id: String, _ days: [TickTickHabitDay]) -> TickTickHabit {
            TickTickHabit(id: id, name: id, goal: 1, step: 1, unit: "", colorHex: nil,
                          repeatRule: nil, isScheduledToday: true, recentDays: days,
                          currentValue: 0, isCompletedToday: false)
        }
        let history = (-27...0).map { day($0, $0 >= -6 ? 1 : 0) }
        let habits = [habit("a", history + [day(1, 0)]), habit("b", [day(0, 0)])]
        let assignments: [String: HabitConsistencyCategory] = ["a": .religious, "b": .religious]
        let weekly = HabitConsistencySummary.calculate(habits: habits, assignments: assignments,
                                                       now: now, calendar: calendar)
        let monthly = HabitConsistencySummary.calculate(habits: habits, assignments: assignments,
                                                        days: 28, now: now, calendar: calendar)
        precondition(weekly.days == 7 && weekly.overallScore == 93)
        precondition(monthly.overallScore == 23)
        let a = weekly.habitImpacts.first { $0.habitID == "a" }!
        let b = weekly.habitImpacts.first { $0.habitID == "b" }!
        precondition(a.score == 100 && a.scheduledDayCount == 7 && a.overallScoreImpact == 93)
        precondition(b.score == 0 && b.overallScoreImpact == -7)
        let stale = HabitConsistencySummary.calculate(
            habits: [habit("a", [day(-7, 1), day(1, 1)])], assignments: assignments,
            now: now, calendar: calendar)
        precondition(stale.overallScore == nil && stale.habitImpacts[0].score == nil)
        let partial = HabitConsistencySummary.calculate(
            habits: [habit("a", [day(0, 0.5), day(-1, 0, scheduled: false)]),
                     habit("b", [day(0, 1)])],
            assignments: ["a": .religious, "b": .selfCare], now: now, calendar: calendar)
        precondition(partial.overallScore == 75)
        print("Consistency checks passed: weekly 93 vs 28-day 23; date boundaries, impacts, partial credit, and category weighting.")
    }
}
