import Foundation

/// The structured guidance returned by the analysis layer.
///
/// Mirrors the guidance engine's `GuidanceResponse` contract (spec §5.4) field
/// for field, so the real backend's JSON decodes directly into this type.
struct GuidanceResponse: Codable, Equatable {
    var emergency: Emergency
    var category: String
    var matchConfidence: MatchConfidence
    var title: String
    var steps: [Step]
    var warnings: [String]
    var sources: [Source]
    var observationProvenance: ObservationProvenance
    var cannotDetermine: [String]
    var followUpQuestions: [String]
    var disclaimer: String
    var isFallback: Bool
    var engineVersion: String

    enum CodingKeys: String, CodingKey {
        case emergency
        case category
        case matchConfidence = "match_confidence"
        case title
        case steps
        case warnings
        case sources
        case observationProvenance = "observation_provenance"
        case cannotDetermine = "cannot_determine"
        case followUpQuestions = "follow_up_questions"
        case disclaimer
        case isFallback = "is_fallback"
        case engineVersion = "engine_version"
    }

    enum MatchConfidence: String, Codable {
        case high, medium, low, none
    }

    /// Always present. `callProsent91` style: `callNineOneOne` is false when no
    /// red flags were detected.
    struct Emergency: Codable, Equatable {
        var callNineOneOne: Bool
        var reason: String?
        var message: String

        enum CodingKeys: String, CodingKey {
            case callNineOneOne = "call_911"
            case reason
            case message
        }
    }

    struct Step: Codable, Equatable, Identifiable {
        var order: Int
        var text: String
        var sourceId: String

        // Stable identity for SwiftUI lists.
        var id: Int { order }

        enum CodingKeys: String, CodingKey {
            case order
            case text
            case sourceId = "source_id"
        }
    }

    struct Source: Codable, Equatable, Identifiable {
        var id: String
        var publisher: String
        var title: String
        var url: String
        var excerpt: String
        var retrievedDate: String

        enum CodingKeys: String, CodingKey {
            case id
            case publisher
            case title
            case url
            case excerpt
            case retrievedDate = "retrieved_date"
        }
    }

    struct ObservationProvenance: Codable, Equatable {
        var source: Observation.Source
        var isSample: Bool
        var label: String

        enum CodingKeys: String, CodingKey {
            case source
            case isSample = "is_sample"
            case label
        }
    }
}
