// Deterministic refresh integration checks; no account, credentials, or network needed.
// Compile with TickTickHabitService.swift, ReminderManager.swift,
// BreakOverlayController.swift, and AudioCuePlayer.swift.
// Live check: /Applications/RestIt.app/Contents/MacOS/RestIt --verify-ticktick-refresh
import AppKit
import Combine
import Foundation

private final class RefreshFailureProtocol: URLProtocol {
    enum Mode { case initial, updated, historyChanged, resetToday, emptyToday, offline, unauthorized, malformed }
    private static let lock = NSLock()
    private static var mode: Mode = .initial
    private static var interceptedCount = 0
    private static var savedValue: Double?
    private static var upsertCount = 0
    private static var listCount = 0

    static func configure(_ newMode: Mode) {
        lock.lock()
        defer { lock.unlock() }
        mode = newMode
        interceptedCount = 0
        savedValue = nil
        upsertCount = 0
        listCount = 0
    }

    static var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return interceptedCount
    }

    static var lastSavedValue: Double? {
        lock.lock()
        defer { lock.unlock() }
        return savedValue
    }

    static var writes: Int {
        lock.lock()
        defer { lock.unlock() }
        return upsertCount
    }

    static var habitFetches: Int {
        lock.lock()
        defer { lock.unlock() }
        return listCount
    }

    override class func canInit(with request: URLRequest) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return request.url?.host == "mcp.ticktick.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let mode = Self.mode
        Self.interceptedCount += 1
        Self.lock.unlock()

        if mode == .offline {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: mode == .unauthorized ? 401 : 200,
                                       httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json", "Mcp-Session-Id": "fixture-session"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if mode == .unauthorized || mode == .malformed {
            client?.urlProtocol(self, didLoad: Data("invalid response fixture".utf8))
        } else {
            do {
                let body = try requestBody()
                let method = body["method"] as? String
                if method != "notifications/initialized" {
                    let params = body["params"] as? [String: Any] ?? [:]
                    let result: [String: Any]
                    switch params["name"] as? String {
                    case "upsert_habit_checkins":
                        let arguments = params["arguments"] as? [String: Any] ?? [:]
                        let checkin = arguments["checkin_data"] as? [String: Any] ?? [:]
                        let value = (checkin["value"] as? NSNumber)?.doubleValue
                        Self.lock.lock()
                        Self.savedValue = value
                        Self.upsertCount += 1
                        Self.lock.unlock()
                        result = ["structuredContent": ["habitId": arguments["habit_id"] ?? "water", "checkins": [checkin]]]
                    case "list_habits":
                        Self.lock.lock()
                        Self.listCount += 1
                        Self.lock.unlock()
                        result = ["structuredContent": ["result": [
                            ["id": "water", "name": "Water fixture", "goal": 4, "step": 1, "unit": "glasses"],
                            ["id": "reading", "name": "Reading fixture", "goal": 1, "step": 1]
                        ]]]
                    case "get_habit_checkins":
                        let arguments = params["arguments"] as? [String: Any] ?? [:]
                        let ids = Set(arguments["habit_ids"] as? [String] ?? [])
                        let fromStamp = arguments["from_stamp"] as? Int ?? 0
                        precondition(ids == ["water", "reading"] || ids == ["water"])
                        precondition(fromStamp == stamp(offset: -6) || fromStamp == stamp(offset: 0))
                        precondition(arguments["to_stamp"] as? Int == stamp(offset: 1))
                        // Match TickTick's real grouped structuredContent.result response.
                        let groups: [[String: Any]] = ids.sorted().map { id in
                            let checkins: [[String: Any]] = (-6...0).compactMap { offset in
                                guard stamp(offset: offset) >= fromStamp else { return nil }
                                if id == "water" && offset == 0 && mode == .emptyToday { return nil }
                                var value: Double = id == "water" ? 4 : 1
                                if id == "water" {
                                    if mode == .historyChanged && offset == -4 { value = 2 }
                                    if offset == 0 {
                                        if mode == .initial { value = 2 }
                                        if mode == .resetToday { value = 1 }
                                        value = Self.lastSavedValue ?? value
                                    }
                                }
                                return ["stamp": stamp(offset: offset), "value": value,
                                        "status": id == "reading" ? 2 : 0]
                            }
                            return ["habitId": id, "checkins": checkins]
                        }
                        result = ["structuredContent": ["result": groups]]
                    default:
                        precondition(method == "initialize", "Unexpected request in refresh: \(String(describing: method))")
                        result = [:]
                    }
                    let data = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": body["id"] ?? 1, "result": result])
                    client?.urlProtocol(self, didLoad: data)
                }
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func requestBody() throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func stamp(offset: Int) -> Int {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: offset, to: Date())!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return parts.year! * 10_000 + parts.month! * 100 + parts.day!
    }
}

@main
struct CheckTickTickRefresh {
    struct CheckFailure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @MainActor static func main() async {
        do {
            try await checkRefresh()
        } catch {
            print("FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }

    @MainActor private static func checkRefresh() async throws {
        let suiteName = "com.abod.RestIt.refresh-check.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: "eyeRemindersEnabled")
        defaults.set(false, forKey: "audioCuesEnabled")
        defaults.set(["water": "selfCare", "reading": "religious"], forKey: "habitCategoryAssignments")

        guard URLProtocol.registerClass(RefreshFailureProtocol.self) else {
            throw CheckFailure(message: "Could not register the failure test transport.")
        }
        defer { URLProtocol.unregisterClass(RefreshFailureProtocol.self) }

        let manager = ReminderManager(defaults: defaults, overlayController: BreakOverlayController(),
                                      tickTickTokenLoader: { "fixture-token" })
        var loadingStates: [Bool] = []
        var dataEvents = 0
        let loadingSubscription = manager.$isTickTickSyncing.sink { loadingStates.append($0) }
        let dataSubscription = manager.$tickTickHabits.dropFirst().sink { _ in dataEvents += 1 }
        defer {
            loadingSubscription.cancel()
            dataSubscription.cancel()
        }

        let startupDeadline = Date().addingTimeInterval(90)
        while !loadingStates.contains(true) || manager.isTickTickSyncing {
            guard Date() < startupDeadline else { throw CheckFailure(message: "Initial refresh timed out.") }
            try await Task.sleep(for: .milliseconds(100))
        }
        try require(!manager.tickTickStatusIsError, "Initial fetch failed: \(manager.tickTickStatusMessage ?? "unknown error")")
        try require(manager.habitConsistencySummary.overallScore == 97, "Initial fixture score is wrong.")
        let staleWater = manager.tickTickHabits.first { $0.id == "water" }!
        print("Initial fixture fetch and score passed.")
        fflush(stdout)

        loadingStates = []
        let eventsBeforeRefresh = dataEvents
        RefreshFailureProtocol.configure(.updated)
        // This is the exact method invoked by both global refresh buttons.
        await manager.syncTickTickHabits()
        try require(!manager.tickTickStatusIsError, "Manual refresh failed: \(manager.tickTickStatusMessage ?? "unknown error")")
        try require(loadingStates == [true, false], "Refresh did not enter and leave its loading state.")
        try require(dataEvents == eventsBeforeRefresh + 1, "Refresh did not publish a fresh habit array.")
        try require(manager.tickTickStatusMessage?.hasPrefix("Refreshed ") == true, "Refresh did not publish success feedback.")
        try require(!manager.tickTickHabits.isEmpty, "The account returned no habits; record refresh could not be verified.")
        try require(manager.tickTickHabits.first { $0.id == "water" }?.currentValue == 4, "Today's progress did not update.")
        try require(manager.habitConsistencySummary.overallScore == 100, "Weekly score did not update with refreshed records.")

        let summary = manager.habitConsistencySummary
        for habit in manager.tickTickHabits {
            try require(habit.recentDays.count == 7, "A habit did not contain exactly seven daily records.")
            try require(habit.recentDays.map(\.stamp) == summary.dayStamps, "A habit's record dates differ from the score window.")
            try require(habit.recentDays.allSatisfy { (0...1).contains($0.progress) }, "A habit has invalid daily progress.")
        }
        print("PASS refresh: seven daily records per habit; today's progress, weekly score, and success state updated.")
        fflush(stdout)

        RefreshFailureProtocol.configure(.historyChanged)
        await manager.syncTickTickHabits()
        let changedHistory = manager.tickTickHabits.first { $0.id == "water" }!
        try require(changedHistory.currentValue == 4 && changedHistory.recentDays[2].progress == 0.5,
                    "Refresh missed a correction to a past day's check-in.")
        try require(manager.habitConsistencySummary.overallScore == 97, "Historical correction did not update the score.")
        RefreshFailureProtocol.configure(.updated)
        await manager.syncTickTickHabits()
        try require(manager.tickTickHabits.first { $0.id == "water" }?.recentDays[2].progress == 1,
                    "Refresh retained an old historical check-in.")
        print("PASS historical corrections: past-day progress and the weekly score follow the source records.")

        let previousHabits = manager.tickTickHabits
        let previousSummary = manager.habitConsistencySummary
        for (mode, label) in [(RefreshFailureProtocol.Mode.offline, "offline"), (.unauthorized, "expired token"), (.malformed, "malformed response")] {
            RefreshFailureProtocol.configure(mode)
            loadingStates = []
            await manager.syncTickTickHabits()
            try require(RefreshFailureProtocol.count > 0, "The \(label) failure was not intercepted.")
            try require(manager.tickTickStatusIsError && manager.tickTickStatusMessage != nil, "The \(label) failure was not reported.")
            try require(loadingStates == [true, false], "The \(label) failure left the refresh control busy.")
            try require(manager.tickTickHabits == previousHabits, "The \(label) failure discarded previous records.")
            try require(manager.habitConsistencySummary == previousSummary, "The \(label) failure changed the existing score.")
            print("PASS \(label): error shown, loading cleared, previous records and scores retained.")
        }
        fflush(stdout)

        RefreshFailureProtocol.configure(.updated)
        loadingStates = []
        let eventsBeforeRetry = dataEvents
        async let first: Void = manager.syncTickTickHabits()
        async let duplicate: Void = manager.syncTickTickHabits()
        _ = await (first, duplicate)
        try require(!manager.tickTickStatusIsError, "Retry did not recover from the simulated errors.")
        try require(loadingStates == [true, false], "Concurrent refresh calls were not coalesced.")
        try require(dataEvents == eventsBeforeRetry + 1, "Concurrent refresh calls caused duplicate data reloads.")
        print("PASS retry and duplicate-click protection. No credentials, real check-ins, or existing app preferences were used.")

        let saved = try await TickTickHabitService(token: "fixture-token").checkIn(staleWater, complete: false)
        try require(saved == 5 && RefreshFailureProtocol.lastSavedValue == 5,
                    "Stale check-in overwrote server progress: server had 4, one step should save 5, got \(saved).")
        print("PASS stale check-in: increments the latest server value instead of overwriting it with cached progress.")

        RefreshFailureProtocol.configure(.resetToday)
        let resetValue = try await TickTickHabitService(token: "fixture-token").checkIn(staleWater, complete: false)
        try require(resetValue == 2, "Logging did not respect a lower value reset in TickTick.")
        RefreshFailureProtocol.configure(.emptyToday)
        let firstValue = try await TickTickHabitService(token: "fixture-token").checkIn(staleWater, complete: false)
        try require(firstValue == 1, "Logging reused yesterday's cached progress when today had no check-in.")
        print("PASS remote reset and first check-in: the source value takes precedence over the cache.")

        RefreshFailureProtocol.configure(.offline)
        do {
            _ = try await TickTickHabitService(token: "fixture-token").checkIn(staleWater, complete: false)
            throw CheckFailure(message: "A failed preflight read was accepted.")
        } catch is CheckFailure {
            throw CheckFailure(message: "A failed preflight read was accepted.")
        } catch {
            try require(RefreshFailureProtocol.writes == 0, "The app wrote cached progress after the current-value fetch failed.")
        }
        print("PASS failed preflight: no check-in is written when the current value cannot be fetched.")

        RefreshFailureProtocol.configure(.updated)
        manager.selectedWaterHabitID = "water"
        manager.logWaterHabit()
        manager.logWaterHabit()
        try require(manager.checkingHabitIDs == ["water"], "Logging did not mark the habit busy.")
        await manager.syncTickTickHabits()
        try require(!manager.isTickTickSyncing, "A refresh overlapped the pending check-in.")
        let loggingDeadline = Date().addingTimeInterval(10)
        while !manager.checkingHabitIDs.isEmpty || manager.isTickTickSyncing {
            guard Date() < loggingDeadline else { throw CheckFailure(message: "Logging/refresh timed out.") }
            try await Task.sleep(for: .milliseconds(10))
        }
        try require(!manager.tickTickStatusIsError, "Logging failed: \(manager.tickTickStatusMessage ?? "unknown error")")
        try require(RefreshFailureProtocol.writes == 1, "Duplicate logging caused more than one write.")
        try require(RefreshFailureProtocol.habitFetches == 1, "Logging did not reload canonical habits after the write.")
        try require(manager.tickTickHabits.first { $0.id == "water" }?.currentValue == 5,
                    "The canonical refresh overwrote the saved value.")
        print("PASS logging/refresh serialization, duplicate logging protection, and canonical reload after saving.")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw CheckFailure(message: message) }
    }
}
