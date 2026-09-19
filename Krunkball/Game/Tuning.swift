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
    static let playerRadius: CGFloat = 16
    static let ballRadius: CGFloat = 9

    // MARK: Movement
    static let baseSpeed: CGFloat = 170          // top speed at speed-stat 0
    static let speedPerStat: CGFloat = 1.5       // + stat * this (stat 100 -> +150)
    static let acceleration: CGFloat = 1100
    static let downedDrag: CGFloat = 6           // exponential velocity decay while down / recovering

    // MARK: Tackling
    static let tackleLungeSpeed: CGFloat = 430
    static let tackleDuration: TimeInterval = 0.22
    static let tackleRecovery: TimeInterval = 0.32
    static let tackleCooldown: TimeInterval = 0.75
    static let tackleReach: CGFloat = 10         // extra reach beyond body contact
    static let knockdownDuration: TimeInterval = 1.4
    static let failedTackleDuration: TimeInterval = 0.7

    // MARK: Ball handling
    static let passSpeedBase: CGFloat = 640
    static let passSpeedPerStat: CGFloat = 2.5
    static let shotSpeedBase: CGFloat = 860
    static let shotSpeedPerStat: CGFloat = 3.0
    static let passAirTime: TimeInterval = 0.55
    static let shotAirTime: TimeInterval = 0.9
    static let throwerImmunity: TimeInterval = 0.25   // thrower can't re-catch their own throw immediately
    static let dropPickupDelay: TimeInterval = 0.6    // a tackled carrier can't scoop it straight back up
    static let ballDragPerSecond: CGFloat = 0.22      // fraction of velocity kept after 1 s rolling
    static let wallRestitution: CGFloat = 0.72
    static let catchSlack: CGFloat = 4

    // MARK: Match
    static let halfLength: TimeInterval = 90
    static let kickoffFreeze: TimeInterval = 1.2
    static let goalCelebration: TimeInterval = 2.2
    static let halfTimePause: TimeInterval = 2.5

    // MARK: AI
    static let aiThinkInterval: TimeInterval = 0.15
    static let aiShootRange: CGFloat = 360
    static let aiPressureDistance: CGFloat = 80
    static let aiChasersPerTeam = 2

    // MARK: Camera
    static let cameraVisibleHeight: CGFloat = 640     // world points shown top-to-bottom
    static let cameraFollowRate: CGFloat = 6
}
