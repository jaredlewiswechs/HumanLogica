// SidebarView.swift — Left Sidebar
// File browser, example programs, and speaker list.

import SwiftUI
import HumanLogicaCore

struct SidebarView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Panel selector
            Picker("", selection: $viewModel.selectedSidebarPanel) {
                ForEach(SidebarPanel.allCases, id: \.self) { panel in
                    Text(panel.rawValue).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            // Panel content
            switch viewModel.selectedSidebarPanel {
            case .files:
                FileListView()
            case .examples:
                ExampleListView()
            case .speakers:
                SpeakerInfoView()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - File List

struct FileListView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        List {
            Section("Open Files") {
                ForEach(viewModel.files) { file in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading) {
                            Text(file.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }

                        Spacer()

                        if file.isModified {
                            Circle()
                                .fill(.orange)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectFile(file)
                    }
                    .listRowBackground(
                        file.id == viewModel.activeFileId
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Example List

struct ExampleListView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        List {
            Section("Example Programs") {
                ForEach(Array(viewModel.examplePrograms.enumerated()), id: \.offset) { index, example in
                    HStack(spacing: 8) {
                        Image(systemName: iconForExample(index))
                            .font(.system(size: 13))
                            .foregroundColor(colorForExample(index))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(example.name)
                                .font(.system(size: 12, weight: .medium))
                            Text(descriptionForExample(index))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.openExample(index)
                    }
                }
            }

            Section("Axioms") {
                ForEach(axioms, id: \.number) { axiom in
                    HStack(spacing: 6) {
                        Text("A\(axiom.number)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .frame(width: 28, alignment: .leading)

                        Text(axiom.name)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func iconForExample(_ index: Int) -> String {
        let icons = ["hand.wave", "lock.shield", "arrow.triangle.branch",
                     "message", "function", "graduationcap", "magnifyingglass"]
        return icons[index % icons.count]
    }

    private func colorForExample(_ index: Int) -> Color {
        let colors: [Color] = [.green, .red, .orange, .blue, .purple, .pink, .cyan]
        return colors[index % colors.count]
    }

    private func descriptionForExample(_ index: Int) -> String {
        let descriptions = [
            "Minimal program",
            "Axiom 8 demo",
            "Three-valued conditional",
            "Request/respond",
            "Fibonacci with loops",
            "Full classroom demo",
            "Inspect and verify",
        ]
        return index < descriptions.count ? descriptions[index] : ""
    }

    private var axioms: [(number: Int, name: String)] {
        [
            (1, "Speaker Requirement"),
            (2, "Condition as Flag"),
            (3, "Three-Valued Evaluation"),
            (4, "Silence Is Distinct"),
            (5, "Ledger Integrity"),
            (6, "Deterministic Evaluation"),
            (7, "No Forced Speech"),
            (8, "Write Ownership"),
            (9, "No Infinite Loops"),
            (10, "No Orphan State"),
        ]
    }
}

// MARK: - Speaker Info

struct SpeakerInfoView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speakers are extracted when you run or check a program.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding()

            // Parse speakers from source
            let speakers = parseSpeakerNames(from: viewModel.sourceCode)

            if !speakers.isEmpty {
                List {
                    Section("Declared Speakers") {
                        ForEach(speakers, id: \.self) { name in
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.accentColor)

                                Text(name)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            Spacer()
        }
    }

    private func parseSpeakerNames(from source: String) -> [String] {
        var names: [String] = []
        let lines = source.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("speaker ") {
                let name = trimmed.dropFirst("speaker ".count).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && !names.contains(name) {
                    names.append(name)
                }
            }
        }
        return names
    }
}
