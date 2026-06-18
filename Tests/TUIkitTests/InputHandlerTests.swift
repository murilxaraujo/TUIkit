//  🖥️ TUIKit — Terminal UI Kit for Swift
//  InputHandlerTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

@MainActor
@Suite("InputHandler Tests")
struct InputHandlerTests {
    @Test("Ctrl+C requests quit even when q is the configured quit shortcut")
    func ctrlCRequestsQuit() {
        var didQuit = false
        let handler = makeHandler {
            didQuit = true
        }

        handler.handle(KeyEvent(key: .character("c"), ctrl: true))

        #expect(didQuit)
    }

    @Test("Ctrl+C quit has priority over registered key handlers")
    func ctrlCPreemptsRegisteredHandlers() {
        var didQuit = false
        var dispatcherHandled = false
        let dispatcher = KeyEventDispatcher()
        dispatcher.addHandler { event in
            if event == KeyEvent(key: .character("c"), ctrl: true) {
                dispatcherHandled = true
                return true
            }
            return false
        }
        let handler = makeHandler(keyEventDispatcher: dispatcher) {
            didQuit = true
        }

        handler.handle(KeyEvent(key: .character("c"), ctrl: true))

        #expect(didQuit)
        #expect(!dispatcherHandled)
    }

    @Test("Plain c does not request quit")
    func plainCDoesNotRequestQuit() {
        var didQuit = false
        let handler = makeHandler {
            didQuit = true
        }

        handler.handle(KeyEvent(key: .character("c")))

        #expect(!didQuit)
    }

    private func makeHandler(
        keyEventDispatcher: KeyEventDispatcher = KeyEventDispatcher(),
        onQuit: @escaping () -> Void
    ) -> InputHandler {
        InputHandler(
            statusBar: StatusBarState(),
            keyEventDispatcher: keyEventDispatcher,
            focusManager: FocusManager(),
            paletteManager: ThemeManager(items: PaletteRegistry.all),
            appearanceManager: ThemeManager(items: AppearanceRegistry.all),
            onQuit: onQuit
        )
    }
}
