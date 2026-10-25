import Foundation

/// The input the app sends to the analysis layer.
///
/// This mirrors the guidance engine's `Observation` contract (spec §5.3) so the
/// exact same type can be sent to the real backend later. The vision/OCR step
/// produces a `description` (+ optional `labels`); the guidance engine turns it
/// into first-aid steps. The engine never sees the image itself.
struct Observation: Codable, Equatable {
    /// Where the observation came from.
    enum Source: String, Codable {
        case visionModel = "vision_model"
        case sample
        case userText = "user_text"
    }

    var source: Source
    /// `true` for demo/hard-coded observations. Surfaced to the user so sample
    /// data is never mistaken for a real analysis.
    var isSample: Bool
    /// Free text describing what was seen. May be empty if `labels` exist.
    var description: String
    /// Optional labels from a vision model, each with a confidence in [0, 1].
    var labels: [Label]
    /// e.g. "hand", "head", "leg".
    var bodyLocation: String?
    /// Things the vision step could not determine.
    var uncertainties: [String]

    init(
        source: Source,
        isSample: Bool,
        description: String,
        labels: [Label] = [],
        bodyLocation: String? = nil,
        uncertainties: [String] = []
    ) {
        self.source = source
        self.isSample = isSample
        self.description = description
        self.labels = labels
        self.bodyLocation = bodyLocation
        self.uncertainties = uncertainties
    }

    // Snake_case keys to match the backend JSON contract exactly.
    enum CodingKeys: String, CodingKey {
        case source
        case isSample = "is_sample"
        case description
        case labels
        case bodyLocation = "body_location"
        case uncertainties
    }

    struct Label: Codable, Equatable {
        var name: String
        var confidence: Double
    }
}
