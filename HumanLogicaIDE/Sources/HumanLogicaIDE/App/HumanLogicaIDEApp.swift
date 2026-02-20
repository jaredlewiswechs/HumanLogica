// HumanLogicaIDEApp.swift — Entry Point
// A SwiftUI IDE for the Logica Programming Language
// Author: Jared Lewis, 2026

import SwiftUI
import HumanLogicaCore

@main
struct HumanLogicaIDEApp: App {
    @StateObject private var viewModel = IDEViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File") {
                    viewModel.newFile()
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Open...") {
                    viewModel.showOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Save") {
                    viewModel.saveCurrentFile()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            CommandMenu("Run") {
                Button("Run Program") {
                    viewModel.runProgram()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Check Axioms") {
                    viewModel.checkAxioms()
                }
                .keyboardShortcut("b", modifiers: .command)

                Divider()

                Button("Show Tokens") {
                    viewModel.showTokens()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Clear Console") {
                    viewModel.clearConsole()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

#if os(macOS)
struct SettingsView: View {
    @AppStorage("editorFontSize") private var fontSize: Double = 14
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = true

    var body: some View {
        Form {
            Section("Editor") {
                Slider(value: $fontSize, in: 10...24, step: 1) {
                    Text("Font Size: \(Int(fontSize))")
                }
                Toggle("Show Line Numbers", isOn: $showLineNumbers)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
