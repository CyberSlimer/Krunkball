# Krunkball — working notes for Claude

Swift + SpriteKit remake of *Crunchball 3000* (2009 Flash). Landscape iPhone/iPad, iOS 16+.
Read `README.md` (controls, how the match works) and `docs/DESIGN.md` (roadmap) first.

## Build & run (Mac)

```bash
brew install xcodegen          # once
xcodegen generate              # .xcodeproj is generated, never committed
xcodebuild -project Krunkball.xcodeproj -scheme Krunkball \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Then install/launch the `.app` from `build/DerivedData/Build/Products/Debug-iphonesimulator/`
with `xcrun simctl install` / `launch`, or just open the project in Xcode and Run.
Rotate the Simulator to landscape (⌘←); the app only supports landscape.

## Debug aids

- `KRUNKBALL_AUTOPILOT=1` in the environment hands the human side to the AI — AI vs AI, for
  balance testing. With simctl: `SIMCTL_CHILD_KRUNKBALL_AUTOPILOT=1 xcrun simctl launch <udid> com.rprobst.krunkball`.
- Every goal and the full-time score are `NSLog`ged with prefix `KRUNK` in DEBUG builds. Read them with
  `xcrun simctl spawn <udid> log show --last 5m --predicate 'process == "Krunkball" AND eventMessage CONTAINS "KRUNK"'`.
- Hardware keyboard works in the Simulator: WASD move, H pass/switch, G shoot/tackle, J formation.

## Rules

- Every gameplay number goes in `Krunkball/Game/Tuning.swift`; never inline magic numbers in logic.
- No SKPhysics — movement is hand-rolled kinematics in `MatchScene.apply` / `updateBall`. Keep it that way.
- `project.yml` is the source of truth for the Xcode project. Add new Swift files under `Krunkball/` and
  re-run `xcodegen generate`; don't hand-edit the `.xcodeproj`.
- LF line endings (`.gitattributes`), edited from both a Windows PC and this Mac.
- Balance target for AI vs AI: roughly 2–4 goals per side over the 2 × 90 s match.
