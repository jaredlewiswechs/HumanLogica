// EditorView.swift — The Code Editor
// Text editor for .logica files with line numbers.

import SwiftUI
import HumanLogicaCore

struct EditorView: View {
    @EnvironmentObject var viewModel: IDEViewModel
    @AppStorage("editorFontSize") private var fontSize: Double = 14
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumbers {
                LineNumberGutter(text: viewModel.sourceCode, fontSize: fontSize)
                    .frame(width: 44)

                Divider()
            }

            TextEditor(text: Binding(
                get: { viewModel.sourceCode },
                set: { viewModel.updateSource($0) }
            ))
            .font(.system(size: fontSize, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.13))
            .foregroundStyle(.white)
        }
        .background(Color(white: 0.13))
    }
}

// MARK: - Line Number Gutter

struct LineNumberGutter: View {
    let text: String
    let fontSize: Double

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...max(1, lineCount), id: \.self) { lineNum in
                    Text("\(lineNum)")
                        .font(.system(size: fontSize - 2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(height: fontSize * 1.45)
                }
            }
            .padding(.top, 7)
            .padding(.horizontal, 6)
        }
        .background(Color(white: 0.16))
    }

    private var lineCount: Int {
        text.components(separatedBy: "\n").count
    }
}
