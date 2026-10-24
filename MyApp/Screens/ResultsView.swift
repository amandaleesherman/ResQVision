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
                Label("This looks serious — consider calling emergency services now.",
                      systemImage: "phone.fill.arrow.up.right")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(result.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        Text(step)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let state = AppState()
    state.result = GuidanceResult(
        title: "Example: possible minor burn",
        steps: ["Cool the area under running water.", "Cover loosely with a clean cloth."],
        isSevere: false
    )
    return ResultsView(appState: state)
}
