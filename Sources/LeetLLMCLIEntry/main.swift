import Darwin
import Foundation
import LeetLLMRuntime

do {
    let exitCode = try LeetLLMCommand.run(arguments: Array(CommandLine.arguments.dropFirst()))
    exit(exitCode)
} catch {
    print("error: \(error.localizedDescription)")
    exit(2)
}