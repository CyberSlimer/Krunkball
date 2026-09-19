import CoreGraphics
import Foundation

/// Every gameplay number lives here so the feel can be tuned without touching logic.
/// Units: points in scene space (origin at the centre spot, x runs goal-to-goal), seconds.
enum Tuning {
    // MARK: Arena
    static let fieldLength: CGFloat = 1600
    static let fieldWidth: CGFloat = 900
    static let goalHalfWidth: CGFloat = 100
    static let goalDepth: CGFloat = 50
    static let wallMargin: CGFloat = 70          // extra world the camera may show beyond the walls

    // MARK: Bodies
    static let playerRadius: CGFloat = 16        // collision radius; the drawn athlete is larger
    static let playerVisualScale: CGFloat = 1.3  // drawn size relative to the collision radius
    static let ballRadius: CGFloat = 9

    // MARK: Movement
    // Pace pass 2026-09-19: the first playable build read as a blur. Top speed is down ~22% and
    // acceleration is heavier, so an athlete now crosses the 1600-point deck in about 8 s instead of 6.
    static let baseSpeed: CGFloat = 132          // top speed at speed-stat 0
    static let speedPerStat: CGFloat = 1.15      // + stat * this (stat 100 -> +115)
    static let acceleration: CGFloat = 880
    static let downedDrag: CGFloat = 6           // exponential velocity decay while down / recovering
    static let carrierSpeedPenalty: CGFloat = 0.93   // holding the ball costs you a little pace

    // MARK: Stamina
    // Sprinting drains; easing off recovers. Keeps play from being 10 athletes at top speed for
    // the whole half, which was most of why the prototype felt frantic.
    static let staminaSprintThreshold: CGFloat = 0.55  // fraction of top speed above which stamina drains
    static let staminaDrainPerSecond: CGFloat = 0.085  // at full sprint
    static let staminaRecoverPerSecond: CGFloat = 0.16 // while at or below the threshold
    static let staminaFloorSpeed: CGFloat = 0.74       // speed multiplier at zero stamina
    static let staminaTackleCost: CGFloat = 0.07       // spent per tackle attempt
    static let staminaPerEndurance: CGFloat = 0.004    // drain reduction per point of the speed stat
    static let staminaBreakRecovery: CGFloat = 0.4     // puff handed back at the kickoff after a goal

    // MARK: Tackling
    static let tackleLungeSpeed: CGFloat = 360
    static let tackleDuration: TimeInterval = 0.24
    static let tackleRecovery: TimeInterval = 0.34
    static let tackleCooldown: TimeInterval = 0.8
    static let tackleReach: CGFloat = 10         // extra reach beyond body contact
    static let knockdownDuration: TimeInterval = 1.4
    static let failedTackleDuration: TimeInterval = 0.7

    // MARK: Ball handling
    static let passSpeedBase: CGFloat = 520
    static let passSpeedPerStat: CGFloat = 2.0
    static let shotSpeedBase: CGFloat = 720
    static let shotSpeedPerStat: CGFloat = 2.4
    static let passAirTime: TimeInterval = 0.6
    static let shotAirTime: TimeInterval = 0.95
    static let throwerImmunity: TimeInterval = 0.25   // thrower can't re-catch their own throw immediately
    static let dropPickupDelay: TimeInterval = 0.6    // a tackled carrier can't scoop it straight back up
    static let ballDragPerSecond: CGFloat = 0.18      // fraction of velocity kept after 1 s rolling
    static let wallRestitution: CGFloat = 0.68
    static let catchSlack: CGFloat = 4
    static let shotSpread: CGFloat = 0.26             // max aim error (radians) at throwing 0; 0 at throwing 100

    // MARK: Match
    static let halfLength: TimeInterval = 120
    static let kickoffFreeze: TimeInterval = 1.6
    static let kickoffClearance: CGFloat = 170        // the receiving side is held this far back from the spot
    static let goalCelebration: TimeInterval = 2.4
    static let halfTimePause: TimeInterval = 2.5

    // MARK: AI
    static let aiThinkInterval: TimeInterval = 0.18
    static let aiShootRange: CGFloat = 290           // + throwing * 1.6; shoots from here when closed down
    static let aiCloseShotRange: CGFloat = 230       // always shoots from here
    static let aiPressureDistance: CGFloat = 80
    static let aiSpeculativeShotChance: CGFloat = 0.03  // per think tick, in range but not under pressure
    static let aiChasersPerTeam = 3
    static let keeperDistributionDelay: TimeInterval = 0.25
    static let keeperCatchProtection: TimeInterval = 0.6   // keeper cannot be tackled this long after a catch
    static let keeperReadAhead: TimeInterval = 1.5   // how far ahead the keeper reads a shot's path (s)
    static let keeperCatchBonus: CGFloat = 10        // extra catch reach for keepers (gloves)
    /// The controlled athlete falls back to the AI after this long with no stick or key input, so an
    /// idle human side does not stand and watch (which is how the prototype conceded).
    static let idleHandoffDelay: TimeInterval = 1.5

    // MARK: Camera
    static let cameraVisibleHeight: CGFloat = 700     // world points shown top-to-bottom
    static let cameraFollowRate: CGFloat = 5.2

    // MARK: Controls
    static let stickRadius: CGFloat = 62
    static let stickKnobRadius: CGFloat = 27
    static let stickDeadZone: CGFloat = 0.14          // stick fraction ignored before the athlete moves
    static let stickHomeInset = CGPoint(x: 112, y: 96) // resting stick centre, in from the bottom-left
    static let stickDragLimit: CGFloat = 0.55         // fraction of the view width that starts a stick drag
    static let buttonRadius: CGFloat = 46
    static let coachHintDuration: TimeInterval = 6    // how long the "drag to move" hint stays up

    // MARK: Animation
    static let runCycleRate: CGFloat = 0.055          // stride phase advanced per point travelled
    static let runCycleSwing: CGFloat = 5.4           // limb travel, in points, at full stride

    // MARK: Career
    static let startingCredits = 120
    static let maxSquadSize = 14
    static let releaseRefund: Double = 0.5            // fraction of a player's value returned on release
}

/// AI sharpness and opponent quality. Picked on the menu; the prototype only had one setting,
/// which read as "hard" because the AI reacted in 0.15 s and pressed with three athletes.
enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case casual, pro, brutal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casual: return "CASUAL"
        case .pro: return "PRO"
        case .brutal: return "BRUTAL"
        }
    }

    var blurb: String {
        switch self {
        case .casual: return "Slow reactions, two pressers, a weaker squad against you."
        case .pro: return "An even match. The setting the balance benchmark targets."
        case .brutal: return "Sharp reactions, four pressers, a stronger squad against you."
        }
    }

    /// Multiplies `Tuning.aiThinkInterval`: higher means slower reactions.
    var thinkMultiplier: TimeInterval {
        switch self {
        case .casual: return 2.2
        case .pro: return 1.0
        case .brutal: return 0.7
        }
    }

    /// How many opposition athletes press the ball.
    var chasers: Int {
        switch self {
        case .casual: return 2
        case .pro: return Tuning.aiChasersPerTeam
        case .brutal: return 4
        }
    }

    /// Added to every stat on the AI side when the match is built.
    var opponentStatBonus: Int {
        switch self {
        case .casual: return -9
        case .pro: return 0
        case .brutal: return 9
        }
    }
}
