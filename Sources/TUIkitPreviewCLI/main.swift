//  🖥️ TUIKit — Terminal UI Kit for Swift
//  tuikit-preview
//
//  Created by LAYERED.work
//  License: MIT

import Foundation

@main
struct TUIkitPreviewCLI {
    static func main() throws {
        var args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty || args.contains("--help") || args.contains("-h") {
            print(help)
            return
        }

        let watch = args.removeAllOccurrences(of: "--watch")
        if args.first == "--" {
            args.removeFirst()
        }

        if watch {
            guard !args.isEmpty else {
                print("tuikit-preview --watch requires a command, e.g. tuikit-preview --watch swift run MyPreviews")
                return
            }
            try PreviewWatcher(command: args).run()
        } else {
            try run(args)
        }
    }

    private static func run(_ command: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        try process.run()
        process.waitUntilExit()
    }

    private static let help = """
    Usage:
      tuikit-preview --watch swift run MyPreviews -- --preview dashboard
      tuikit-preview swift run MyPreviews -- --list

    Description:
      Runs a TUIkit preview executable and, with --watch, reruns it whenever Swift
      source files in the current package change. Preview declarations live in
      your own executable via TUIkitPreviewApp so previews compile with your app.

    Options:
      --watch     Re-run the command when Package.swift or .swift files change.
      --help      Show this help.
    """
}

private struct PreviewWatcher {
    let command: [String]
    let root: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    func run() throws {
        var lastSignature = signature()
        try render()

        while true {
            Thread.sleep(forTimeInterval: 0.8)
            let nextSignature = signature()
            if nextSignature != lastSignature {
                lastSignature = nextSignature
                try render()
            }
        }
    }

    private func render() throws {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        print("TUIkit Preview • \(command.joined(separator: " "))")
        print("Watching \(root.path) — press Ctrl-C to stop\n")
        try TUIkitPreviewCLI.mainRun(command)
    }

    private func signature() -> String {
        watchedFiles()
            .compactMap { url -> String? in
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let modified = attrs[.modificationDate] as? Date,
                      let size = attrs[.size] as? NSNumber else { return nil }
                return "\(url.path):\(modified.timeIntervalSince1970):\(size.intValue)"
            }
            .joined(separator: "|")
    }

    private func watchedFiles() -> [URL] {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var urls: [URL] = [root.appendingPathComponent("Package.swift")].filter { manager.fileExists(atPath: $0.path) }
        for case let url as URL in enumerator {
            let path = url.path
            if path.contains("/.build/") || path.contains("/.swiftpm/") { continue }
            guard url.pathExtension == "swift" else { continue }
            urls.append(url)
        }
        return urls.sorted { $0.path < $1.path }
    }
}

private extension TUIkitPreviewCLI {
    static func mainRun(_ command: [String]) throws {
        try run(command)
    }
}

private extension Array where Element == String {
    mutating func removeAllOccurrences(of value: String) -> Bool {
        let oldCount = count
        removeAll { $0 == value }
        return count != oldCount
    }
}
