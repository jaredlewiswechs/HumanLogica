// IDEToolbar.swift — The Toolbar
// Run, Check, Tokens, and utility buttons.

import SwiftUI

struct IDEToolbar: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        HStack(spacing: 12) {
            // App title
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16))
                    .foregroundStyle(.tint)
                Text("HumanLogica IDE")
                    .font(.system(size: 13, weight: .semibold))
            }

            Divider()
                .frame(height: 20)

            // Run button
            Button(action: { viewModel.runProgram() }) {
                Label("Run", systemImage: "play.fill")
                    .font(.system(size: 12))
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(viewModel.isRunning)
            .help("Run program (Cmd+R)")

            // Check button
            Button(action: { viewModel.checkAxioms() }) {
                Label("Check", systemImage: "checkmark.shield")
                    .font(.system(size: 12))
            }
            .keyboardShortcut("b", modifiers: .command)
            .help("Check axioms (Cmd+B)")

            // Tokens button
            Button(action: { viewModel.showTokens() }) {
                Label("Tokens", systemImage: "list.bullet.rectangle")
                    .font(.system(size: 12))
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .help("Show tokens (Cmd+Shift+T)")

            Spacer()

            // Running indicator
            if viewModel.isRunning {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }

            // Clear console
            Button(action: { viewModel.clearConsole() }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .help("Clear console")

            // Inspector toggle
            Button(action: { viewModel.showInspector.toggle() }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 12))
                    .foregroundStyle(viewModel.showInspector ? .tint : .secondary)
            }
            .help("Toggle inspector")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
