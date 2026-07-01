//  🖥️ TUIKit — Terminal UI Kit for Swift
//  AppStorageTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Dispatch
import Foundation
import Testing

@testable import TUIkit

private final class InMemoryStorageBackend: StorageBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func value<T: Codable>(forKey key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = values[key] else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func setValue<T: Codable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }

        lock.lock()
        values[key] = data
        lock.unlock()
    }

    func removeValue(forKey key: String) {
        lock.lock()
        values.removeValue(forKey: key)
        lock.unlock()
    }

    func synchronize() {}
}

private final class ConcurrentIssueRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var issues: [String] = []

    func append(_ issue: String) {
        lock.lock()
        issues.append(issue)
        lock.unlock()
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return issues.isEmpty
    }

    var allIssues: [String] {
        lock.lock()
        defer { lock.unlock() }
        return issues
    }
}

@Suite("AppStorage Tests", .serialized)
struct AppStorageTests {

    @Test("StorageDefaults backend supports concurrent reads and writes")
    func storageDefaultsBackendIsConcurrentSafe() {
        let originalBackend = StorageDefaults.backend
        defer { StorageDefaults.backend = originalBackend }

        let issues = ConcurrentIssueRecorder()

        DispatchQueue.concurrentPerform(iterations: 200) { index in
            let backend = InMemoryStorageBackend()
            backend.setValue(index, forKey: "value")
            StorageDefaults.backend = backend

            let current = StorageDefaults.backend
            current.setValue(index, forKey: "thread-\(index)")
            let stored: Int? = current.value(forKey: "thread-\(index)")
            if stored != index {
                issues.append("Expected \(index), got \(String(describing: stored))")
            }
        }

        #expect(issues.isEmpty, "Concurrent StorageDefaults access had issues: \(issues.allIssues)")
    }

    @Test("AppStorage captures the default backend at initialization")
    func appStorageCapturesDefaultBackendAtInitialization() {
        let originalBackend = StorageDefaults.backend
        defer { StorageDefaults.backend = originalBackend }

        let initialBackend = InMemoryStorageBackend()
        let replacementBackend = InMemoryStorageBackend()
        StorageDefaults.backend = initialBackend

        var storage = AppStorage(wrappedValue: "fallback", "username")
        StorageDefaults.backend = replacementBackend

        storage.wrappedValue = "initial"

        let initialValue: String? = initialBackend.value(forKey: "username")
        let replacementValue: String? = replacementBackend.value(forKey: "username")
        #expect(initialValue == "initial")
        #expect(replacementValue == nil)
        #expect(storage.wrappedValue == "initial")
    }

    @Test("AppStorage reads and writes values through custom backend")
    func appStorageUsesCustomBackend() {
        let backend = InMemoryStorageBackend()
        var storage = AppStorage(wrappedValue: 10, "launchCount", storage: backend)

        #expect(storage.wrappedValue == 10)

        storage.wrappedValue = 42

        let stored: Int? = backend.value(forKey: "launchCount")
        #expect(stored == 42)
        #expect(storage.wrappedValue == 42)
    }
}
