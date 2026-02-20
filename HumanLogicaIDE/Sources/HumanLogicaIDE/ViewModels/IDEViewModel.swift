// IDEViewModel.swift — The IDE's Brain
// Manages editor state, program execution, file management, and console output.

import SwiftUI
import HumanLogicaCore

#if canImport(AppKit)
import AppKit
#endif

/// Represents a file open in the editor.
public struct EditorFile: Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var content: String
    public var url: URL?
    public var isModified: Bool = false

    public static func == (lhs: EditorFile, rhs: EditorFile) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A line of console output.
public struct ConsoleLine: Identifiable {
    public let id = UUID()
    public let text: String
    public let type: ConsoleLineType
    public let timestamp: Date = Date()
}

public enum ConsoleLineType {
    case output
    case error
    case system
    case axiomViolation
}

/// Represents a token for display.
public struct DisplayToken: Identifiable {
    public let id = UUID()
    public let type: String
    public let value: String
    public let line: Int
    public let col: Int
}

/// An entry in the ledger display.
public struct LedgerDisplayEntry: Identifiable {
    public let id: Int
    public let speakerName: String
    public let operation: String
    public let action: String
    public let status: String
    public let timestamp: Date
}

/// Sidebar panel selection.
public enum SidebarPanel: String, CaseIterable {
    case files = "Files"
    case examples = "Examples"
    case speakers = "Speakers"
}

/// Inspector panel selection.
public enum InspectorPanel: String, CaseIterable {
    case tokens = "Tokens"
    case ledger = "Ledger"
    case axioms = "Axioms"
}

@MainActor
public class IDEViewModel: ObservableObject {
    // MARK: - Editor State
    @Published public var files: [EditorFile] = []
    @Published public var activeFileId: UUID?
    @Published public var sourceCode: String = ""

    // MARK: - Console
    @Published public var consoleLines: [ConsoleLine] = []

    // MARK: - Inspector
    @Published public var displayTokens: [DisplayToken] = []
    @Published public var ledgerEntries: [LedgerDisplayEntry] = []

    // MARK: - Panels
    @Published public var selectedSidebarPanel: SidebarPanel = .examples
    @Published public var selectedInspectorPanel: InspectorPanel = .tokens
    @Published public var showInspector: Bool = true

    // MARK: - Status
    @Published public var isRunning: Bool = false
    @Published public var statusMessage: String = "Ready"

    // MARK: - Example Programs
    public let examplePrograms: [(name: String, source: String)] = [
        ("Hello World", """
        speaker Jared

        as Jared {
            speak "Hello, World!"
        }
        """),
        ("Write Ownership", """
        speaker Jared
        speaker Maria

        as Jared {
            let assignment = "Build a Calculator"
            let due = "2026-02-24"
            speak "Assignment posted: " + assignment
        }

        as Maria {
            let submission = "def calc(): return 2+2"
            speak "Submitted: " + submission
        }

        # Maria cannot write to Jared's variables (Axiom 8)
        # Uncomment to see the violation:
        # as Maria {
        #     let Jared.assignment = "TAMPERED"
        # }
        """),
        ("Three Values", """
        speaker Teacher

        as Teacher {
            let score = 85

            when score >= 70 {
                speak "Student passed with " + score
            } otherwise {
                speak "Student did not meet the threshold"
            } broken {
                speak "Could not evaluate score"
            }
        }
        """),
        ("Communication", """
        speaker Jared
        speaker Maria

        as Jared {
            speak "Posting assignment..."
            let assignment = "Build a REST API"
        }

        as Maria {
            speak "Requesting review..."
            request Jared "review_submission"
        }

        as Jared {
            respond accept
            speak "Review accepted"
        }
        """),
        ("Loops & Functions", """
        speaker Jared

        as Jared {
            fn fibonacci(n) {
                if n <= 1 {
                    return n
                }
                let a = 0
                let b = 1
                let i = 2
                while i <= n, max 100 {
                    let temp = a + b
                    let a = b
                    let b = temp
                    let i = i + 1
                }
                return b
            }

            let result = fibonacci(10)
            speak "Fibonacci(10) = " + result
        }
        """),
        ("The Full Demo", """
        speaker Jared
        speaker Maria
        speaker Admin

        # Teacher creates assignment
        as Jared {
            let assignment.title = "Build a Calculator"
            let assignment.due = "2026-02-24"
            let assignment.points = 100
            speak "Assignment posted: " + assignment.title
        }

        # Student submits work
        as Maria {
            let submission.content = "def calc(): return 2+2"
            let submission.status = "submitted"
            speak "Work submitted"
        }

        # Teacher grades
        as Jared {
            let grade.Maria.score = 92
            let grade.Maria.feedback = "Strong work. Clean code."
            speak "Grade posted: 92"
        }

        # Student checks grade
        as Maria {
            speak "My score: " + read Jared.grade.Maria.score
            speak "Feedback: " + read Jared.grade.Maria.feedback
        }

        # Student disputes grade
        as Maria {
            request Jared "review_grade"
            speak "Requested grade review"
        }

        # Teacher responds
        as Jared {
            respond refuse
            speak "Review refused: Missing error handling"
        }

        # Admin cannot modify grades (Axiom 8)
        as Admin {
            speak "Admin observing. Cannot modify grades."
            inspect Jared
        }

        # Verify the ledger
        as Jared {
            verify ledger
            ledger last 5
        }
        """),
        ("Inspection", """
        speaker Jared

        as Jared {
            let name = "Jared Lewis"
            let role = "Teacher"
            let school = "Houston ISD"

            inspect Jared
            history Jared.name
            verify ledger
        }
        """),
    ]

    // MARK: - Initialization

    public init() {
        let hello = examplePrograms[0]
        let file = EditorFile(name: hello.name + ".logica", content: hello.source)
        files = [file]
        activeFileId = file.id
        sourceCode = hello.source

        appendSystem("HumanLogica IDE initialized")
        appendSystem("Every operation has a speaker. Every state change has a receipt.")
    }

    // MARK: - File Management

    public func newFile() {
        let file = EditorFile(name: "untitled.logica", content: "speaker MyName\n\nas MyName {\n    speak \"Hello!\"\n}\n")
        files.append(file)
        activeFileId = file.id
        sourceCode = file.content
    }

    public func openExample(_ index: Int) {
        guard index < examplePrograms.count else { return }
        let example = examplePrograms[index]
        let file = EditorFile(name: example.name + ".logica", content: example.source)
        files.append(file)
        activeFileId = file.id
        sourceCode = file.source
    }

    public func selectFile(_ file: EditorFile) {
        if let currentId = activeFileId,
           let idx = files.firstIndex(where: { $0.id == currentId }) {
            files[idx].content = sourceCode
        }
        activeFileId = file.id
        sourceCode = file.content
    }

    public func closeFile(_ file: EditorFile) {
        files.removeAll { $0.id == file.id }
        if activeFileId == file.id {
            activeFileId = files.first?.id
            sourceCode = files.first?.content ?? ""
        }
    }

    public func showOpenPanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Open a .logica file"

        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let file = EditorFile(name: url.lastPathComponent, content: content, url: url)
                files.append(file)
                activeFileId = file.id
                sourceCode = content
                appendSystem("Opened: \(url.lastPathComponent)")
            }
        }
        #endif
    }

    public func saveCurrentFile() {
        guard let currentId = activeFileId,
              let idx = files.firstIndex(where: { $0.id == currentId }) else { return }
        files[idx].content = sourceCode
        files[idx].isModified = false

        if let url = files[idx].url {
            try? sourceCode.write(to: url, atomically: true, encoding: .utf8)
            appendSystem("Saved: \(files[idx].name)")
        } else {
            #if os(macOS)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = files[idx].name

            if panel.runModal() == .OK, let url = panel.url {
                try? sourceCode.write(to: url, atomically: true, encoding: .utf8)
                files[idx].url = url
                files[idx].name = url.lastPathComponent
                appendSystem("Saved: \(url.lastPathComponent)")
            }
            #endif
        }
    }

    // MARK: - Program Execution

    public func runProgram() {
        guard !isRunning else { return }
        isRunning = true
        statusMessage = "Running..."
        clearConsole()
        appendSystem("--- Run: \(activeFileName) ---")

        let source = sourceCode

        Task {
            let result = await Task.detached {
                runLogicaProgram(source: source, quiet: true)
            }.value

            if let error = result.error {
                appendError(error.description)
                statusMessage = "Error"
            } else {
                for line in result.output {
                    appendOutput(line)
                }
                if result.output.isEmpty {
                    appendSystem("Program completed with no output.")
                }
                statusMessage = "Completed"
            }

            isRunning = false
            appendSystem("--- End ---")
        }
    }

    public func checkAxioms() {
        clearConsole()
        appendSystem("--- Axiom Check: \(activeFileName) ---")

        let error = checkLogicaProgram(source: sourceCode)
        if let error = error {
            appendAxiomViolation(error.description)
            statusMessage = "Axiom Violation"
        } else {
            appendSystem("All axioms satisfied. Program is valid.")
            statusMessage = "Valid"
        }
    }

    public func showTokens() {
        let (tokens, error) = tokenizeLogica(source: sourceCode)

        if let error = error {
            appendError(error.description)
            return
        }

        displayTokens = tokens.map {
            DisplayToken(type: $0.type.rawValue, value: $0.value, line: $0.line, col: $0.col)
        }
        selectedInspectorPanel = .tokens
        showInspector = true
        statusMessage = "\(tokens.count) tokens"
    }

    // MARK: - Console Management

    public func clearConsole() {
        consoleLines = []
    }

    private func appendOutput(_ text: String) {
        consoleLines.append(ConsoleLine(text: text, type: .output))
    }

    private func appendError(_ text: String) {
        consoleLines.append(ConsoleLine(text: text, type: .error))
    }

    private func appendSystem(_ text: String) {
        consoleLines.append(ConsoleLine(text: text, type: .system))
    }

    private func appendAxiomViolation(_ text: String) {
        consoleLines.append(ConsoleLine(text: text, type: .axiomViolation))
    }

    // MARK: - Helpers

    private var activeFileName: String {
        if let id = activeFileId, let file = files.first(where: { $0.id == id }) {
            return file.name
        }
        return "untitled.logica"
    }

    public func updateSource(_ newSource: String) {
        sourceCode = newSource
        if let id = activeFileId,
           let idx = files.firstIndex(where: { $0.id == id }) {
            files[idx].isModified = true
        }
    }
}
