// ConsoleView.swift — Output Console
// Displays program output, errors, and system messages.

import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Console header
            HStack {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Console")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewModel.consoleLines.count) lines")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Button(action: { viewModel.clearConsole() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.bar)

            Divider()

            // Console output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(viewModel.consoleLines) { line in
                            ConsoleLineView(line: line)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .onChange(of: viewModel.consoleLines.count) {
                    if let last = viewModel.consoleLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            .font(.system(size: 12, design: .monospaced))
        }
    }
}

struct ConsoleLineView: View {
    let line: ConsoleLine

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 9))
                .foregroundStyle(lineColor)
                .frame(width: 12)

            Text(line.text)
                .foregroundStyle(lineColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
    }

    private var lineColor: Color {
        switch line.type {
        case .output: return .white
        case .error: return .red
        case .system: return Color(red: 0.5, green: 0.7, blue: 1.0)
        case .axiomViolation: return .orange
        }
    }

    private var iconName: String {
        switch line.type {
        case .output: return "chevron.right"
        case .error: return "xmark.circle.fill"
        case .system: return "info.circle"
        case .axiomViolation: return "exclamationmark.triangle.fill"
        }
    }
}
