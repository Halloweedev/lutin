import Foundation
import LutinAppPackagerCore
import LutinCore

@main
enum LutinAppPackagerCLI {
    static func main() {
        let args = CommandLine.arguments
        guard args.count >= 4 else {
            FileHandle.standardError.write(Data("""
            usage: lutin-app-packager <binary> <resources-dir> <output-dir> [--name=Lutin] [--bundle-id=com.lutin.app] [--version=1.0.0] [--build=1]
            """.utf8))
            exit(64)
        }

        let binary = URL(fileURLWithPath: args[1])
        let resources = URL(fileURLWithPath: args[2])
        let output = URL(fileURLWithPath: args[3])
        var name = "Lutin", bundleID = "com.lutin.app", version = "1.0.0", build = "1"
        for arg in args.dropFirst(4) {
            if let v = arg.afterPrefix("--name=") { name = v }
            else if let v = arg.afterPrefix("--bundle-id=") { bundleID = v }
            else if let v = arg.afterPrefix("--version=") { version = v }
            else if let v = arg.afterPrefix("--build=") { build = v }
        }

        do {
            let url = try BundleAssembler.assemble(AppBundleSpec(
                binaryURL: binary, resourcesURL: resources, outputDirectory: output,
                bundleName: name, bundleIdentifier: bundleID,
                shortVersion: version, buildNumber: build, minimumSystemVersion: "15.0"))
            print(url.path)
        } catch let error as LutinError {
            FileHandle.standardError.write(Data("error[\(error.code)]: \(error.message)\n".utf8))
            exit(1)
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}

private extension String {
    func afterPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
