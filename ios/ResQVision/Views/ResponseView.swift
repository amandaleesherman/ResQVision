import SwiftUI

/// The guidance result screen. Emergency escalation comes first and is visually
/// unmissable, followed by steps, warnings, "what we couldn't tell", cited
/// sources, and the disclaimer. A prominent banner marks SAMPLE data.
struct ResponseView: View {
    let response: GuidanceResponse
    let image: UIImage
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if response.observationProvenance.isSample {
                    sampleBanner
                }

                if response.emergency.callNineOneOne {
                    emergencyBanner
                }

                header
                stepsSection
                if !response.warnings.isEmpty { warningsSection }
                if !response.cannotDetermine.isEmpty { cannotDetermineSection }
                if !response.followUpQuestions.isEmpty { followUpSection }
                sourcesSection
                disclaimerSection

                Button("Analyze Another Photo", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Guidance")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Banners

    private var sampleBanner: some View {
        Label(response.observationProvenance.label, systemImage: "testtube.2")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.purple, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emergencyBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Call 911 now", systemImage: "phone.fill")
                .font(.title3.weight(.bold))
            if let reason = response.emergency.reason {
                Text(reason).font(.subheadline)
            }
            Text(response.emergency.message).font(.subheadline)

            if let url = URL(string: "tel://911") {
                Link(destination: url) {
                    Label("Call 911", systemImage: "phone.arrow.up.right.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(response.title).font(.title2.weight(.bold))
            HStack(spacing: 8) {
                Text(response.category.replacingOccurrences(of: "_", with: " ").capitalized)
                Text("•")
                Text("Match: \(response.matchConfidence.rawValue)")
                if response.isFallback {
                    Text("• General guidance")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Steps")
            ForEach(response.steps) { step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(step.order)")
                        .font(.headline)
                        .frame(width: 26, height: 26)
                        .background(Color.accentColor.opacity(0.15), in: Circle())
                    Text(step.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Warnings")
            ForEach(response.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var cannotDetermineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("What we couldn't tell")
            ForEach(response.cannotDetermine, id: \.self) { item in
                Label(item, systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Check for")
            ForEach(response.followUpQuestions, id: \.self) { q in
                Label(q, systemImage: "checklist")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Sources")
            ForEach(response.sources) { source in
                VStack(alignment: .leading, spacing: 2) {
                    if let url = URL(string: source.url) {
                        Link(destination: url) {
                            Text(source.publisher).font(.subheadline.weight(.semibold))
                        }
                    } else {
                        Text(source.publisher).font(.subheadline.weight(.semibold))
                    }
                    if !source.excerpt.isEmpty {
                        Text(source.excerpt).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var disclaimerSection: some View {
        Text(response.disclaimer)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.headline)
    }
}

#Preview {
    NavigationStack {
        ResponseView(
            response: MockScenario.severeBleeding.response(ocrText: ""),
            image: UIImage(systemName: "bandage") ?? UIImage(),
            onDone: {}
        )
    }
}
