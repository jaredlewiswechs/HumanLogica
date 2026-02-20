// ContentView.swift — Main IDE Layout
// Three-panel layout: Sidebar | Editor+Console | Inspector

import SwiftUI
import HumanLogicaCore

struct ContentView: View {
    @EnvironmentObject var viewModel: IDEViewModel
    @State private var sidebarWidth: CGFloat = 220
    @State private var inspectorWidth: CGFloat = 280
    @State private var consoleHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            IDEToolbar()
                .environmentObject(viewModel)

            Divider()

            // Main content area
            HSplitView {
                // Sidebar
                SidebarView()
                    .environmentObject(viewModel)
                    .frame(minWidth: 180, idealWidth: sidebarWidth, maxWidth: 350)

                // Center: Editor + Console
                VSplitView {
                    // Editor
                    VStack(spacing: 0) {
                        // Tab bar
                        TabBarView()
                            .environmentObject(viewModel)

                        // Editor
                        EditorView()
                            .environmentObject(viewModel)
                    }
                    .frame(minHeight: 200)

                    // Console
                    ConsoleView()
                        .environmentObject(viewModel)
                        .frame(minHeight: 100, idealHeight: consoleHeight)
                }

                // Inspector (optional)
                if viewModel.showInspector {
                    InspectorView()
                        .environmentObject(viewModel)
                        .frame(minWidth: 200, idealWidth: inspectorWidth, maxWidth: 400)
                }
            }

            // Status bar
            StatusBar()
                .environmentObject(viewModel)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
        .background(Color(nsColor: .controlBackgroundColor))
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
                .foregroundColor(.secondary)

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
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color(nsColor: .textBackgroundColor) : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(isActive ? .accentColor : .clear),
            alignment: .bottom
        )
    }
}

// MARK: - Status Bar

struct StatusBar: View {
    @EnvironmentObject var viewModel: IDEViewModel

    var body: some View {
        HStack {
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(viewModel.statusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Line info
            Text("Logica")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 12)

            // Inspector toggle
            Button(action: { viewModel.showInspector.toggle() }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
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

#if os(macOS)
// nsColor bridge for cross-platform
extension Color {
    init(nsColor: NSColor) {
        self.init(nsColor)
    }
}
#endif
