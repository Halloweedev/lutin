import LutinCLI

// Rewrite the `lutin <ProjectName> <verb>` form before ArgumentParser sees it.
let rawArgs = Array(CommandLine.arguments.dropFirst())
let processed = ArgumentPreprocessor.rewrite(rawArgs)
Lutin.main(processed)
