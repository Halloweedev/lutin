import ArgumentParser
import Foundation
import LutinCore
import LutinDocument
import LutinConfig
import LutinIntentBridge

struct ApplyIntents: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apply-intents",
        abstract: "Apply a JSON sequence of intents to a lutin.yml. Reads JSON from stdin or --file.")

    @Option(name: .long, help: "Path to the lutin.yml to mutate.")
    var config: String

    @Option(name: .long, help: "Path to a JSON file of intents. If omitted, reads stdin.")
    var file: String?

    @Flag(name: .long, help: "Emit machine-readable JSON output.")
    var json: Bool = false

    func run() throws {
        let renderer = OutputRenderer(json: json, verbose: false)
        let configURL = URL(fileURLWithPath: config)
        let document: LutinProjectDocument
        do {
            document = try LutinProjectDocument(configURL: configURL)
        } catch let error as LutinError {
            renderer.failure(error)
            throw ExitCode(1)
        }
        let data: Data
        if let file {
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: file))
            } catch {
                let lutinError = LutinError(code: "intent_file_unreadable",
                                            message: "Cannot read intents file: \(file)")
                renderer.failure(lutinError)
                throw ExitCode(1)
            }
        } else {
            data = FileHandle.standardInput.readDataToEndOfFile()
        }
        do {
            try IntentBridge.applySequence(jsonData: data, to: document)
            try document.save()
        } catch let error as LutinError {
            renderer.failure(error)
            throw ExitCode(1)
        } catch {
            let lutinError = LutinError(code: "intent_apply_failed",
                                        message: error.localizedDescription)
            renderer.failure(lutinError)
            throw ExitCode(1)
        }
        if json {
            renderer.success(EmptyPayload(), human: "")
        }
    }
}
