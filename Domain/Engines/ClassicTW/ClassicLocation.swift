import Foundation

// Classic BattleTech (A Game of Armored Combat rules). Shares no types with Alpha Strike (ClassicModeSpec).

/// The eight hit locations on a 'Mech record sheet.
public enum ClassicLocation: String, Codable, CaseIterable, Sendable {
    case head = "HD"
    case centerTorso = "CT"
    case leftTorso = "LT"
    case rightTorso = "RT"
    case leftArm = "LA"
    case rightArm = "RA"
    case leftLeg = "LL"
    case rightLeg = "RL"

    /// Critical slots: 6 in the head and legs, 12 elsewhere.
    public var slots: Int {
        switch self {
        case .head, .leftLeg, .rightLeg: 6
        default: 12
        }
    }

    /// Armor key for the rear of a torso location ("CTR"); `nil` where there's no rear armor.
    public var rearKey: String? {
        switch self {
        case .centerTorso, .leftTorso, .rightTorso: rawValue + "R"
        default: nil
        }
    }
}
