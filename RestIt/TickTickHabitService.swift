import Foundation
import Security

enum HabitConsistencyCategory: String, CaseIterable, Identifiable, Sendable {
    case religious
    case selfCare
    case contribution

    var id: String { rawValue }

    var name: String {
        switch self {
        case .religious: "Religious"
        case .selfCare: "Self-care"
        case .contribution: "Contribution"
        }
    }

    var icon: String {
        switch self {
        case .religious: "sparkles"
        case .selfCare: "heart.fill"
        case .contribution: "hands.and.sparkles.fill"
        }
    }
}

struct TickTickHabitDay: Hashable, Sendable {
    let stamp: Int
    let isScheduled: Bool
    let progress: Double
}

struct TickTickHabit: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let goal: Double
    let step: Double
    let unit: String
    let colorHex: String?
    let repeatRule: String?
    let isScheduledToday: Bool
    var recentDays: [TickTickHabitDay]
    var currentValue: Double
    var isCompletedToday: Bool

    var progressText: String {
        if goal <= 1, unit.isEmpty {
            return isCompletedToday ? "Done" : "Not done"
        }

        let suffix = unit.isEmpty ? "" : " \(unit)"
        return "\(Self.numberText(currentValue)) / \(Self.numberText(goal))\(suffix)"
    }

    mutating func applyCurrentValue(_ value: Double) {
        currentValue = value
        isCompletedToday = value >= goal

        guard let index = recentDays.indices.last else { return }
        let today = recentDays[index]
        recentDays[index] = TickTickHabitDay(
            stamp: today.stamp,
            isScheduled: today.isScheduled,
            progress: min(1, max(0, value / goal))
        )
    }

    private static func numberText(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct HabitConsistencyCategoryScore: Identifiable, Hashable, Sendable {
    let category: HabitConsistencyCategory
    let score: Int?
    let habitCount: Int
    let scheduledDayCount: Int

    var id: String { category.id }
}

struct HabitConsistencySummary: Hashable, Sendable {
    let days: Int
    let categoryScores: [HabitConsistencyCategoryScore]

    var overallScore: Int? {
        let scores = categoryScores.compactMap(\.score)
        guard !scores.isEmpty else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }

    var configuredHabitCount: Int {
        categoryScores.reduce(0) { $0 + $1.habitCount }
    }

    static func calculate(
        habits: [TickTickHabit],
        assignments: [String: HabitConsistencyCategory],
        days: Int = 28
    ) -> HabitConsistencySummary {
        let scores = HabitConsistencyCategory.allCases.map { category in
            let assignedHabits = habits.filter { assignments[$0.id] == category }
            var progressByDay: [Int: [Double]] = [:]

            for habit in assignedHabits {
                for day in habit.recentDays where day.isScheduled {
                    progressByDay[day.stamp, default: []].append(day.progress)
                }
            }

            let dailyScores = progressByDay.values.compactMap { progress -> Double? in
                guard !progress.isEmpty else { return nil }
                return progress.reduce(0, +) / Double(progress.count)
            }
            let score = dailyScores.isEmpty
                ? nil
                : Int((100 * dailyScores.reduce(0, +) / Double(dailyScores.count)).rounded())

            return HabitConsistencyCategoryScore(
                category: category,
                score: score,
                habitCount: assignedHabits.count,
                scheduledDayCount: dailyScores.count
            )
        }

        return HabitConsistencySummary(days: days, categoryScores: scores)
    }
}

enum TickTickTokenStore {
    private static let service = "com.abod.RestIt.ticktick"
    private static let account = "api-token"

    static func load() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            throw TickTickError.invalidResponse
        }
        return token
    }

    static func save(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError(status: updateStatus) }

        var item = query
        item[kSecValueData as String] = data
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private struct KeychainError: LocalizedError {
        let status: OSStatus

        var errorDescription: String? {
            SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)."
        }
    }
}

actor TickTickHabitService {
    private static let endpoint = URL(string: "https://mcp.ticktick.com/")!
    private static let protocolVersion = "2025-06-18"

    private let token: String
    private var sessionID: String?
    private var nextRequestID = 1
    private var initialized = false

    init(token: String) {
        self.token = token
    }

    func fetchHabits(historyDays: Int = 28) async throws -> [TickTickHabit] {
        let habitsPayload = try await callTool("list_habits", arguments: [:])
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<max(1, historyDays)).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        .reversed()
        let todayStamp = Self.dateStamp(for: today)
        let rawHabits = Self.parseHabits(habitsPayload)

        guard !rawHabits.isEmpty else { return [] }

        let checkinsPayload = try await callTool(
            "get_habit_checkins",
            arguments: [
                "habit_ids": rawHabits.map(\.id),
                "from_stamp": Self.dateStamp(for: days.first ?? today),
                "to_stamp": todayStamp
            ]
        )
        let checkins = Self.parseCheckins(checkinsPayload, habitIDs: Set(rawHabits.map(\.id)))

        return rawHabits.map { raw in
            let todayRecords = checkins[raw.id, default: []].filter { $0.stamp == todayStamp }
            let value = todayRecords.map(\.value).max() ?? 0
            let completed = todayRecords.contains(where: { $0.status == 2 }) || value >= raw.goal
            let recentDays = days.map { date in
                let stamp = Self.dateStamp(for: date)
                let records = checkins[raw.id, default: []].filter { $0.stamp == stamp }
                let recordedValue = records.map(\.value).max() ?? 0
                let progress = records.contains(where: { $0.status == 2 })
                    ? 1
                    : min(1, max(0, recordedValue / raw.goal))
                return TickTickHabitDay(
                    stamp: stamp,
                    isScheduled: Self.isScheduled(raw, on: date),
                    progress: progress
                )
            }
            return TickTickHabit(
                id: raw.id,
                name: raw.name,
                goal: raw.goal,
                step: raw.step,
                unit: raw.unit,
                colorHex: raw.colorHex,
                repeatRule: raw.repeatRule,
                isScheduledToday: Self.isScheduled(raw, on: today),
                recentDays: recentDays,
                currentValue: value,
                isCompletedToday: completed
            )
        }
        .sorted { lhs, rhs in
            if lhs.isScheduledToday != rhs.isScheduledToday { return lhs.isScheduledToday }
            if lhs.isCompletedToday != rhs.isCompletedToday { return !lhs.isCompletedToday }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func checkIn(_ habit: TickTickHabit, complete: Bool) async throws -> Double {
        let value = complete
            ? max(habit.currentValue, habit.goal)
            : habit.currentValue + max(0.01, habit.step)
        _ = try await callTool(
            "upsert_habit_checkins",
            arguments: [
                "habit_id": habit.id,
                "checkin_data": [
                    "stamp": Self.dateStamp(for: Date()),
                    "value": value,
                    "goal": habit.goal
                ]
            ]
        )
        return value
    }

    private func initializeIfNeeded() async throws {
        guard !initialized else { return }

        _ = try await send(
            method: "initialize",
            params: [
                "protocolVersion": Self.protocolVersion,
                "capabilities": [:],
                "clientInfo": ["name": "RestIt", "version": "1.0"]
            ],
            isNotification: false,
            includeProtocolHeader: false
        )
        initialized = true

        _ = try await send(
            method: "notifications/initialized",
            params: nil,
            isNotification: true,
            includeProtocolHeader: true
        )
    }

    private func callTool(_ name: String, arguments: [String: Any]) async throws -> Any {
        try await initializeIfNeeded()
        guard let response = try await send(
            method: "tools/call",
            params: ["name": name, "arguments": arguments],
            isNotification: false,
            includeProtocolHeader: true
        ) as? [String: Any] else {
            throw TickTickError.invalidResponse
        }

        if response["isError"] as? Bool == true {
            throw TickTickError.tool(Self.message(from: response) ?? "TickTick rejected the request.")
        }
        if let structured = response["structuredContent"] {
            return structured
        }
        if let content = response["content"] as? [[String: Any]] {
            for item in content where item["type"] as? String == "text" {
                guard let text = item["text"] as? String else { continue }
                if let data = text.data(using: .utf8),
                   let object = try? JSONSerialization.jsonObject(with: data) {
                    return object
                }
                return text
            }
        }
        return response
    }

    private func send(
        method: String,
        params: [String: Any]?,
        isNotification: Bool,
        includeProtocolHeader: Bool
    ) async throws -> Any? {
        var body: [String: Any] = ["jsonrpc": "2.0", "method": method]
        if let params { body["params"] = params }
        if !isNotification {
            body["id"] = nextRequestID
            nextRequestID += 1
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if includeProtocolHeader {
            request.setValue(Self.protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version")
        }
        if let sessionID {
            request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TickTickError.invalidResponse }
        if let returnedSessionID = http.value(forHTTPHeaderField: "Mcp-Session-Id") {
            sessionID = returnedSessionID
        }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 { throw TickTickError.unauthorized }
            let detail = Self.responseMessage(data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw TickTickError.http(http.statusCode, detail)
        }
        guard !isNotification, !data.isEmpty else { return nil }

        let object = try Self.decodeResponse(data)
        guard let envelope = object as? [String: Any] else { throw TickTickError.invalidResponse }
        if let error = envelope["error"] as? [String: Any] {
            throw TickTickError.tool(error["message"] as? String ?? "TickTick MCP returned an error.")
        }
        return envelope["result"]
    }

    private static func decodeResponse(_ data: Data) throws -> Any {
        if let object = try? JSONSerialization.jsonObject(with: data) { return object }
        guard let text = String(data: data, encoding: .utf8) else { throw TickTickError.invalidResponse }

        for line in text.split(whereSeparator: \Character.isNewline).reversed() {
            let value = line.trimmingCharacters(in: .whitespaces)
            guard value.hasPrefix("data:") else { continue }
            let json = value.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let eventData = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: eventData) else { continue }
            return object
        }
        throw TickTickError.invalidResponse
    }

    private static func responseMessage(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object["message"] as? String
                ?? (object["error"] as? [String: Any])?["message"] as? String
        }
        return String(data: data, encoding: .utf8)
    }

    private static func message(from response: [String: Any]) -> String? {
        guard let content = response["content"] as? [[String: Any]] else { return nil }
        return content.compactMap { $0["text"] as? String }.first
    }

    private struct RawHabit {
        let id: String
        let name: String
        let goal: Double
        let step: Double
        let unit: String
        let colorHex: String?
        let repeatRule: String?
        let targetStartDate: Int?
        let excludedDates: [String]
    }

    private struct RawCheckin {
        let stamp: Int
        let value: Double
        let status: Int
    }

    private static func parseHabits(_ payload: Any) -> [RawHabit] {
        dictionaries(in: payload).compactMap { dictionary in
            guard let id = string(dictionary["id"] ?? dictionary["habitId"]),
                  let name = string(dictionary["name"] ?? dictionary["title"]),
                  !id.isEmpty, !name.isEmpty else { return nil }
            let goal = max(0.01, number(dictionary["goal"]) ?? 1)
            let step = max(0.01, number(dictionary["step"]) ?? min(1, goal))
            return RawHabit(
                id: id,
                name: name,
                goal: goal,
                step: step,
                unit: string(dictionary["unit"]) ?? "",
                colorHex: string(dictionary["color"]),
                repeatRule: string(dictionary["repeatRule"]),
                targetStartDate: integer(dictionary["targetStartDate"]),
                excludedDates: dictionary["exDates"] as? [String] ?? []
            )
        }
    }

    private static func parseCheckins(_ payload: Any, habitIDs: Set<String>) -> [String: [RawCheckin]] {
        var result: [String: [RawCheckin]] = [:]

        func walk(_ value: Any, contextHabitID: String?) {
            if let array = value as? [Any] {
                array.forEach { walk($0, contextHabitID: contextHabitID) }
                return
            }
            guard let dictionary = value as? [String: Any] else { return }

            let embeddedID = string(dictionary["habitId"] ?? dictionary["habit_id"])
            let habitID = embeddedID.flatMap { habitIDs.contains($0) ? $0 : nil } ?? contextHabitID
            if let habitID,
               let stamp = integer(dictionary["stamp"]),
               let value = number(dictionary["value"]) {
                result[habitID, default: []].append(
                    RawCheckin(stamp: stamp, value: value, status: integer(dictionary["status"]) ?? 0)
                )
            }

            for (key, child) in dictionary {
                let childContext = habitIDs.contains(key) ? key : habitID
                walk(child, contextHabitID: childContext)
            }
        }

        walk(payload, contextHabitID: nil)
        return result
    }

    private static func dictionaries(in value: Any) -> [[String: Any]] {
        if let dictionary = value as? [String: Any] {
            return [dictionary] + dictionary.values.flatMap(dictionaries(in:))
        }
        if let array = value as? [Any] {
            return array.flatMap(dictionaries(in:))
        }
        return []
    }

    private static func isScheduled(_ habit: RawHabit, on date: Date) -> Bool {
        let stamp = dateStamp(for: date)
        if let start = habit.targetStartDate, start > stamp { return false }
        let stampText = String(stamp)
        if habit.excludedDates.contains(where: { $0.filter(\.isNumber) == stampText }) { return false }

        guard let rule = habit.repeatRule?.uppercased(), !rule.isEmpty else { return true }
        let values = Dictionary(uniqueKeysWithValues: rule
            .replacingOccurrences(of: "RRULE:", with: "")
            .split(separator: ";")
            .compactMap { component -> (String, String)? in
                let pieces = component.split(separator: "=", maxSplits: 1).map(String.init)
                guard pieces.count == 2 else { return nil }
                return (pieces[0], pieces[1])
            })

        let weekdaySymbols = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
        let weekday = Calendar.current.component(.weekday, from: date)
        if let byDay = values["BYDAY"]?.split(separator: ",").map(String.init),
           weekdaySymbols.indices.contains(weekday - 1),
           !byDay.contains(weekdaySymbols[weekday - 1]) {
            return false
        }

        guard let startStamp = habit.targetStartDate,
              let startDate = Self.date(from: startStamp) else { return true }
        let interval = max(1, Int(values["INTERVAL"] ?? "1") ?? 1)
        let calendar = Calendar.current

        switch values["FREQ"] {
        case "DAILY":
            let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: date)).day ?? 0
            return elapsed >= 0 && elapsed % interval == 0
        case "WEEKLY":
            let elapsed = calendar.dateComponents([.weekOfYear], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: date)).weekOfYear ?? 0
            return elapsed >= 0 && elapsed % interval == 0
        case "MONTHLY":
            let elapsed = calendar.dateComponents([.month], from: startDate, to: date).month ?? 0
            let requiredDays = values["BYMONTHDAY"]?.split(separator: ",").compactMap { Int($0) }
            let dayMatches = requiredDays?.contains(calendar.component(.day, from: date))
                ?? (calendar.component(.day, from: date) == calendar.component(.day, from: startDate))
            return elapsed >= 0 && elapsed % interval == 0 && dayMatches
        case "YEARLY":
            let elapsed = calendar.dateComponents([.year], from: startDate, to: date).year ?? 0
            return elapsed >= 0
                && elapsed % interval == 0
                && calendar.component(.month, from: date) == calendar.component(.month, from: startDate)
                && calendar.component(.day, from: date) == calendar.component(.day, from: startDate)
        default:
            return true
        }
    }

    private static func dateStamp(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (components.year ?? 0) * 10_000 + (components.month ?? 0) * 100 + (components.day ?? 0)
    }

    private static func date(from stamp: Int) -> Date? {
        DateComponents(
            calendar: Calendar.current,
            year: stamp / 10_000,
            month: (stamp / 100) % 100,
            day: stamp % 100
        ).date
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

enum TickTickError: LocalizedError {
    case unauthorized
    case invalidResponse
    case http(Int, String)
    case tool(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "The TickTick API token is invalid or expired."
        case .invalidResponse:
            return "TickTick returned an unexpected response."
        case let .http(code, message):
            return "TickTick request failed (\(code)): \(message)"
        case let .tool(message):
            return message
        }
    }
}
