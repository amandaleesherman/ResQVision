//
//  QuestionnaireView.swift
//  EmergencyFirst
//
//  Shown ONLY when the vision model is uncertain and returned clarifying
//  questions. The user's answers are fed back into retrieval + synthesis so
//  the guidance is more specific and the generic fallback is less likely.
//
//  Max 3 questions. Each question offers preset options plus a "+" to add a
//  custom answer. Single- or multi-select depending on the question.
//

import SwiftUI

struct QuestionnaireView: View {
    let appState: AppState

    /// Selected answers per question: question text → set of chosen options.
    @State private var selections: [String: Set<String>] = [:]
    /// Custom options the user added per question.
    @State private var customOptions: [String: [String]] = [:]
    /// Which question's "add" field is open, and its text.
    @State private var addingFor: String?
    @State private var addText = ""

    private var questions: [ClarifyingQuestion] {
        Array((appState.pendingAnalysis?.clarifyingQuestions ?? []).prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A few quick questions")
                        .font(.title2).fontWeight(.bold)
                    Text("The photo was a bit unclear. Answering these helps give more specific guidance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(questions) { q in
                    questionBlock(q)
                }

                Button {
                    Task { await appState.finishWithAnswers(collectedAnswers()) }
                } label: {
                    Label("Continue", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Skip") {
                    Task { await appState.finishWithAnswers([:]) }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }

    // MARK: - One question

    @ViewBuilder
    private func questionBlock(_ q: ClarifyingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(q.question)
                .font(.headline)

            let options = q.options + (customOptions[q.question] ?? [])
            FlowChips(
                options: options,
                selected: selections[q.question] ?? [],
                onTap: { option in toggle(option, for: q) }
            )

            // "+" add-custom control.
            if addingFor == q.question {
                HStack {
                    TextField("Add symptom…", text: $addText)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let trimmed = addText.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            customOptions[q.question, default: []].append(trimmed)
                            selections[q.question, default: []].insert(trimmed)
                        }
                        addText = ""
                        addingFor = nil
                    }
                    Button("Cancel") { addText = ""; addingFor = nil }
                }
            } else {
                Button {
                    addingFor = q.question
                } label: {
                    Label("Add symptom", systemImage: "plus.circle")
                        .font(.footnote)
                }
            }
        }
    }

    // MARK: - Selection logic

    private func toggle(_ option: String, for q: ClarifyingQuestion) {
        var set = selections[q.question] ?? []
        if q.allowsMultiple {
            if set.contains(option) { set.remove(option) } else { set.insert(option) }
        } else {
            set = set.contains(option) ? [] : [option]
        }
        selections[q.question] = set
    }

    /// Flattens selections into question → comma-joined answer string.
    private func collectedAnswers() -> [String: String] {
        var out: [String: String] = [:]
        for (question, chosen) in selections where !chosen.isEmpty {
            out[question] = chosen.sorted().joined(separator: ", ")
        }
        return out
    }
}

/// A simple wrapping row of selectable chips.
private struct FlowChips: View {
    let options: [String]
    let selected: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        // A lightweight wrap using a vertical stack of horizontal rows.
        let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isOn = selected.contains(option)
                Button {
                    onTap(option)
                } label: {
                    Text(option)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isOn ? Color.red : Color(.secondarySystemBackground),
                                    in: Capsule())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    let state = AppState()
    state.pendingAnalysis = WoundAnalysis(
        visibleRedness: .mild, apparentWoundType: "unclear",
        bleedingVisibility: .unsure, imageQuality: .fair, uncertainty: 0.6,
        observations: "Unclear.",
        clarifyingQuestions: [
            ClarifyingQuestion(question: "How did you get this?", options: ["falling", "cutting", "hitting a surface"], allowsMultiple: false),
            ClarifyingQuestion(question: "Any of these symptoms?", options: ["bleeding", "itching", "swelling"], allowsMultiple: true)
        ]
    )
    return QuestionnaireView(appState: state)
}
