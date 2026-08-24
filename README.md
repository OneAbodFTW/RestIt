# RestIt

RestIt is a small native macOS menu-bar app for healthier screen habits.

- A 20-second, full-screen eye break every 20 minutes
- Configurable water reminders through native macOS notifications
- Gentle, adjustable audio cues for break start, break finish, and water
- Pause, resume, skip, and start-now controls
- Settings that persist between launches
- No accounts, analytics, or network access

## Run it

1. Open `RestIt.xcodeproj` in Xcode.
2. Select the **RestIt** scheme and **My Mac**.
3. Press **Run**.
4. Allow notifications when macOS asks so water reminders can appear.

RestIt lives in the menu bar (look for the eye icon), not the Dock. The app
must remain running for reminders to fire.

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
