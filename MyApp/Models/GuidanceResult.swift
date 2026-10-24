//
//  GuidanceResult.swift
//  EmergencyFirst
//
//  The structured result returned by the guidance engine. Using a model
//  (instead of a plain String) gives the UI something richer to show and
//  gives the engine teammate a clear contract to fill in.
//

import Foundation

nonisolated struct GuidanceResult: Identifiable, Equatable {
    let id = UUID()

    /// A short headline, e.g. "Possible minor burn".
    let title: String

    /// Ordered first-aid steps the user should follow.
    let steps: [String]

    /// Whether the situation looks serious enough to call emergency services.
    /// The UI uses this to emphasize the warning.
    let isSevere: Bool

    /// The observable features the vision model extracted (nil for the stub).
    var analysis: WoundAnalysis? = nil

    /// The trusted-source documents this guidance was grounded in (for citation).
    var sources: [GuidanceDocument] = []

    /// Suggested supplies/tools that could help (e.g. bandage, tourniquet).
    var supplies: [Supply] = []

    /// Longer-term care notes (e.g. keep clean, watch for infection, OTC options).
    var longerTermCare: [String] = []

    static func == (lhs: GuidanceResult, rhs: GuidanceResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// A recommended supply/tool or medication category, with a reason and an icon.
nonisolated struct Supply: Identifiable, Equatable, Codable {
    var id: String { name }

    /// Item name, e.g. "Sterile gauze", "Tourniquet", "Pain reliever (OTC)".
    let name: String

    /// Short reason it helps, in plain language.
    let reason: String

    /// An SF Symbol name used as an illustrative icon in the UI.
    let symbol: String

    /// Which "how to use" animation + sourced technique applies to this item.
    /// Derived from the name/symbol so the model's JSON doesn't need to change.
    var technique: FirstAidTechnique {
        let n = name.lowercased()
        if n.contains("tourniquet") { return .tourniquet }
        if n.contains("gauze") || n.contains("bandage") || n.contains("dressing") || symbol == "bandage.fill" { return .bandage }
        if n.contains("gloves") || n.contains("hand") || symbol == "hand.raised.fill" { return .pressure }
        if n.contains("water") || n.contains("saline") || n.contains("rinse") || symbol == "drop.fill" { return .irrigate }
        if n.contains("ice") || n.contains("cold") || symbol == "snowflake" { return .coldPack }
        return .none
    }
}

/// A first-aid technique that has a small illustrative animation + sourced
/// steps. "none" means no animation is shown for that supply.
nonisolated enum FirstAidTechnique: String, Equatable {
    case tourniquet, bandage, pressure, irrigate, coldPack, none

    /// A short, user-facing title for the "how to use" section.
    var title: String {
        switch self {
        case .tourniquet: return "How to apply a tourniquet"
        case .bandage:    return "How to apply a bandage"
        case .pressure:   return "How to apply direct pressure"
        case .irrigate:   return "How to rinse the wound"
        case .coldPack:   return "How to use a cold pack"
        case .none:       return ""
        }
    }

    /// Technique steps, paraphrased from the three approved sources. Each entry
    /// carries which source it is grounded in, for on-screen citation.
    var steps: [(text: String, source: GuidanceDocument.Source)] {
        switch self {
        case .tourniquet:
            return [
                ("Only for life-threatening limb bleeding that won't stop with pressure.", .redCross),
                ("Place it 2–3 inches above the wound, not on a joint.", .redCross),
                ("Tighten until the bright-red bleeding stops, then secure it.", .redCross),
                ("Note the time applied and get emergency help immediately.", .redCross)
            ]
        case .bandage:
            return [
                ("Clean and dry the area first if you can.", .medlinePlus),
                ("Place a sterile pad over the wound.", .redCross),
                ("Wrap firmly enough to stay put, but not so tight it cuts off circulation.", .webMD),
                ("Check fingers/toes stay warm and pink after wrapping.", .webMD)
            ]
        case .pressure:
            return [
                ("Use a clean cloth or sterile gauze over the wound.", .redCross),
                ("Press firmly and steadily — don't keep lifting to peek.", .redCross),
                ("If blood soaks through, add more cloth on top; don't remove it.", .redCross),
                ("Keep pressing until bleeding slows or help arrives.", .medlinePlus)
            ]
        case .irrigate:
            return [
                ("Rinse under clean, cool running water.", .medlinePlus),
                ("Let water run over it; avoid hard scrubbing.", .redCross),
                ("Remove visible dirt gently if you can.", .medlinePlus),
                ("Pat dry with a clean cloth before covering.", .webMD)
            ]
        case .coldPack:
            return [
                ("Wrap the cold pack in a thin cloth — never apply ice directly.", .webMD),
                ("Apply for about 10–20 minutes at a time.", .medlinePlus),
                ("Take breaks to let the skin rewarm.", .webMD)
            ]
        case .none:
            return []
        }
    }
}
