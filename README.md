# RestIt

RestIt is a small native macOS menu-bar app for healthier screen habits.

- A 20-second, full-screen eye break every 20 minutes
- A persistent daily dashboard for completed rests
- Native TickTick habit sync for water intake, eye drops, and today’s incomplete habits
- A 7-day TickTick consistency score with per-habit percentages, completed-day counts, and a weekly history
- Gentle, adjustable audio cues for break start and break finish
- A control for skipping the next scheduled rest
- Settings that persist between launches
- No analytics; the TickTick token stays in macOS Keychain

## Run it

1. Open `RestIt.xcodeproj` in Xcode.
2. Select the **RestIt** scheme and **My Mac**.
3. Press **Run**.

RestIt lives in the menu bar (look for the eye icon), not the Dock. The app
must remain running for reminders to fire.

The completed-rest count resets automatically at the start of each local calendar day.
Only rests allowed to finish are counted; rests dismissed early are not.

## TickTick habit integration

RestIt connects to TickTick's official MCP service, loads existing habits, and
lets you link the menu-bar Water button and multiple Eye Drops buttons to the habits you already
configured. Water and each linked eye-drop habit record one configured habit step per press. The full-screen eye
break stays focused on resting your eyes without showing habit tasks. RestIt also loads the last 7 days of check-ins and summarizes
categorized habits in the menu-bar panel. **Weekly consistency details** and the **Consistency** settings show each habit’s percentage,
completed-day count (such as **5 of 7 days met goal**), and seven daily indicators. Partial progress still earns proportional credit;
days off are excluded. Habits with the lowest weekly consistency appear first. Weighted points, category weights, daily calculations,
and the effect of leaving a habit out are available in expandable details. Fractional point values are shares of the 100-point score,
not fractional day counts.

Use **Refresh all TickTick habits** at the top of the menu or at the bottom of any Settings tab to refetch every habit and 91 days
of check-ins. Today's progress, the rolling 7-day score, and weekly snapshots update together, with loading, success, and error feedback beside the control.

To connect:

1. In TickTick Web, open **Settings → Account → API Token** and create a token.
2. Open **RestIt Settings → TickTick Habits** and paste the token.
3. Select the existing habit for water intake and all of your eye-drop habits.
4. Open the **Consistency** tab and assign habits to Religious or Self-care.

The token is stored in macOS Keychain, not UserDefaults or the project files.
TickTick remains responsible for habit goals, schedules, and reminder times.

## Habit insights and weekly snapshots

Open **Habit insights & weekly history** in the menu, or **Settings → Consistency**.

- **Habits needing attention** ranks the last 7 completed days, excluding today's unfinished goals. Switch between lowest consistency and biggest score gap. Each habit shows missed goals, days with no progress, and partial days. The score gap is the weighted points left unearned, not the leave-one-habit-out comparison.
- **Weekly score history** uses Monday–Sunday weeks. Choose Overall, Religious, or Self-care, then select a graph bar or use **Inspect week** to see the score and every habit's saved daily breakdown.
- The graph shows the latest 13 saved weeks; the week picker retains older snapshots. The current week includes today and is marked **Week to date**. Missing scores stay missing rather than becoming zero.
- Initial history reconstructs up to 12 completed weeks from TickTick check-ins using the goals, schedules, and categories available at capture time. Historical configuration changes and deleted habits cannot be recovered; these weeks are labeled **Reconstructed**.
- Completed snapshots are saved locally in UserDefaults and stay fixed across refreshes, recategorization, and restarts. An open week is updated on refresh and finalized on the first successful refresh after Sunday. If the app is absent beyond the 91-day fetch window, an unfinished older snapshot remains explicitly incomplete. Weeks with no scored data are not invented. Snapshots are retained when disconnecting TickTick.

Run snapshot checks with:

```sh
swiftc RestIt/TickTickHabitService.swift Scripts/CheckWeeklyHistory.swift -o /tmp/restit-history-check
/tmp/restit-history-check
```

## How consistency is calculated

The window is the last 7 local calendar days, including today. Today's unfinished habits use their current progress, so the score can rise
as you check in. Scheduled days without a check-in count as zero. Unscheduled days and uncategorized habits are excluded; a category
without any scheduled data is excluded from the overall average.

1. **Daily habit progress:** `min(1, max(0, recordedValue / goal))`. A check-in marked completed receives `1` (100%).
2. **Individual habit consistency:** `round(100 × sum(progress) / scheduledDays)`. For example, 4 full days, 1 half day, and 2 zero days
   give `round(100 × 4.5 / 7) = 64%`.
3. **Category score:** average the scheduled habits' progress separately for each day, then average those daily results and round to a
   whole percentage. Each scored day has equal weight, even if different numbers of habits are due.
4. **Overall score:** average the rounded category scores and round again. Religious and Self-care each get 50% when both have scheduled
   data; a single category with data gets 100%.

The calculation lives in [`RestIt/TickTickHabitService.swift`](RestIt/TickTickHabitService.swift). A habit's contribution for one day is:

```swift
var possibleCategoryPoints: Double {
    100 / Double(scheduledHabitCount) / Double(categoryDayCount)
}

var categoryPoints: Double { progress * possibleCategoryPoints }
var overallPoints: Double { categoryPoints / Double(scoredCategoryCount) }
```

Sum `overallPoints` across that habit's scheduled days to get its earned points. Use `progress = 1` on every scheduled day to get its possible
points. All habits' possible points sum to 100. Earned habit points sum to the unrounded overall result; the displayed rounding adjustment
reconciles that sum with the existing category-then-overall rounding. Point values are displayed to two decimal places.

For example, with two Religious habits due every day at 100% and 50% consistency and one Self-care habit at 80%, their contributions are
25, 12.5, and 40 points. Religious scores 75, Self-care scores 80, and the final score is `round((75 + 80) / 2) = 78`.
The habit contributions total 77.5 points, with a +0.5 rounding adjustment. When schedules differ, the daily number of habits due changes
each habit's share, so simply averaging the individual habit consistency percentages will not necessarily produce the category score.

The separate **overall without this habit** comparison recomputes the entire score after excluding the habit. Its effect is
`currentOverallScore - overallScoreWithoutHabit`; these effects are not additive. If removing a habit leaves no scheduled data, there is
no comparison score.

Run the calculation checks with:

```sh
swiftc RestIt/TickTickHabitService.swift Scripts/CheckConsistency.swift -o /tmp/restit-consistency-check
/tmp/restit-consistency-check
```

Refresh integration checks exercise today's records, historical corrections, score updates, offline and authorization failures, malformed
responses, retry, duplicate-click protection, and logging from stale cached values. They use TickTick-shaped fixture responses and isolated
preferences, without credentials or network access. Logging reads today's current value before adding a step; refreshes and logging run
one at a time, and successful logging reloads the canonical records from TickTick.

```sh
swiftc -O RestIt/TickTickHabitService.swift RestIt/ReminderManager.swift \
  RestIt/BreakOverlayController.swift RestIt/AudioCuePlayer.swift \
  Scripts/CheckTickTickRefresh.swift -o /tmp/restit-refresh-check
/tmp/restit-refresh-check
```

To verify a live refresh using the installed app's own Keychain access, run the opt-in check below. That process reports habit counts,
generated calendar windows, loading state, and refresh status as JSON, then exits. It verifies the refresh flow, not whether every value
matches the TickTick UI. It does not write TickTick check-ins.

```sh
/Applications/RestIt.app/Contents/MacOS/RestIt --verify-ticktick-refresh
```

## Build from Terminal

```sh
xcodebuild \
  -project RestIt.xcodeproj \
  -scheme RestIt \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The resulting app is at
`DerivedData/Build/Products/Debug/RestIt.app`.
