//  🖥️ TUIKit — Terminal UI Kit for Swift
//  CursorTimerTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

@MainActor
@Suite("CursorTimer Tests")
struct CursorTimerTests {

    @Test("Initial blink state is visible")
    func initialBlinkStateVisible() {
        let appState = AppState()
        let timer = CursorTimer(renderNotifier: appState)

        #expect(timer.blinkVisible(for: .regular) == true)
    }

    @Test("Pulse phase stays within 0-1 range")
    func pulsePhaseRange() {
        let appState = AppState()
        let timer = CursorTimer(renderNotifier: appState)

        let phase = timer.pulsePhase(for: .regular)
        #expect(phase >= 0 && phase <= 1)
    }

    @Test("Timer ticks request render from background task")
    func timerTicksRequestRender() async throws {
        let appState = AppState()
        let timer = CursorTimer(renderNotifier: appState)

        timer.start()
        try await Task.sleep(for: .milliseconds(80))
        timer.stop()

        #expect(appState.needsRender == true)
    }

    @Test("Stop cancels structured timer task")
    func stopCancelsStructuredTimerTask() async throws {
        let appState = AppState()
        let timer = CursorTimer(renderNotifier: appState)

        timer.start()
        timer.stop()
        appState.didRender()

        try await Task.sleep(for: .milliseconds(80))

        #expect(appState.needsRender == false)
        #expect(timer.blinkVisible(for: .regular) == true)
    }
}
