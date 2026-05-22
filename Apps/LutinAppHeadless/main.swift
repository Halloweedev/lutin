import Foundation
import LutinDocument
import LutinConfig
import LutinIntentBridge

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(Data("usage: lutin-app-headless <config.yml> <intents.json>\n".utf8))
    exit(2)
}
let configURL = URL(fileURLWithPath: args[1])
let intentsURL = URL(fileURLWithPath: args[2])
do {
    let document = try LutinProjectDocument(configURL: configURL)
    let data = try Data(contentsOf: intentsURL)
    try IntentBridge.applySequence(jsonData: data, to: document)
    try document.save()
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
