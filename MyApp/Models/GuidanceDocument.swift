//
//  GuidanceDocument.swift
//  EmergencyFirst
//
//  A single piece of first-aid guidance retrieved from a trusted source.
//  These are the "documents" our Option-A RAG retrieves from and cites.
//
//  Only three sources are permitted: WebMD, MedlinePlus, American Red Cross.
//

import Foundation

nonisolated struct GuidanceDocument: Identifiable, Equatable, Sendable {
    let id = UUID()

    /// Which trusted source this guidance came from.
    let source: Source

    /// Human-readable topic, e.g. "Minor cuts and scrapes".
    let topic: String

    /// The first-aid guidance text (summarized/paraphrased from the source).
    let content: String

    /// Keywords used to match this document to an observed wound type.
    let keywords: [String]

    /// A link back to the source material for citation.
    let url: String

    nonisolated enum Source: String, Equatable, Sendable {
        case webMD = "WebMD"
        case medlinePlus = "MedlinePlus"
        case redCross = "American Red Cross"
    }

    static func == (lhs: GuidanceDocument, rhs: GuidanceDocument) -> Bool {
        lhs.id == rhs.id
    }
}
