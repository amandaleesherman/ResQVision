//
//  ResultsView.swift
//  EmergencyFirst
//
//  Shows the first-aid guidance produced by the engine, alongside a small
//  thumbnail of the analyzed photo. "Start Over" returns to the home screen.
//
//  Includes a visible safety reminder: this app is guidance only and not a
//  substitute for professional emergency services.
//

import SwiftUI

struct ResultsView: View {
    let appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("First-Aid Guidance")
                    .font(.title2)
                    .fontWeight(.bold)

                // Small thumbnail of what was analyzed.
                if let image = appState.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let result = appState.result {
                    guidance(for: result)
                } else {
                    // Error / no-result fallback.
                    Label {
                        Text(appState.errorMessage ?? "No guidance available.")
                    } icon: {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                    }
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Safety reminder (always shown).
                Label {
                    Text("This is guidance only. In a real emergency, call your local emergency number (911 in the US) immediately.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.footnote)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    appState.reset()
                } label: {
                    Label("Start Over", systemImage: "house.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top, 8)
            }
            .padding()
        }
    }

    /// Renders a structured GuidanceResult: title, severity, numbered steps.
    @ViewBuilder
    private func guidance(for result: GuidanceResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.title)
                .font(.headline)

            if result.isSevere {
                Label("This may need emergency care now.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            // Immediate steps, each with an illustrative icon.
            Text("Immediate steps")
                .font(.subheadline).fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(result.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: stepSymbol(for: step))
                            .font(.title3)
                            .foregroundStyle(.red)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Step \(index + 1)")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(step)
                        }
                    }
                }
            }

            // Call 911 — placed right after the immediate steps. Emphasized
            // when the situation looks severe, but always available.
            callEmergencyButton(isSevere: result.isSevere)

            // Supplies / tools that could help, each with an expandable
            // "how to use" animation + sourced steps.
            if !result.supplies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Helpful supplies & tools")
                        .font(.subheadline).fontWeight(.semibold)
                    ForEach(result.supplies) { supply in
                        SupplyRow(supply: supply)
                    }
                }
                .padding(.top, 4)
            }

            // Longer-term care.
            if !result.longerTermCare.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Longer-term care")
                        .font(.subheadline).fontWeight(.semibold)
                    ForEach(Array(result.longerTermCare.enumerated()), id: \.offset) { _, note in
                        Label(note, systemImage: "checkmark.circle")
                            .font(.footnote)
                    }
                }
                .padding(.top, 4)
            }

            // Observable features extracted by the vision model (not a diagnosis).
            if let analysis = result.analysis {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What the photo appears to show")
                        .font(.subheadline).fontWeight(.semibold)
                    Text("Appears to be: \(analysis.apparentWoundType)")
                    Text("Redness: \(analysis.visibleRedness.rawValue) · Bleeding: \(analysis.bleedingVisibility.rawValue)")
                    if analysis.imageQuality == .poor || analysis.uncertainty >= 0.5 {
                        Text("The photo may be unclear, so treat this with extra caution.")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }

            // Citations: the trusted sources this guidance was grounded in.
            if !result.sources.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sources")
                        .font(.subheadline).fontWeight(.semibold)
                    ForEach(result.sources) { doc in
                        if let url = URL(string: doc.url) {
                            Link("\(doc.source.rawValue): \(doc.topic)", destination: url)
                                .font(.footnote)
                        } else {
                            Text("\(doc.source.rawValue): \(doc.topic)")
                                .font(.footnote)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Call 911

    @ViewBuilder
    private func callEmergencyButton(isSevere: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isSevere {
                Text("This may be a serious emergency.")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
            Button {
                callEmergencyServices()
            } label: {
                Label(EmergencyContact.displayName, systemImage: "phone.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.vertical, 4)
    }

    /// Opens the phone dialer with the emergency number pre-filled. On devices
    /// without a dialer (e.g. simulator, iPad without cellular) this does
    /// nothing.
    private func callEmergencyServices() {
        guard let url = URL(string: "tel://\(EmergencyContact.dialNumber)"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    /// Picks an illustrative SF Symbol for a step based on keywords. Purely
    /// visual — if nothing matches, a neutral checklist icon is used.
    private func stepSymbol(for step: String) -> String {
        let s = step.lowercased()
        if s.contains("call") || s.contains("911") || s.contains("emergency") { return "phone.fill" }
        if s.contains("pressure") || s.contains("press") { return "hand.raised.fill" }
        if s.contains("rinse") || s.contains("water") || s.contains("wash") || s.contains("clean") { return "drop.fill" }
        if s.contains("cool") || s.contains("ice") || s.contains("cold") { return "snowflake" }
        if s.contains("cover") || s.contains("bandage") || s.contains("dress") || s.contains("gauze") { return "bandage.fill" }
        if s.contains("elevate") || s.contains("raise") || s.contains("lift") { return "arrow.up.circle.fill" }
        if s.contains("medic") || s.contains("pill") || s.contains("pain") { return "pills.fill" }
        return "checkmark.circle.fill"
    }
}

/// A single supply row with an expandable "how to use" (text) steps.
private struct SupplyRow: View {
    let supply: Supply
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: supply.symbol)
                    .font(.title3)
                    .foregroundStyle(.red)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(supply.name).fontWeight(.medium)
                    Text(supply.reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Only show the "how to use" toggle when an animation exists.
            if supply.technique != .none {
                Button {
                    withAnimation(.easeInOut) { expanded.toggle() }
                } label: {
                    Label(expanded ? "Hide how to use" : "How to use",
                          systemImage: expanded ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                if expanded {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(supply.technique.steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(i + 1).")
                                    .font(.footnote).fontWeight(.semibold)
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(step.text).font(.footnote)
                                    Text("Source: \(step.source.rawValue)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.leading, 40)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    let state = AppState()
    state.result = GuidanceResult(
        title: "Example: possible minor burn",
        steps: ["Cool the area under running water.", "Cover loosely with a clean cloth."],
        isSevere: true,
        supplies: [
            Supply(name: "Sterile gauze", reason: "Cover the area and absorb drainage.", symbol: "bandage.fill"),
            Supply(name: "Tourniquet", reason: "Last resort for severe limb bleeding.", symbol: "cross.case.fill"),
            Supply(name: "Pain reliever (OTC)", reason: "May ease discomfort; follow the label.", symbol: "pills.fill")
        ],
        longerTermCare: ["Keep the area clean and dry.", "Watch for increasing redness, warmth, or pus."]
    )
    return ResultsView(appState: state)
}
