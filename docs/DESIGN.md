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

## Prototype (milestone 1) — what is built

Playable match, human vs AI: arena, physics-free kinematics, tackles, passes, shots, keepers,
two halves, formation toggle, floating stick + two buttons, keyboard fallback.

## Improvements over the original

| Original | Here |
|---|---|
| Ball knocks the keeper over | Keeper catches any ball that touches him; only a tackle fells him |
| Control stuck on a downed player | Control auto-jumps to the nearest upright player |
| Pass goes roughly "forward" | Cone-based target pick with lead on a moving receiver; falls back to the aimed direction |
| Frame-perfect AI reactions | AI decisions throttled (`aiThinkInterval`) for human-ish timing |
| Keyboard only | Touch-first (floating stick, big buttons), keyboard kept for the Simulator and iPad |
| Fixed zoom | Camera zoom derived from view height so every device shows the same slice of deck |

## Roadmap

1. **Feel pass** (after first build): tune speeds, tackle odds, camera, stick dead zone. Add haptics on
   tackles and goals, a short hit-stop on big hits, ball trail when airborne.
2. **Match polish**: stamina (speed drains, recovers when off the ball), injuries from heavy hits,
   crowd/SFX, replays of goals, pause menu, difficulty levels (AI reaction + stats).
3. **Manager layer**: 32 teams across 4 divisions, fixtures + table, promotion/relegation, season save
   via SwiftData. Training (spend credits on speed / strength / throwing), equipment tiers, transfers,
   supplements with a fine chance and a suspension risk (an improvement: make the risk visible as odds).
4. **Presentation**: proper sprites and animation (idle / run / tackle / down), team kits with
   customisable colours, player names on the HUD, stadiums per division.
5. **Multiplayer**: local two-player on iPad (split controls) first; Game Center leaderboards for
   season points; online head-to-head later if it earns it.
6. **Ship**: App Store listing, icon, screenshots, TestFlight round with friends who played the original.

## Open questions

- Scoring: the original counted goals as single points. Keep it, or add a bonus for long-range shots
  (Speedball-style) to reward skill? Leaning: keep single points for the mirror, experiment later.
- Match length for mobile: 2 x 90 s prototype. Real sessions probably want 2 x 60 s with a "quick match"
  option and 2 x 120 s for cup finals.
- Monetisation: none planned. Paid up-front or free with no IAP; no energy timers, no loot.
