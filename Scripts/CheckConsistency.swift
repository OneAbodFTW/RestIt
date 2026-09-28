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
        func close(_ actual: Double?, _ expected: Double) {
            precondition(actual != nil && abs(actual! - expected) < 0.000_001,
                         "Expected \(expected), got \(String(describing: actual))")
        }
        func reconciles(_ summary: HabitConsistencySummary) {
            guard let score = summary.overallScore else {
                precondition(summary.totalHabitPoints == nil && summary.roundingAdjustment == nil)
                precondition(summary.habitImpacts.allSatisfy { $0.overallPoints == nil })
                return
            }
            close(summary.habitImpacts.compactMap(\.possibleOverallPoints).reduce(0, +), 100)
            close(summary.totalHabitPoints! + summary.roundingAdjustment!, Double(score))
            for category in summary.categoryScores where category.score != nil {
                let points = summary.habitImpacts.filter { $0.category == category.category }
                    .compactMap(\.overallPoints).reduce(0, +)
                close(points, category.unroundedScore! / Double(summary.scoredCategoryCount))
            }
        }
        let history = (-27...0).map { day($0, $0 >= -6 ? 1 : 0) }
        let habits = [habit("a", history + [day(1, 0)]), habit("b", [day(0, 0)])]
        let assignments: [String: HabitConsistencyCategory] = ["a": .religious, "b": .religious]
        let weekly = HabitConsistencySummary.calculate(habits: habits, assignments: assignments,
                                                       now: now, calendar: calendar)
        let monthly = HabitConsistencySummary.calculate(habits: habits, assignments: assignments,
                                                        days: 28, now: now, calendar: calendar)
        precondition(weekly.days == 7 && weekly.overallScore == 93)
        precondition(weekly.dayStamps == [20261028, 20261029, 20261030, 20261031, 20261101, 20261102, 20261103])
        precondition(monthly.overallScore == 23)
        let a = weekly.habitImpacts.first { $0.habitID == "a" }!
        let b = weekly.habitImpacts.first { $0.habitID == "b" }!
        precondition(a.score == 100 && a.scheduledDayCount == 7 && a.overallScoreImpact == 93)
        precondition(b.score == 0 && b.overallScoreImpact == -7)
        close(a.overallPoints, 650 / 7)
        close(a.possibleOverallPoints, 650 / 7)
        close(b.overallPoints, 0)
        close(b.possibleOverallPoints, 50 / 7)
        precondition(a.overallScoreWithoutHabit == 0 && b.overallScoreWithoutHabit == 100)
        precondition(a.completedDayCount == 7 && b.zeroProgressDayCount == 1)
        let stale = HabitConsistencySummary.calculate(
            habits: [habit("a", [day(-7, 1), day(1, 1)])], assignments: assignments,
            now: now, calendar: calendar)
        precondition(stale.overallScore == nil && stale.habitImpacts[0].score == nil)
        let partial = HabitConsistencySummary.calculate(
            habits: [habit("a", [day(0, 0.5), day(-1, 0, scheduled: false)]),
                     habit("b", [day(0, 1)])],
            assignments: ["a": .religious, "b": .selfCare], now: now, calendar: calendar)
        precondition(partial.overallScore == 75)
        close(partial.habitImpacts[0].overallPoints, 25)
        close(partial.habitImpacts[0].possibleOverallPoints, 50)
        precondition(partial.habitImpacts[0].partialDayCount == 1)
        precondition(partial.habitImpacts[0].scheduledDayCount == 1)

        // Equal habit consistency can earn different points when daily schedules differ.
        let mixed = HabitConsistencySummary.calculate(
            habits: [habit("a", [day(-1, 1), day(0, 0)]),
                     habit("b", [day(-1, 0), day(0, 1)]),
                     habit("c", [day(-1, 1)]),
                     habit("d", [day(-1, 1), day(0, 1)]),
                     habit("off", [day(0, 1, scheduled: false)]),
                     habit("ignored", [day(0, 0)])],
            assignments: ["a": .religious, "b": .religious, "c": .religious,
                          "d": .selfCare, "off": .selfCare], now: now, calendar: calendar)
        precondition(mixed.overallScore == 79 && mixed.habitImpacts.count == 5)
        let mixedA = mixed.habitImpacts.first { $0.habitID == "a" }!
        let mixedB = mixed.habitImpacts.first { $0.habitID == "b" }!
        precondition(mixedA.score == 50 && mixedB.score == 50)
        close(mixedA.overallPoints, 100 / 12)
        close(mixedB.overallPoints, 12.5)
        close(mixedA.possibleOverallPoints, 100 / 12 + 12.5)
        precondition(mixedA.dayContributions.map(\.scheduledHabitCount) == [3, 2])
        let off = mixed.habitImpacts.first { $0.habitID == "off" }!
        precondition(off.score == nil && off.overallPoints == nil && off.overallScoreWithoutHabit == nil)

        // Preserve rounding at BOTH category and overall levels (raw 50.05 becomes 51).
        let rounding = HabitConsistencySummary.calculate(
            habits: [habit("a", [day(0, 0.496)]), habit("b", [day(0, 0.505)])],
            assignments: ["a": .religious, "b": .selfCare], now: now, calendar: calendar)
        precondition(rounding.categoryScores.map(\.score) == [50, 51])
        precondition(rounding.overallScore == 51)
        close(rounding.totalHabitPoints, 50.05)
        close(rounding.roundingAdjustment, 0.95)

        var soloHabit = habit("solo", [day(0, 0.5)])
        let solo = HabitConsistencySummary.calculate(
            habits: [soloHabit], assignments: ["solo": .selfCare], now: now, calendar: calendar)
        precondition(solo.scoredCategoryCount == 1 && solo.overallScore == 50)
        close(solo.habitImpacts[0].overallPoints, 50)
        close(solo.habitImpacts[0].possibleOverallPoints, 100)
        precondition(solo.habitImpacts[0].overallScoreImpact == nil)
        precondition(solo.habitImpacts[0].overallScoreWithoutHabit == nil)
        soloHabit.applyCurrentValue(2)
        let updated = HabitConsistencySummary.calculate(
            habits: [soloHabit], assignments: ["solo": .selfCare], now: now, calendar: calendar)
        precondition(updated.overallScore == 100 && updated.habitImpacts[0].completedDayCount == 1)
        close(updated.habitImpacts[0].overallPoints, 100)

        let empty = HabitConsistencySummary.calculate(habits: [], assignments: [:], now: now, calendar: calendar)
        let unassigned = HabitConsistencySummary.calculate(
            habits: [soloHabit], assignments: [:], now: now, calendar: calendar)
        precondition(unassigned.habitImpacts.isEmpty && unassigned.overallScore == nil)

        [weekly, monthly, stale, partial, mixed, rounding, solo, updated, empty, unassigned].forEach(reconciles)
        print("Consistency checks passed: date boundaries, partial credit, mixed schedules, equal category weights, additive contributions, two-stage rounding, empty data, and live progress updates.")
    }
}
