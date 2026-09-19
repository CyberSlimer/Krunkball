# Krunkball — design notes

## The original (reference)

*Crunchball 3000*, Ben Olding / DJStatika, Flash, May 2009 (Miniclip, Kongregate, Armor Games).
Openly inspired by *Speedball 2: Brutal Deluxe*. Premise: in the third millennium every other sport
has been banned; this is what is left.

What it had:

- 10 v 10 on a walled deck, score by getting the ball into the opponent's goal.
- Tackle / shoot on one key (`G`), pass / switch player on another (`H`), formation change (`J`), WASD to move.
- 4 divisions, 32 teams, 320 named players with individual abilities.
- Manager layer: train players, upgrade equipment, transfers, performance-enhancing drugs with the risk of a fine.
- Customise kit colours, team name, player names.
- Two-player local mode on one keyboard.

Known rough edges players remember:

- Throw the ball at the keeper, knock him down, walk it in.
- AI teammates could be passive; pass targeting was loose.
- No save/resume mid-season, no touch support (it was Flash).

## What is built

**Milestone 1 — the match.** Human vs AI: arena, physics-free kinematics, tackles, passes, shots,
keepers, two halves, formation toggle, stick + two buttons, keyboard fallback.

**Milestone 2 — the front end (2026-09-19).** Title menu with the controls spelled out, the full
32-team ladder across four divisions, quick match with a team picker on both sides, three difficulty
settings, and a manager career: credits, a transfer market, squad selection, a home-and-away fixture
list and a saved season. Plus a pace pass (slower athletes, slower ball, longer halves, stamina) and
athletes drawn as athletes rather than discs.

## Improvements over the original

| Original | Here |
|---|---|
| Ball knocks the keeper over | Keeper catches any ball that touches him; only a tackle fells him |
| Control stuck on a downed player | Control auto-jumps to the nearest upright player |
| Pass goes roughly "forward" | Cone-based target pick with lead on a moving receiver; falls back to the aimed direction |
| Frame-perfect AI reactions | AI decisions throttled (`aiThinkInterval`) for human-ish timing |
| Keyboard only | Touch-first (floating stick, big buttons), keyboard kept for the Simulator and iPad |
| Fixed zoom | Camera zoom derived from view height so every device shows the same slice of deck |
| One speed setting | Casual / Pro / Brutal change AI reaction time, how many press, and opposition stats |
| Everyone sprints forever | Stamina drains on the sprint and recovers when you ease off |
| Stats are numbers on a screen | Build, role and kit are drawn on the athlete — a blocker is visibly a slab |
| Nothing tells you the controls | Visible stick with a dead zone, a first-kickoff prompt, a HOW TO PLAY panel |
| Put the pad down and concede | After 1.5 s idle the AI takes your athlete; any input takes it back |

## Roadmap

1. ~~**Feel pass**: speeds, tackle odds, camera, stick dead zone, ball trail when airborne.~~ Done
   2026-09-19, except **haptics on tackles and goals and a short hit-stop on big hits** — still open.
2. **Match polish**: ~~stamina~~, ~~difficulty levels~~ done. Still open: injuries from heavy hits,
   crowd/SFX, replays of goals, pause menu.
3. **Manager layer**: ~~32 teams across 4 divisions~~, ~~transfers~~, ~~season save~~ (JSON in
   `UserDefaults`, not SwiftData yet) done. Still open: a league table and standings, promotion and
   relegation, training (spend credits on speed / strength / throwing), equipment tiers, supplements
   with a fine chance and a suspension risk (an improvement: make the risk visible as odds), and the
   AI sides playing each other's fixtures so the table means something.
4. **Presentation**: athletes are drawn procedurally (helmet, visor, pads, swinging limbs, build from
   the stats) — good enough that sprites are no longer urgent. Still open: customisable kit colours
   and team name, stadiums per division, goal celebrations.
5. **Multiplayer**: local two-player on iPad (split controls) first; Game Center leaderboards for
   season points; online head-to-head later if it earns it.
6. **Ship**: App Store listing, icon, screenshots, TestFlight round with friends who played the original.

## Open questions

- Scoring: the original counted goals as single points. Keep it, or add a bonus for long-range shots
  (Speedball-style) to reward skill? Leaning: keep single points for the mirror, experiment later.
- Match length for mobile: 2 x 90 s read as a blur, so it is 2 x 120 s now — the extra time is what
  lets a possession breathe. Still worth offering a 2 x 60 s "quick match" and longer cup finals;
  `MatchConfig.halfLength` is already per-match, nothing else needs to change.
- Monetisation: none planned. Paid up-front or free with no IAP; no energy timers, no loot.
