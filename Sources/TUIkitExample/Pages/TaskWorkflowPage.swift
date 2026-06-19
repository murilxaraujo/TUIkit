//  TUIKit - Terminal UI Kit for Swift
//  TaskWorkflowPage.swift
//
//  Created by LAYERED.work
//  License: MIT

import TUIkit

private struct ReleaseArtifact: Identifiable, Sendable {
    let id: String
    let status: String

    static let samples = [
        Self(id: "Build", status: "passed"),
        Self(id: "Tests", status: "pending"),
        Self(id: "Docs", status: "updated"),
    ]
}

/// A production-style dogfood flow that combines navigation, forms,
/// persistent local state, empty/loading/error/success copy, focusable actions,
/// and contextual shortcut hints in one realistic screen.
struct TaskWorkflowPage: View {
    @State var selectedTask: Int = 0
    @State var draftTitle: String = "Prepare release candidate"
    @State var includeValidation: Bool = true
    @State var showError: Bool = false
    @State var savedMessage: String = ""
    @State var showChecklist: Bool = false
    @State var progress: Double = 0.65
    @State var artifactSelection: String?
    @AppStorage("tuikit.example.releaseOwner") var releaseOwner: String = "Framework Team"

    private let tasks = [
        "Audit public API notes",
        "Run terminal smoke checks",
        "Update release notes",
        "Publish RC tag",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            DemoSection("Production-style workflow") {
                Text("A compact app flow with list navigation, persistence, editable detail state, validation copy, and status hints.")
                    .foregroundStyle(.palette.foregroundSecondary)
            }

            HStack(alignment: .top, spacing: 3) {
                taskList
                taskDetail
                releaseStatus
            }

            if showError {
                ContentUnavailableView(
                    "⚠ Validation missing",
                    description: "Enable validation before saving release-candidate work."
                )
                .foregroundStyle(.palette.warning)
            } else if !savedMessage.isEmpty {
                Text("✓ \(savedMessage)")
                    .foregroundStyle(.palette.success)
            } else {
                Text("Tip: keep release work validated before publishing tags.")
                    .foregroundStyle(.palette.foregroundSecondary)
            }

            KeyboardHelpSection("Workflow shortcuts", shortcuts: [
                "[Tab] Move through list, form, and actions",
                "[↑] [↓] Navigate task list when focused",
                "[Enter] or [Space] activate focused buttons",
                "[ESC] Return to the main menu",
            ])

            Spacer()
        }
        .padding(.horizontal, 1)
        .modal(isPresented: $showChecklist) {
            Dialog(title: "Release checklist", borderColor: .palette.border, titleColor: .palette.accent) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("✓ Build passes")
                    Text("✓ Tests pass")
                    Text("□ Manual terminal matrix recorded")
                    Text("□ Release notes reviewed")
                    Button("Close", style: .primary) { showChecklist = false }
                }
            }
            .frame(width: 48)
        }
        .notificationHost()
        .statusBarItems {
            StatusBarItem(shortcut: Shortcut.tab, label: "next")
            StatusBarItem(shortcut: Shortcut.enter, label: "activate")
            StatusBarItem(shortcut: Shortcut.escape, label: showChecklist ? "close" : "back")
        }
        .appHeader {
            DemoAppHeader(
                "Dogfood Workflow",
                subtitle: "A realistic release-prep screen exercising core TUIkit systems"
            )
        }
    }

    private var taskList: some View {
        DemoSection("Backlog") {
            Menu(
                title: "Release tasks",
                items: tasks.enumerated().map { index, title in
                    let shortcut = Character(String(index + 1))
                    return MenuItem(label: title, shortcut: shortcut)
                },
                selection: $selectedTask,
                onSelect: { selectedTask = $0 },
                selectedColor: .palette.accent,
                borderColor: .palette.border
            )
        }
    }

    private var releaseStatus: some View {
        DemoSection("Release status") {
            VStack(alignment: .leading, spacing: 1) {
                Text("Owner")
                    .foregroundStyle(.palette.foregroundSecondary)
                Text(releaseOwner).bold()

                ProgressView("RC readiness", value: progress)
                    .trackStyle(.blockFine)

                if progress < 1.0 {
                    HStack(spacing: 1) {
                        Spinner(style: .dots)
                        Text("Waiting on manual terminal validation")
                            .foregroundStyle(.palette.foregroundSecondary)
                    }
                } else {
                    Text("Ready for tag review")
                        .foregroundStyle(.palette.success)
                }

                Table(
                    ReleaseArtifact.samples,
                    selection: $artifactSelection
                ) {
                    TableColumn("Artifact", value: \ReleaseArtifact.id)
                    TableColumn("Status", value: \ReleaseArtifact.status)
                        .width(.fixed(10))
                }

                Button("Mark automated checks", style: .success) {
                    progress = 0.85
                    NotificationService.current.post("Automated checks recorded")
                }
            }
        }
    }

    private var taskDetail: some View {
        DemoSection("Task detail") {
            VStack(alignment: .leading, spacing: 1) {
                Text(tasks[selectedTask])
                    .bold()
                    .foregroundStyle(.palette.accent)

                HStack(spacing: 1) {
                    Text("Title:").foregroundStyle(.palette.foregroundSecondary)
                    TextField("Task title", text: $draftTitle, prompt: Text("Describe the work"))
                }

                HStack(spacing: 1) {
                    Text("Owner:").foregroundStyle(.palette.foregroundSecondary)
                    TextField("Owner", text: $releaseOwner, prompt: Text("Release owner"))
                }

                Toggle("Require validation before save", isOn: $includeValidation)

                ButtonRow(spacing: 2) {
                    Button("Save", style: .primary) {
                        if includeValidation {
                            showError = false
                            savedMessage = "Saved '\(draftTitle)' for \(releaseOwner)."
                            NotificationService.current.post("Release task saved")
                        } else {
                            savedMessage = ""
                            showError = true
                        }
                    }
                    Button("Checklist", style: .plain) {
                        showChecklist = true
                    }
                    Button("Reset", style: .plain) {
                        draftTitle = tasks[selectedTask]
                        includeValidation = true
                        showError = false
                        savedMessage = ""
                        progress = 0.65
                    }
                }
            }
        }
    }
}
