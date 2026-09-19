import CoreGraphics
import Foundation

extension CGVector {
    init(angle: CGFloat) { self.init(dx: cos(angle), dy: sin(angle)) }

    var length: CGFloat { (dx * dx + dy * dy).squareRoot() }
    var lengthSquared: CGFloat { dx * dx + dy * dy }
    var angle: CGFloat { atan2(dy, dx) }
    var normalized: CGVector {
        let l = length
        return l > 0.0001 ? CGVector(dx: dx / l, dy: dy / l) : .zero
    }
    var perpendicular: CGVector { CGVector(dx: -dy, dy: dx) }

    func dot(_ o: CGVector) -> CGFloat { dx * o.dx + dy * o.dy }
    func limited(to max: CGFloat) -> CGVector { length > max ? normalized * max : self }

    static func + (a: CGVector, b: CGVector) -> CGVector { CGVector(dx: a.dx + b.dx, dy: a.dy + b.dy) }
    static func - (a: CGVector, b: CGVector) -> CGVector { CGVector(dx: a.dx - b.dx, dy: a.dy - b.dy) }
    static prefix func - (a: CGVector) -> CGVector { CGVector(dx: -a.dx, dy: -a.dy) }
    static func * (a: CGVector, s: CGFloat) -> CGVector { CGVector(dx: a.dx * s, dy: a.dy * s) }
    static func / (a: CGVector, s: CGFloat) -> CGVector { CGVector(dx: a.dx / s, dy: a.dy / s) }
    static func += (a: inout CGVector, b: CGVector) { a = a + b }
    static func *= (a: inout CGVector, s: CGFloat) { a = a * s }
}

extension CGPoint {
    static func + (p: CGPoint, v: CGVector) -> CGPoint { CGPoint(x: p.x + v.dx, y: p.y + v.dy) }
    static func - (p: CGPoint, v: CGVector) -> CGPoint { CGPoint(x: p.x - v.dx, y: p.y - v.dy) }
    static func - (a: CGPoint, b: CGPoint) -> CGVector { CGVector(dx: a.x - b.x, dy: a.y - b.y) }
    static func += (p: inout CGPoint, v: CGVector) { p = p + v }

    func distance(to o: CGPoint) -> CGFloat { (self - o).length }
}

func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }

/// Fraction of a gap closed after `dt` seconds when approaching exponentially at `rate`.
func smoothFactor(rate: CGFloat, dt: CGFloat) -> CGFloat { 1 - exp(-rate * dt) }
