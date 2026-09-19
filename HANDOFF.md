# Handoff

## 2026-09-19 — playtest feedback: controls, pace, teams, athletes

Four things came back from the first real playthrough. All four are addressed here.
**Nothing in this session was compiled or run** — it was written on a Linux box with no Xcode, so
`xcodegen generate` + build + `xcodebuild test` is the first job on the Mac.

### 1. "There was no toggle to move the player, just pass and kick on the right"

This was real, and it was the worst bug in the build: `TouchControls` created the stick with
`isHidden = true` and only revealed it once a finger already landed on the left half. With nothing
drawn there, the two right-hand buttons were the only visible controls, so there was no way to know
movement existed. Compounding it, `HANDOFF` already noted that an unsteered human side just stands
still — so the match looked broken as well as unplayable.

- The stick is now **always drawn**, parked bottom-left with a four-way glyph and a `MOVE` caption,
  and brightens when held. It still jumps to wherever your thumb lands (anywhere in the left 55%).
- Added `Tuning.stickDeadZone` (0.14) so a resting thumb does not drift the athlete.
- A **DRAG HERE TO MOVE** prompt pulses next to the stick for the first 20 s of the first half and
  vanishes on the first input.
- Button hit areas are circular with a 12 pt margin instead of `SKShapeNode.contains`.
- **Idle handoff**: after `Tuning.idleHandoffDelay` (1.5 s) with no stick or key input, the AI takes
  the controlled athlete and the HUD says so. Any input takes it straight back.
- The menu now has a HOW TO PLAY panel listing every control, touch and keyboard.

### 2. "It played really fast"

A pace pass rather than a field resize — the arena is unchanged, so the AI tuning and formation
slots still hold:

- Top speed down ~22% (`baseSpeed` 170→132, `speedPerStat` 1.5→1.15), acceleration 1100→880.
  An athlete now crosses the deck in about 8 s instead of 6.
- Pass 640→520, shot 860→720 base; a little more air time and more grip on a loose ball.
- Halves 90 s → **120 s**, so a possession has room to develop.
- Camera pulled back: `cameraVisibleHeight` 640→700, follow rate 6→5.2.
- **Stamina**: sprinting above 55% of top speed drains it, easing off pays it back, and a tired
  athlete is slower (floor 0.74x). The speed stat doubles as fitness. Full rest at each half,
  a 0.4 top-up at the kickoff after a goal. Frozen play never drains it.
- Carrying the ball costs 7% of your pace (`carrierSpeedPenalty`).

**If it still reads too fast**, the next lever is the deck itself — scale `Tuning.fieldLength` /
`fieldWidth` *and* every `Formation` slot together, then re-run `BalanceBenchmark`. Everything else
is already tuned down.

### 3. "It felt like hard difficulty"

It effectively was: one setting, 0.15 s reactions, three pressers. Now `Difficulty` (casual / pro /
brutal) changes three things at once — AI reaction time (x2.2 / x1.0 / x0.7), how many opponents
press (2 / 3 / 4), and the opposition's stats (-9 / 0 / +9 across the board). **Your own squad is
never rescaled.** Pro is the setting the balance benchmark targets. Picked on the title menu.

### 4. "Pick your teams, recruit the players, like the original"

- **The full ladder**: 32 teams over 4 divisions (`Krunkball/Game/Model/League.swift`), each squad
  generated from a fixed seed so a team is the same team on every device. The two demo squads are
  in there as Division 2 entries at their original seeds, so `BalanceBenchmark` is unchanged.
- **Menus are SwiftUI** now (`Krunkball/App/Menu/`), with SpriteKit kept for the match only. The
  scene takes a `MatchConfig` and hands back a `MatchResult` — it knows nothing about careers.
- **Quick match**: pick your squad, then your opponent, off the ladder.
- **Career**: take over any club, start with 120 credits and a home-and-away fixture list against
  your seven divisional rivals. Squad screen with a starting ten (tap two athletes to swap, slot GK
  plays in goal) and a **transfer market** of twelve free agents priced off overall — sign up to a
  14-man squad, release for half the fee back. Results pay gate money. Saved as JSON in
  `UserDefaults` via `CareerStore`, written after every signing and every result.
- **Result screen**: `MatchScene.stats` was being collected and never shown. It is shown now.

### 5. "Something more in depth than a little circle"

`PlayerNode` is drawn rather than filled: helmet with a crest stripe and a cyan visor that shows
which way the athlete is turned, shoulder pads, a wedge torso in the kit colours, a squad number
down the back, and arms and legs that swing on a stride cycle driven by distance covered (so a
walking athlete does not paddle at sprint tempo). Build comes from the stats — a strength-heavy
blocker is visibly broader than a speed-heavy runner. Dive and sprawl poses for tackles and
knockdowns. Keepers wear the kit inverted. Selection is a marker at the feet, not a ring round the
body. The ball got a seam that spins and a fading trail in flight.

Roles (BLOCKER / RUNNER / GUNNER / ALL-ROUND) are derived from the stats, not stored, so training a
player later will move them between roles for free.

### Tests

- `CareerTests` is new: ladder shape, divisions descending in strength, deterministic markets,
  signing / releasing / swapping, results and gate money, JSON round trip, roles and values,
  difficulty only touching the opposition.
- `MatchSceneTests` gained: stick dead zone, stamina drain and recovery (driven on a bare
  `PlayerNode` so it does not depend on where the ball is), fitness from the speed stat, the idle
  handoff, difficulty wiring, and full time reporting a result exactly once.
- `BalanceBenchmark` now asserts **goals per minute** (0.5-1.6) instead of goals per match, so it
  survives the half-length change. **Re-run it first on the Mac** — the pace pass moves the
  scoring rate and the numbers here are reasoned, not measured.

### Audit pass (same session, no compiler)

A second read hunting specifically for things that would not compile, since there was no Xcode.
Found and fixed:

- **Key paths into tuples.** `ForEach(Array(x.enumerated()), id: \.element.id)` in `TeamPickerView`
  and `ClubView`. Swift does not do key paths to tuple members. Both now index by slot / by the
  division's own id instead, which also removed the index clamping.
- **`Career.record` was both a stored property and a method** (`record(homeGoals:awayGoals:)`).
  The method is now `bankResult(homeGoals:awayGoals:)`.
- **A result-screen race.** `AppModel.finishMatch` cleared `pendingConfig` while `screen` was still
  `.match`. Those are two separate publishes, and a re-render in the gap lands on the empty-config
  branch, which bounces to the menu instead of showing the result. It no longer clears it — the
  next match overwrites it.
- **`.frame(maxWidth: wide ? .infinity : nil)`** — an implicit member on the wrapped type of an
  optional. Spelled out as a `CGFloat?` computed property.
- **`[CGFloat(0), .pi / 2, ...]`** — a heterogeneous literal array leaning on inference. Now an
  explicit `[CGFloat]`.
- **`TeamPickerView`** got a written-out `init` rather than relying on the synthesized memberwise
  one, since it is built from another file and also carries private state. Its `private let columns`
  became a computed property.
- **Stamina drained off a stale velocity while play was frozen** (velocities are not cleared during
  a celebration, and `apply` does not run). `PlayerNode.tick` now takes `live:`.
- **Goal-net tints went stale after the half-time swap** — the nets are built once. They are now
  re-tinted at every kickoff.
- Shirt numbers now match the squad screen (K, then 1-9).

Cross-checked by script: brace/paren balance across all 25 files, every `Tuning.*`, `Deck.*`,
`Difficulty.*` and `League.*` reference against its declaration, and every `controls.*`, `ball.*`
and `PlayerNode` member reference against what those types actually declare. All resolve.

### Known / next

- Still not compiled. The audit above removed the errors I could find by reading; what is left is
  most likely SwiftUI type-inference complaints in the menu files, which are the least exercised
  code in the repo. `Krunkball/App/Menu/` is where to look first.
- Roadmap item 1 leftovers still open: haptics on tackles and goals, a short hit-stop on big hits.
- The career has no league table — the AI sides do not play each other's fixtures, so there are no
  standings and no promotion or relegation yet. That is the next obvious chunk.
- No training / equipment / supplements yet (roadmap item 3).
- The Simulator sends one touch at a time, so test stick-plus-button on a device.
- `CareerStore` is `UserDefaults` JSON under `krunkball.career.v1`. Bump the key on any `Career`
  shape change rather than letting old saves fail to decode.

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

## Known / next (as of 2026-09-18 — see the 2026-09-19 entry above for what has since been done)

- ~~Human side with no input concedes constantly (the controlled carrier just stands there). Consider
  falling back to AI for the controlled athlete when the stick has been idle for ~1.5 s.~~ Done: the
  idle handoff.
- ~~The controlled athlete's white ring can sit under the score panel when play is at the top edge.~~
  Done: the HUD panel sits tighter to the top edge and the selection marker is at the feet.
- ~~Roadmap item 1 leftovers: haptics on tackles/goals, hit-stop, ball trail, stick dead zone.~~
  Ball trail and stick dead zone done; haptics and hit-stop still open.
- The Simulator sends one touch at a time, so test touch controls (stick + button together) on a device.
- ~~`MatchScene.stats` is collected but not shown anywhere yet — a post-match stats screen is a cheap win.~~
  Done: the result screen.
