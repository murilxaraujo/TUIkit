//  🖥️ TUIKit — Terminal UI Kit for Swift
//  tuikit-preview
//
//  Created by LAYERED.work
//  License: MIT

import Foundation

enum PreviewCLIError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let value): value
        }
    }
}

@main
struct TUIkitPreviewCLI {
    static func main() throws {
        do {
            let options = try PreviewCLIOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            if options.help {
                print(help)
                return
            }
            try PreviewRunner(options: options).run()
        } catch let error as PreviewCLIError {
            FileHandle.standardError.write(Data(("tuikit-preview: \(error.description)\n").utf8))
            Foundation.exit(2)
        }
    }

    private static let help = """
    Usage:
      tuikit-preview [options]
      tuikit-preview list [options]
      tuikit-preview --watch swift run MyPreviews -- --preview dashboard   # compatibility mode

    Options:
      --package-path <path>        Path to Swift package. Defaults to current directory.
      --target <target>            Preview executable product/target to build and run.
      --preview <name-or-id>       Preview to render.
      --size <WxH>                 Fixed terminal size.
      --theme <system|light|dark>  Preview theme metadata.
      --configuration <debug|release>
      --no-watch                   Build once and run once.
      --verbose                    Show build commands and diagnostics.
      --help                       Show this help.

    The target should be an executable that conforms to TUIkitPreviewApp. The
    executable receives --list, --preview, --size, and --theme flags.
    """
}

struct PreviewCLIOptions: Equatable {
    enum Mode: Equatable { case run, list, compatibility(command: [String]) }

    var mode: Mode = .run
    var packagePath = FileManager.default.currentDirectoryPath
    var target: String?
    var preview: String?
    var size: String?
    var theme: String?
    var configuration = "debug"
    var watch = true
    var verbose = false
    var help = false

    init(arguments: [String]) throws {
        var args = arguments
        if args.isEmpty {
            // Default run mode; config may supply target/defaultPreview.
        }
        if args.contains("--help") || args.contains("-h") {
            help = true
            return
        }

        if args.removeAllOccurrences(of: "--watch") {
            guard !args.isEmpty else { throw PreviewCLIError.message("--watch requires a command") }
            mode = .compatibility(command: args)
            watch = true
            return
        }

        if args.first == "list" {
            mode = .list
            args.removeFirst()
        }

        var iterator = args.makeIterator()
        while let arg = iterator.next() {
            switch arg {
            case "--":
                continue
            case "list":
                mode = .list
                watch = false
            case "--package-path":
                packagePath = try iterator.requiredValue(after: arg)
            case "--target":
                target = try iterator.requiredValue(after: arg)
            case "--preview", "-p":
                preview = try iterator.requiredValue(after: arg)
            case "--size":
                size = try iterator.requiredValue(after: arg)
            case "--theme":
                theme = try iterator.requiredValue(after: arg)
            case "--configuration", "-c":
                configuration = try iterator.requiredValue(after: arg)
            case "--no-watch":
                watch = false
            case "--verbose":
                verbose = true
            default:
                if target == nil {
                    target = arg
                } else if preview == nil {
                    preview = arg
                } else {
                    throw PreviewCLIError.message("unexpected argument '\(arg)'")
                }
            }
        }

        let config = PreviewConfig.load(packagePath: packagePath)
        target = target ?? config.target
        preview = preview ?? config.defaultPreview
        size = size ?? config.size
        theme = theme ?? config.theme
    }
}

struct PreviewConfig: Equatable {
    var target: String?
    var defaultPreview: String?
    var theme: String?
    var size: String?

    static func load(packagePath: String) -> Self {
        let url = URL(fileURLWithPath: packagePath).appendingPathComponent(".tuikit-preview.yml")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return Self() }
        var config = Self()
        var inSize = false
        var sizeWidth: String?
        var sizeHeight: String?

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let withoutComment = rawLine.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
            let line = withoutComment.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line == "size:" {
                inSize = true
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            switch (inSize, key) {
            case (_, "target"):
                config.target = value
                inSize = false
            case (_, "defaultPreview"):
                config.defaultPreview = value
                inSize = false
            case (_, "theme"):
                config.theme = value
                inSize = false
            case (true, "width"):
                sizeWidth = value
            case (true, "height"):
                sizeHeight = value
            default:
                inSize = false
            }
        }

        if let sizeWidth, let sizeHeight {
            config.size = "\(sizeWidth)x\(sizeHeight)"
        }
        return config
    }
}

struct PreviewRunner {
    var options: PreviewCLIOptions

    func run() throws {
        switch options.mode {
        case .compatibility(let command):
            try CompatibilityWatcher(command: command, watch: options.watch).run()
        case .list:
            try build()
            try runPreview(list: true)
        case .run:
            guard options.target != nil else {
                throw PreviewCLIError.message("missing --target. Set target in .tuikit-preview.yml or pass --target <preview executable>.")
            }
            if options.watch {
                try watchLoop()
            } else {
                try build()
                try runPreview(list: false)
            }
        }
    }

    private func watchLoop() throws {
        var lastSignature = signature()
        try rebuildAndRun()
        while true {
            Thread.sleep(forTimeInterval: 0.25)
            let nextSignature = signature()
            if nextSignature != lastSignature {
                lastSignature = nextSignature
                try rebuildAndRun()
            }
        }
    }

    private func rebuildAndRun() throws {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        do {
            let start = Date()
            try build()
            let elapsed = String(format: "%.2fs", Date().timeIntervalSince(start))
            print("Build: ✅ \(elapsed)\n")
            try runPreview(list: false)
        } catch {
            print("Build failed\n")
            print(error)
            print("\nPress Ctrl-C to quit; save a file to retry.")
        }
    }

    private func build() throws {
        var command = ["swift", "build", "--package-path", options.packagePath]
        if options.configuration == "release" {
            command += ["-c", "release"]
        }
        if let target = options.target {
            command += ["--product", target]
        }
        try runProcess(command, verbose: options.verbose)
    }

    private func runPreview(list: Bool) throws {
        guard let target = options.target else { throw PreviewCLIError.message("missing --target") }
        var command = ["swift", "run", "--package-path", options.packagePath]
        if options.configuration == "release" {
            command += ["-c", "release"]
        }
        command += [target, "--"]
        if !list { command.append("--tuikit-preview") }
        if list { command.append("--list") }
        if let preview = options.preview { command += ["--preview", preview] }
        if let size = options.size { command += ["--size", size] }
        if let theme = options.theme { command += ["--theme", theme] }
        try runProcess(command, verbose: options.verbose)
    }

    private func runProcess(_ command: [String], verbose: Bool) throws {
        if verbose { print("$ \(command.joined(separator: " "))") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PreviewCLIError.message("command failed with exit code \(process.terminationStatus): \(command.joined(separator: " "))")
        }
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
        let root = URL(fileURLWithPath: options.packagePath)
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else { return [] }

        var urls: [URL] = [root.appendingPathComponent("Package.swift")].filter { manager.fileExists(atPath: $0.path) }
        for case let url as URL in enumerator {
            let parts = Set(url.pathComponents)
            if !parts.isDisjoint(with: [".build", ".git", "DerivedData", ".swiftpm"]) { continue }
            guard url.pathExtension == "swift" || url.lastPathComponent == "Package.resolved" else { continue }
            urls.append(url)
        }
        return urls.sorted { $0.path < $1.path }
    }
}

private struct CompatibilityWatcher {
    let command: [String]
    let watch: Bool
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    func run() throws {
        if !watch {
            try runProcess(command)
            return
        }
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
        try runProcess(command)
    }

    private func runProcess(_ command: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        try process.run()
        process.waitUntilExit()
    }

    private func signature() -> String {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: nil) else { return "" }
        return enumerator.compactMap { item -> String? in
            guard let url = item as? URL, url.pathExtension == "swift" || url.lastPathComponent == "Package.swift" else { return nil }
            guard let attrs = try? manager.attributesOfItem(atPath: url.path), let date = attrs[.modificationDate] as? Date else { return nil }
            return "\(url.path):\(date.timeIntervalSince1970)"
        }.joined(separator: "|")
    }
}

private extension IndexingIterator where Elements == [String] {
    mutating func requiredValue(after option: String) throws -> String {
        guard let value = next(), !value.hasPrefix("--") else {
            throw PreviewCLIError.message("\(option) requires a value")
        }
        return value
    }
}

private extension Array where Element == String {
    mutating func removeAllOccurrences(of value: String) -> Bool {
        let oldCount = count
        removeAll { $0 == value }
        return count != oldCount
    }
}
