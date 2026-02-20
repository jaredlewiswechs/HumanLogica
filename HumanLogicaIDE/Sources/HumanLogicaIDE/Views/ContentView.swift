// ContentView.swift — Main IDE Layout
// Three-panel layout: Sidebar | Editor+Console | Inspector

import SwiftUI
import HumanLogicaCore

struct ContentView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            IDEToolbar()
                .environmentObject(viewModel)

            Divider()

            // Main content area — 3 columns
            HStack(spacing: 0) {
                // Left: Sidebar
                SidebarView()
                    .environmentObject(viewModel)
                    .frame(width: 220)

                Divider()

                // Center: Editor + Console
                VStack(spacing: 0) {
                    // Tab bar
                    TabBarView()
                        .environmentObject(viewModel)

                    // Editor
                    EditorView()
                        .environmentObject(viewModel)
                        .frame(minHeight: 200)

                    Divider()

                    // Console
                    ConsoleView()
                        .environmentObject(viewModel)
                        .frame(minHeight: 120, idealHeight: 200)
                }

                // Right: Inspector (optional)
                if viewModel.showInspector {
                    Divider()

                    InspectorView()
                        .environmentObject(viewModel)
                        .frame(width: 280)
                }
            }

            // Status bar
            StatusBar()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Tab Bar

struct TabBarView: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(viewModel.files) { file in
                    TabItemView(file: file, isActive: file.id == viewModel.activeFileId)
                        .onTapGesture {
                            viewModel.selectFile(file)
                        }
                }
                Spacer()
            }
        }
        .frame(height: 30)
        .background(.bar)
    }
}

struct TabItemView: View {
    let file: EditorFile
    let isActive: Bool
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text(file.name)
                .font(.system(size: 11))
                .lineLimit(1)

            if file.isModified {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }

            Button(action: { viewModel.closeFile(file) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(isActive ? Color.accentColor : Color.clear),
            alignment: .bottom
        )
    }
}

// MARK: - Status Bar

struct StatusBar: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(viewModel.statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Logica")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 12)

            Button(action: { viewModel.showInspector.toggle() }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var statusColor: Color {
        switch viewModel.statusMessage {
        case "Error", "Axiom Violation": return .red
        case "Valid", "Completed": return .green
        case "Running...": return .orange
        default: return .gray
        }
    }
}
