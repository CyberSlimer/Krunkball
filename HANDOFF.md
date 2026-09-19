# Handoff

## 2026-09-18 — first Mac build, feel pass, tests

- Compiled first time on the Mac with **zero errors** (Xcode 26.6, iOS 18.6 simulator). Runs at 60 fps.
- **Fixed a real sim bug**: intents were decided and applied in one pass, team 0 first, so team 1's AI
  always read team 0's already-moved positions. With identical rosters on both sides team 1 won 58–29.
  Now every athlete decides from the frame-start snapshot, then everyone moves (see `runPlayers`).
  Head-on simultaneous tackles were also always resolved with team 0 as the tackler; now a coin flip.
- Safe-area handling: camera keeps the goals out from under the Dynamic Island; buttons and HUD move in
  from the notch / home-indicator side.
- Keeper: reads a shot's flight path and moves to intercept; extra catch reach; only comes off the line
  for a loose ball when nobody else will get there first; 0.6 s tackle protection after a catch so the
  original's knock-the-keeper-down exploit stays dead; distributes in 0.25 s and clears long when nobody
  is open instead of dribbling into the press.
- AI carrier no longer shoots the instant it is in range and "under pressure" (which, with pressers,
  was always): point-blank shoots, pressured looks for an open pass first, else shoots if in range.
- Demo rosters re-seeded (3322 / 3189, both quality 60) so both squads profile the same. The old seeds
  gave the Crushers str-73/74 forwards against a str-50 Titans back line.
- **Tests** (`KrunkballTests`, run with `xcodebuild … test`): 9 mechanics tests drive `MatchScene.update`
  headlessly (pickup, shoot, pass, tackle, switch, goal + reset, wall rebound, full match to full time)
  and `BalanceBenchmark` plays 10 AI-vs-AI matches and asserts 2 < avg total goals < 9.
- Balance history (AI vs AI, 2 × 90 s): first live match 5–9; after tuning + sim fix + reseed the
  benchmark averages **4.5 – 3.3** (≈27 shots a match, keepers save roughly half).
- Debug: `KRUNKBALL_AUTOPILOT=1` env (AI plays the human side), `KRUNK` goal / full-time NSLog lines,
  `MatchScene.stats` (shots / saves / tackles per team). Placeholder app icon added.

## TestFlight (2026-09-18)

- ASC record **Krunkball**, App ID 6813724028, bundle `com.rprobst.krunkball`, SKU `krunkball`, team 5X895J3VYD.
- Build **0.1.0 (1)** uploaded and processed; export compliance answered "none"; `ITSAppUsesNonExemptEncryption`
  is now in `project.yml` so later builds skip the prompt.
- Internal group **Krunkball Testers** (auto-distribution on) with `ryan.j.probst@icloud.com` (account holder).
  `rprobst93@gmail.com` is an Admin whose ASC invitation has expired — resend under Users and Access if it
  should test too.
- Next build: bump `CURRENT_PROJECT_VERSION` in `project.yml`, `xcodegen generate`, archive
  (`-destination 'generic/platform=iOS' -allowProvisioningUpdates archive`), then
  `xcodebuild -exportArchive -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates`.

## Known / next

- Human side with no input concedes constantly (the controlled carrier just stands there). Consider
  falling back to AI for the controlled athlete when the stick has been idle for ~1.5 s.
- The controlled athlete's white ring can sit under the score panel when play is at the top edge.
- Roadmap item 1 leftovers: haptics on tackles/goals, hit-stop, ball trail, stick dead zone.
- The Simulator sends one touch at a time, so test touch controls (stick + button together) on a device.
- `MatchScene.stats` is collected but not shown anywhere yet — a post-match stats screen is a cheap win.
