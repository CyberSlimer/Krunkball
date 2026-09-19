# Krunkball (iOS)

**Krunkball** is a native Swift + SpriteKit remake of Ben Olding's 2009 Flash classic *Crunchball 3000*: two teams of ten,
one ball, full-contact, get it in the goal. The long-term plan mirrors the original's structure (four
divisions, 32 teams, training, equipment, transfers, the fine-risk "supplements") and improves on it
where the Flash game was rough. See [docs/DESIGN.md](docs/DESIGN.md).

**Current milestone: playable match prototype.** One match, you vs. AI, touch controls, scoring, two halves.

## Build (on a Mac)

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen),
so there is no `.xcodeproj` checked in.

```bash
brew install xcodegen
xcodegen generate
open Krunkball.xcodeproj
```

Then in Xcode: pick your team under *Signing & Capabilities*, choose an iPhone simulator (landscape) or
your device, and Run. Deployment target is iOS 16.

## Controls

| Action | Touch | Keyboard (Simulator / iPad) |
|---|---|---|
| Move | drag anywhere on the left half (floating stick) | `W A S D` or arrows |
| Pass (with ball) / Switch player (without) | blue button | `H` or Space |
| Shoot (with ball) / Tackle (without) | red button | `G` or Return |
| Cycle formation | `FORM` button, top right | `J` |

The keyboard mapping is the original's (WASD + G / H / J), which is also the only way to move and
press a button at the same time in the Simulator, since it sends one touch at a time.

## How the match works

- **Arena**: 1600 x 900 walled deck. The ball rebounds off the walls; the only openings are the goal mouths.
- **Possession**: anyone upright who touches a loose or flying ball takes it. The thrower cannot catch
  their own throw straight back. A tackled carrier drops it and cannot scoop it up for a moment.
- **Tackles**: a short lunge in your facing direction. Contact triggers a strength contest with a random
  swing; the loser hits the deck (1.4 s for the victim, 0.7 s for a failed tackler).
- **Passing**: picks the best teammate in the cone you are aiming at (stick direction, else facing) and
  leads them. No one there? It goes where you aimed.
- **Shooting**: always towards the goal you attack; the stick nudges the aim across the mouth. Throwing
  stat adds pace and tightens the spread. Keepers *catch* shots that hit them, which removes the
  original's knock-the-keeper-over-and-walk-it-in exploit.
- **Control**: you steer the carrier when your side has the ball, otherwise the highlighted player.
  Control auto-jumps to the nearest player when you lose the ball; the blue button cycles manually.
- **AI**: two nearest players press the ball, the rest hold formation shape anchored on the ball. The
  carrier drives at goal, sidesteps pressure, shoots in range, and passes to an open teammate when
  closed down. Decisions are throttled (`aiThinkInterval`) so the AI has human-ish reaction time.

All the numbers live in `Krunkball/Game/Tuning.swift`.

## Layout

```
project.yml                        XcodeGen spec
Krunkball/
  App/            SwiftUI app entry + UIKit host controller (SKView, keyboard)
  Game/
    Tuning.swift  every gameplay constant
    Geometry.swift
    Model/        PlayerStats, TeamData, Formation, seeded roster generator
    Match/        MatchScene (loop, arena, camera, input), +Actions (ball, tackles, goals), +AI
                  PlayerNode, BallNode
    UI/           TouchControls (stick + buttons), HUD (score, clock, messages)
  Resources/      asset catalog (icon placeholder)
docs/DESIGN.md    original-game reference, improvements list, roadmap
```

## Tests

```bash
xcodebuild -project Krunkball.xcodeproj -scheme Krunkball \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

`KrunkballTests` drives the match headlessly: mechanics (pickup, pass, shoot, tackle, switch, goals,
walls, a full match to full time) plus `BalanceBenchmark`, ten AI-vs-AI matches that must average
between 2 and 9 goals. Run it after touching `Tuning.swift` or the AI.

## Status

Builds and runs on the Mac (Xcode 26.6). See `HANDOFF.md` for what the first Mac session changed and
what is next; `CLAUDE.md` for the working rules.
