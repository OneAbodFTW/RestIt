# RestIt

RestIt is a small native macOS menu-bar app for healthier screen habits.

- A 20-second, full-screen eye break every 20 minutes
- A persistent daily dashboard for completed rests
- Native TickTick habit sync for water intake, eye drops, and today’s incomplete habits
- A 7-day TickTick consistency score with habit-level impact for Religious and Self-care habits
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
categorized habits in the menu-bar panel. A habit-impact breakdown shows each habit’s own score and how the overall score changes when
that habit is left out. Numeric habits receive proportional credit up to their goal, and the overall score weights each configured category equally.

To connect:

1. In TickTick Web, open **Settings → Account → API Token** and create a token.
2. Open **RestIt Settings → TickTick Habits** and paste the token.
3. Select the existing habit for water intake and all of your eye-drop habits.
4. Open the **Consistency** tab and assign habits to Religious or Self-care.

The token is stored in macOS Keychain, not UserDefaults or the project files.
TickTick remains responsible for habit goals, schedules, and reminder times.

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
