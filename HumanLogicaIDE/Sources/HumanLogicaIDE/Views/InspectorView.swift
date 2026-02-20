// InspectorView.swift — Right Inspector Panel
// Token display, ledger viewer, axiom reference.

import SwiftUI
import HumanLogicaCore

struct InspectorView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Panel selector
            Picker("", selection: $viewModel.selectedInspectorPanel) {
                ForEach(InspectorPanel.allCases, id: \.self) { panel in
                    Text(panel.rawValue).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            switch viewModel.selectedInspectorPanel {
            case .tokens:
                TokenListView()
            case .ledger:
                LedgerView()
            case .axioms:
                AxiomReferenceView()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
}

// MARK: - Token List

struct TokenListView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Token action
            HStack {
                Button("Refresh Tokens") {
                    viewModel.showTokens()
                }
                .font(.system(size: 11))
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text("\(viewModel.displayTokens.count) tokens")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(8)

            Divider()

            if viewModel.displayTokens.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Click 'Refresh Tokens' to tokenize")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.displayTokens) { token in
                            TokenRow(token: token)
                        }
                    }
                    .padding(6)
                }
            }
        }
    }
}

struct TokenRow: View {
    let token: DisplayToken

    var body: some View {
        HStack(spacing: 6) {
            // Line:col
            Text("L\(token.line):\(token.col)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 42, alignment: .leading)

            // Token type badge
            Text(token.type)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(colorForTokenType(token.type))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForTokenType(token.type).opacity(0.12))
                )
                .frame(width: 80, alignment: .leading)

            // Value
            Text(displayValue(token))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.vertical, 1)
    }

    private func displayValue(_ token: DisplayToken) -> String {
        if token.type == "NEWLINE" { return "\\n" }
        if token.type == "EOF" { return "<eof>" }
        if token.type == "STRING" { return "\"\(token.value)\"" }
        return token.value
    }

    private func colorForTokenType(_ type: String) -> Color {
        switch type {
        case "SPEAKER", "AS", "LET", "SPEAK", "WHEN", "OTHERWISE", "BROKEN",
             "FN", "RETURN", "WHILE", "MAX", "REQUEST", "RESPOND", "ACCEPT",
             "REFUSE", "INSPECT", "HISTORY", "LEDGER", "VERIFY", "WORLD", "SEAL",
             "IF", "ELIF", "ELSE", "PASS", "FAIL", "AND", "OR", "NOT", "READ":
            return .purple
        case "ACTIVE", "INACTIVE", "TRUE", "FALSE", "NONE":
            return .orange
        case "STRING":
            return .green
        case "INTEGER", "FLOAT":
            return .cyan
        case "IDENTIFIER":
            return .blue
        default:
            return .secondary
        }
    }
}

// MARK: - Ledger View

struct LedgerView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Run a program to see the ledger.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(8)

            Divider()

            if viewModel.ledgerEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No ledger entries yet")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Run a program to populate the ledger")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.ledgerEntries) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("#\(entry.id)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text(entry.status)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(statusColor(entry.status))
                                Spacer()
                            }
                            Text("\(entry.speakerName): \(entry.action)")
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "active": return .green
        case "inactive": return .gray
        case "broken": return .red
        default: return .secondary
        }
    }
}

// MARK: - Axiom Reference

struct AxiomReferenceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("The 10 Axioms of Human Logic")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.bottom, 4)

                ForEach(axioms, id: \.number) { axiom in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("A\(axiom.number)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .frame(width: 28, alignment: .leading)

                            Text(axiom.name)
                                .font(.system(size: 12, weight: .semibold))
                        }

                        Text(axiom.description)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.leading, 34)

                        if axiom.enforcement != "" {
                            HStack(spacing: 4) {
                                Image(systemName: axiom.enforcement == "compile" ? "hammer" : "cpu")
                                    .font(.system(size: 9))
                                Text(axiom.enforcement == "compile" ? "Compile-time" : "Runtime")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(axiom.enforcement == "compile" ? .purple : .orange)
                            .padding(.leading, 34)
                        }
                    }
                    .padding(.vertical, 4)

                    if axiom.number < 10 {
                        Divider()
                    }
                }

                Spacer()
            }
            .padding(12)
        }
    }

    private var axioms: [(number: Int, name: String, description: String, enforcement: String)] {
        [
            (1, "Speaker Requirement",
             "Every operation has a speaker. No anonymous operations.",
             "compile"),
            (2, "Condition as Flag",
             "Conditions are scoped markers, not values themselves.",
             "compile"),
            (3, "Three-Valued Evaluation",
             "Every expression is active, inactive, or broken. No other states.",
             "runtime"),
            (4, "Silence Is Distinct",
             "Not speaking is different from speaking nothing.",
             "compile"),
            (5, "Ledger Integrity",
             "The ledger is append-only. No modification. No deletion. Ever.",
             "runtime"),
            (6, "Deterministic Evaluation",
             "Same state in, same result out. Always.",
             "runtime"),
            (7, "No Forced Speech",
             "Only speaker s can author expressions for s.",
             "compile"),
            (8, "Write Ownership",
             "Only speaker s can write to s's variables. This is math, not permission.",
             "compile"),
            (9, "No Infinite Loops",
             "Every loop must have a termination path or explicit bound.",
             "compile"),
            (10, "No Orphan State",
             "Every state change is traced to a ledger entry.",
             "runtime"),
        ]
    }
}
