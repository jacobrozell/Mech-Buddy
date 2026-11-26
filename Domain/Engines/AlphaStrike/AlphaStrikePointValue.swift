import Foundation

/// Point Value by MechWarrior Skill (Alpha Strike Quick-Start Rulebook p. 35, Improved Skill PV Increase Table).
public enum AlphaStrikePointValue {
    /// PV added per Skill point better than 4: base 0–7 → 1, 8–12 → 2, … 48–52 → 10, then +1 per 5 base PV.
    public static func increasePerSkillPoint(base: Int) -> Int {
        guard base > 7 else { return 1 }
        return (base - 7 + 4) / 5 + 1
    }

    /// The card's PV (which assumes Skill 4) adjusted for a better pilot. A Skill 2 pilot in a 39 PV ’Mech
    /// costs 39 + 8 × 2 = 55. Skills worse than 4 aren't in the Quick-Start, so they keep the card's PV.
    public static func adjusted(base: Int, skill: Int) -> Int {
        base + increasePerSkillPoint(base: base) * max(0, 4 - skill)
    }
}
