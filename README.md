# Krunkball (iOS)

**Krunkball** is a native Swift + SpriteKit remake of Ben Olding's 2009 Flash classic *Crunchball 3000*: two teams of ten,
one ball, full-contact, get it in the goal. The long-term plan mirrors the original's structure (four
divisions, 32 teams, training, equipment, transfers, the fine-risk "supplements") and improves on it
where the Flash game was rough. See [docs/DESIGN.md](docs/DESIGN.md).

**Current milestone: pick a club, sign players, play the season.** Title menu, 32 teams across four
divisions, a manager career with credits and a transfer market, three difficulty settings, and the
match itself.

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
| Move | drag anywhere on the left of the screen — the stick is drawn at rest bottom-left and jumps to your thumb | `W A S D` or arrows |
| Pass (with ball) / Switch player (without) | blue button | `H` or Space |
| Shoot (with ball) / Tackle (without) | red button | `G` or Return |
| Cycle formation | `FORM` button, top right | `J` |

The keyboard mapping is the original's (WASD + G / H / J), which is also the only way to move and
press a button at the same time in the Simulator, since it sends one touch at a time.

The stick is always visible, has a dead zone so a resting thumb does not drift, and the first
kickoff puts a *DRAG HERE TO MOVE* prompt next to it. The menu's **HOW TO PLAY** panel lists the
same thing. If you put the phone down mid-match, the AI takes your athlete after 1.5 seconds and
hands it straight back the moment you touch the stick.

## How the match works

- **Arena**: 1600 x 900 walled deck, two halves of 120 seconds. The ball rebounds off the walls; the
  only openings are the goal mouths. The net at each end is tinted with the colours of the side
  defending it.
- **Possession**: anyone upright who touches a loose or flying ball takes it. The thrower cannot catch
  their own throw straight back. A tackled carrier drops it and cannot scoop it up for a moment.
- **Tackles**: a short lunge in your facing direction. Contact triggers a strength contest with a random
  swing; the loser hits the deck (1.4 s for the victim, 0.7 s for a failed tackler).
- **Stamina**: sprinting drains it, easing off pays it back, and a tired athlete is a slower one. The
  speed stat doubles as fitness. Watch the bar under the athlete you are steering.
- **Passing**: picks the best teammate in the cone you are aiming at (stick direction, else facing) and
  leads them. No one there? It goes where you aimed.
- **Shooting**: always towards the goal you attack; the stick nudges the aim across the mouth. Throwing
  stat adds pace and tightens the spread. Keepers *catch* shots that hit them, which removes the
  original's knock-the-keeper-over-and-walk-it-in exploit.
- **Control**: you steer the carrier when your side has the ball, otherwise the highlighted player.
  Control auto-jumps to the nearest player when you lose the ball; the blue button cycles manually.
- **AI**: two to four players press the ball depending on difficulty, the rest hold formation shape
  anchored on the ball. The carrier drives at goal, sidesteps pressure, shoots in range, and passes to
  an open teammate when closed down. Decisions are throttled (`aiThinkInterval` x the difficulty's
  multiplier) so the AI has human-ish reaction time.

**Difficulty** changes three things at once: how fast the AI reacts, how many of them press the ball,
and the opposition's stats (casual −9, pro 0, brutal +9 across the board). Your own squad is never
rescaled.

All the numbers live in `Krunkball/Game/Tuning.swift`.

## Career

Take over any of the 32 clubs. You get the squad it comes with, 120 credits, and a fixture list
against the other seven in your division, home and away.

- **Squad**: the ten that take the deck are the first ten on the list; slot GK plays in goal. Tap two
  athletes to swap them, which is how a bench signing gets into the side (and how you put a better
  arm in goal).
- **Transfer market**: a dozen free agents, priced off their overall — steeply, so a star is a real
  decision. Sign up to a 14-man squad. Release someone and you get half the fee back.
- **Roles** are read off the stats rather than stored: BLOCKER (strength), RUNNER (speed), GUNNER
  (throwing), ALL-ROUND. A blocker is drawn visibly broader than a runner.
- **Money** comes from results: a win pays best, goals always pay something.

The save is JSON in `UserDefaults`, written after every signing and every result.

## Layout

```
project.yml                        XcodeGen spec
Krunkball/
  App/            SwiftUI app entry + UIKit host controller (SKView, keyboard)
    Menu/         AppModel (navigation), title menu, team picker, club / recruitment, result card
  Game/
    Tuning.swift  every gameplay constant, plus the Difficulty settings
    Geometry.swift
    Model/        PlayerStats + roles, Kit, TeamData, Formation, the 32-team League,
                  Career (save + transfers), MatchConfig / MatchResult
    Match/        MatchScene (loop, arena, camera, input), +Actions (ball, tackles, goals), +AI
                  PlayerNode (drawn athlete, stamina), BallNode
    UI/           TouchControls (visible stick + buttons), HUD (score, clock, name card, stamina)
  Resources/      asset catalog (icon placeholder)
docs/DESIGN.md    original-game reference, improvements list, roadmap
```

## Tests

```bash
xcodebuild -project Krunkball.xcodeproj -scheme Krunkball \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

`KrunkballTests` drives the match headlessly: mechanics (pickup, pass, shoot, tackle, switch, goals,
walls, a full match to full time), the feel systems (stick dead zone, stamina drain and recovery,
the idle handoff, difficulty), `CareerTests` (the ladder, signings, releases, results, save round
trip) and `BalanceBenchmark`, ten AI-vs-AI matches that must land between 0.5 and 1.6 goals a minute.
Run it after touching `Tuning.swift` or the AI.

## Status

See `HANDOFF.md` for what each session changed and what is next; `CLAUDE.md` for the working rules.
