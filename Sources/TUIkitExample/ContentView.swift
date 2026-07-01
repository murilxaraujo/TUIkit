//  🖥️ TUIKit — Terminal UI Kit for Swift
//  ContentView.swift
//
//  Created by LAYERED.work
//  License: MIT

import TUIkit

// MARK: - Demo Page Enum

/// The available demo pages in the example app.
enum DemoPage: Int, CaseIterable, Hashable {
    case menu
    case textStyles
    case colors
    case containers
    case overlays
    case layout
    case buttons
    case toggles
    case textFields
    case secureFields
    case radioButtons
    case spinners
    case lists
    case tables
    case sliders
    case steppers
    case splitView
    case dogfoodWorkflow
    case imageFile
    case imageURL
}

// MARK: - Content View

/// The main content view for the example app.
///
/// The example now uses ``NavigationStack`` for page routing. The menu is the
/// non-removable root, and demo pages are pushed as ``DemoPage`` route values.
struct ContentView: View {
    @State private var path: [DemoPage] = []
    @State private var menuSelection: Int = 0

    var body: some View {
        let pathBinding = $path

        NavigationStack(path: pathBinding) {
            MainMenuPage(menuSelection: $menuSelection) { page in
                pathBinding.wrappedValue.append(page)
            }
            .statusBarItems {
                StatusBarItem(shortcut: Shortcut.arrowsUpDown, label: "nav")
                StatusBarItem(shortcut: Shortcut.enter, label: "select", key: .enter)
                StatusBarItem(shortcut: Shortcut.range("1", "9") + ", 0", label: "jump")
            }
            .onKeyPress { event in
                handleMenuShortcut(event.key, path: pathBinding)
            }
            .navigationDestination(for: DemoPage.self) { page in
                pageContent(for: page, path: pathBinding)
            }
        }
    }

    @ViewBuilder
    private func pageContent(for page: DemoPage, path: Binding<[DemoPage]>) -> some View {
        switch page {
        case .menu:
            EmptyView()
        case .textStyles:
            TextStylesPage()
                .statusBarItems(subPageItems())
        case .colors:
            ColorsPage()
                .statusBarItems(subPageItems())
        case .containers:
            ContainersPage()
                .statusBarItems(subPageItems())
        case .overlays:
            OverlaysPage(onBack: { path.wrappedValue.removeAll() })
        case .layout:
            LayoutPage()
                .statusBarItems(subPageItems())
        case .buttons:
            ButtonsPage()
                .statusBarItems(subPageItems())
        case .toggles:
            TogglePage()
                .statusBarItems(subPageItems())
        case .textFields:
            TextFieldPage()
                .statusBarItems(subPageItems())
        case .secureFields:
            SecureFieldPage()
                .statusBarItems(subPageItems())
        case .radioButtons:
            RadioButtonPage()
                .statusBarItems(subPageItems())
        case .spinners:
            SpinnersPage()
                .statusBarItems(subPageItems())
        case .lists:
            ListPage()
                .statusBarItems(subPageItems())
        case .tables:
            TablePage()
                .statusBarItems(subPageItems())
        case .sliders:
            SliderPage()
                .statusBarItems(subPageItems())
        case .steppers:
            StepperPage()
                .statusBarItems(subPageItems())
        case .splitView:
            SplitViewPage()
                .statusBarItems(subPageItems())
        case .dogfoodWorkflow:
            TaskWorkflowPage()
        case .imageFile:
            ImageFilePage()
        case .imageURL:
            ImageURLPage()
        }
    }

    /// Common status bar items for sub-pages.
    private func subPageItems() -> [any StatusBarItemProtocol] {
        [
            StatusBarItem(shortcut: Shortcut.escape, label: "back"),
            StatusBarItem(shortcut: Shortcut.arrowsUpDown, label: "scroll"),
        ]
    }

    /// Handles quick-jump shortcuts from the menu page.
    ///
    /// - Returns: `true` if the key was consumed, `false` otherwise.
    private func handleMenuShortcut(_ key: Key, path: Binding<[DemoPage]>) -> Bool {
        let mapping: [Character: DemoPage] = [
            "1": .textStyles, "2": .colors, "3": .containers,
            "4": .overlays, "5": .layout, "6": .buttons,
            "7": .toggles, "8": .textFields, "\\": .secureFields,
            "9": .radioButtons, "0": .spinners, "-": .lists,
            "=": .tables, "[": .sliders, "]": .steppers,
            ";": .splitView, ".": .dogfoodWorkflow,
            "'": .imageFile, ",": .imageURL,
        ]

        if case .character(let ch) = key, let page = mapping[ch] {
            path.wrappedValue.append(page)
            return true
        }
        return false
    }
}
