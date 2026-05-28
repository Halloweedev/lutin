# typed: strict
# frozen_string_literal: true

# Draft of the Homebrew formula for the Lutin CLI.
#
# This file lives in the main repo while we iterate; the published copy
# belongs in github.com/Halloweedev/homebrew-lutin under `Formula/lutin.rb`
# so users can run `brew install halloweedev/lutin/lutin`.
#
# Build-from-source formula: no prebuilt bottle yet. `brew install` runs
# `swift build -c release` against the tagged source tarball, which takes
# ~30s on first install with Xcode 16+ already present.
class Lutin < Formula
  desc "Design, build, sign, and notarize macOS DMGs"
  homepage "https://github.com/Halloweedev/lutin"
  url "https://github.com/Halloweedev/lutin/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_AFTER_TAGGING"
  license "GPL-3.0-only"
  head "https://github.com/Halloweedev/lutin.git", branch: "main"

  depends_on xcode: ["16.0", :build]
  depends_on macos: :sequoia

  def install
    # SwiftPM's own sandbox conflicts with Homebrew's; --disable-sandbox
    # lets `swift build` resolve and fetch package dependencies.
    system "swift", "build",
           "--disable-sandbox",
           "-c", "release",
           "--product", "lutin"
    bin.install ".build/release/lutin"
  end

  test do
    # --help is the cheapest smoke test that exercises argument parsing
    # and confirms every registered subcommand resolves cleanly.
    assert_match "USAGE: lutin <subcommand>", shell_output("#{bin}/lutin --help")
  end
end
