//
//  FirstAidKnowledgeBase.swift
//  EmergencyFirst
//
//  Option-A RAG: a small curated set of first-aid snippets from the three
//  approved sources (WebMD, MedlinePlus, American Red Cross) plus a retriever
//  that matches documents to an observed wound type.
//
//  The guidance text is PARAPHRASED/summarized general first-aid information,
//  not copied verbatim, and each document links back to its source so the UI
//  can cite it. This works offline and is fast — ideal for a live demo.
//

import Foundation

protocol GuidanceRetriever: Sendable {
    /// Returns the most relevant guidance documents for the observed features.
    func retrieve(for analysis: WoundAnalysis) -> [GuidanceDocument]
}

nonisolated struct FirstAidKnowledgeBase: GuidanceRetriever {

    /// The curated corpus. Keep entries short, paraphrased, and cited.
    static let documents: [GuidanceDocument] = [
        GuidanceDocument(
            source: .redCross,
            topic: "Minor cuts and scrapes",
            content: "For a small wound, apply gentle pressure with a clean cloth until bleeding stops. Rinse with clean water, avoid scrubbing, pat dry, and cover with a sterile bandage. Watch for signs of infection over the next days.",
            keywords: ["cut", "laceration", "scrape", "abrasion", "graze"],
            url: "https://www.redcross.org/take-a-class/first-aid"
        ),
        GuidanceDocument(
            source: .medlinePlus,
            topic: "Wound care basics",
            content: "Keep a minor wound clean and covered. Change the dressing when it becomes wet or dirty. Seek care if the wound is deep, gaping, from a dirty or rusty object, or if redness, warmth, swelling, or pus develops.",
            keywords: ["cut", "laceration", "wound", "scrape", "puncture"],
            url: "https://medlineplus.gov/woundsandinjuries.html"
        ),
        GuidanceDocument(
            source: .webMD,
            topic: "Treating minor burns",
            content: "For a minor burn, cool it under cool (not cold) running water for several minutes. Do not apply ice, butter, or ointments. Cover loosely with a clean, non-stick dressing. Seek medical care for large burns, burns on the face, hands, or joints, or any blistering burn.",
            keywords: ["burn", "scald", "blister"],
            url: "https://www.webmd.com/first-aid/burns-treatment"
        ),
        GuidanceDocument(
            source: .medlinePlus,
            topic: "Bruises",
            content: "For a bruise, rest the area and apply a cold pack wrapped in cloth for short periods to reduce swelling. Elevate if possible. Seek care if the bruise is very large, extremely painful, or appeared without a clear cause.",
            keywords: ["bruise", "contusion"],
            url: "https://medlineplus.gov/bruises.html"
        ),
        GuidanceDocument(
            source: .redCross,
            topic: "Puncture wounds",
            content: "For a puncture wound, let it bleed a little to help clean it, then rinse with clean water and cover. Do not remove a deeply embedded object. Puncture wounds carry infection risk — seek medical care, and check whether a tetanus shot is needed.",
            keywords: ["puncture", "nail", "splinter", "embedded"],
            url: "https://www.redcross.org/take-a-class/first-aid"
        ),
        GuidanceDocument(
            source: .redCross,
            topic: "Severe bleeding",
            content: "For heavy bleeding, call emergency services immediately. Apply firm, direct pressure with a clean cloth and keep pressing. Do not remove soaked cloths — add more on top. This is an emergency and needs professional care right away.",
            keywords: ["heavy", "severe", "bleeding", "deep", "gaping"],
            url: "https://www.redcross.org/take-a-class/first-aid"
        )
    ]

    func retrieve(for analysis: WoundAnalysis) -> [GuidanceDocument] {
        // Build a haystack of terms from the observed features.
        var terms = analysis.apparentWoundType.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)

        // Heavy/moderate bleeding pulls in the severe-bleeding guidance.
        if analysis.bleedingVisibility == .heavy || analysis.bleedingVisibility == .moderate {
            terms.append(contentsOf: ["heavy", "severe", "bleeding"])
        }

        // Score each document by keyword overlap.
        let scored = Self.documents.map { doc -> (GuidanceDocument, Int) in
            let score = doc.keywords.reduce(0) { partial, keyword in
                partial + (terms.contains(where: { keyword.contains($0) || $0.contains(keyword) }) ? 1 : 0)
            }
            return (doc, score)
        }

        let matches = scored.filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }

        // Always return something: fall back to general wound-care basics.
        if matches.isEmpty {
            return Self.documents.filter { $0.topic == "Wound care basics" }
        }
        return Array(matches.prefix(3))
    }
}
