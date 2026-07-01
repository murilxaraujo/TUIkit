import Foundation
import PackagePlugin

@main
struct TUIkitPreviewPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "tuikit-preview")
        var runnerArguments = arguments
        if !containsPackagePath(arguments) {
            runnerArguments = ["--package-path", FileManager.default.currentDirectoryPath] + runnerArguments
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.path.string)
        process.arguments = runnerArguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            Diagnostics.error("tuikit-preview exited with status \(process.terminationStatus)")
        }
    }

    private func containsPackagePath(_ arguments: [String]) -> Bool {
        arguments.contains("--package-path")
    }
}
