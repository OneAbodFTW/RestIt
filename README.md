# RestIt

RestIt is a small native macOS menu-bar app for healthier screen habits.

- A 20-second, full-screen eye break every 20 minutes
- A persistent daily dashboard for completed rests and active work time
- Native TickTick habit sync for water intake, eye drops, and today’s incomplete habits
- A 28-day TickTick consistency score for Religious, Self-care, and Contribution habits
- Gentle, adjustable audio cues for break start and break finish
- Pause, resume, skip, and start-now controls
- Settings that persist between launches
- No analytics; the TickTick token stays in macOS Keychain

## Run it

1. Open `RestIt.xcodeproj` in Xcode.
2. Select the **RestIt** scheme and **My Mac**.
3. Press **Run**.

RestIt lives in the menu bar (look for the eye icon), not the Dock. The app
must remain running for reminders to fire.

Daily tracking resets automatically at the start of each local calendar day.
Work time counts while RestIt is running and excludes paused reminders and
active eye-break overlays.

## TickTick habit integration

RestIt connects to TickTick's official MCP service, loads existing habits, and
lets you link the menu-bar Water button and multiple Eye Drops buttons to the habits you already
configured. Water records one habit step; each linked eye-drop habit can be checked off individually. The full-screen eye
break shows every scheduled habit that is still incomplete, with a Done button
for completing it. RestIt also loads the last 28 days of check-ins and summarizes
categorized habits in the menu-bar panel. Numeric habits receive proportional
credit up to their goal, and the overall score weights each configured category equally.

To connect:

1. In TickTick Web, open **Settings → Account → API Token** and create a token.
2. Open **RestIt Settings → TickTick Habits** and paste the token.
3. Select the existing habit for water intake and all of your eye-drop habits.
4. Open the **Consistency** tab and assign habits to Religious, Self-care, or Contribution.

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
