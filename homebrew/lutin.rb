# typed: strict
# frozen_string_literal: true

# Homebrew formula for the Lutin CLI. Canonical copy lives in the main repo
# at homebrew/lutin.rb; it is mirrored to github.com/Halloweedev/homebrew-lutin
# under Formula/lutin.rb so users can `brew install halloweedev/lutin/lutin`.
#
# Ships a prebuilt universal (arm64 + x86_64) binary attached to the GitHub
# Release by .github/workflows/release-cli.yml — no source build or Xcode
# needed by users. To build from source instead: clone the repo and run
# `swift build -c release --product lutin`.
class Lutin < Formula
  desc "Design, build, sign, and notarize macOS DMGs"
  homepage "https://github.com/Halloweedev/lutin"
  url "https://github.com/Halloweedev/lutin/releases/download/v0.3.1/lutin-0.3.1-macos-universal.tar.gz"
  version "0.3.1"
  sha256 "e92b17f89322f66fb5306b435ad4b00cff3ab774367fc10eeab34dcb3cca4f38"
  license "GPL-3.0-only"

  depends_on macos: :sequoia

  def install
    bin.install "lutin"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lutin --version")
    assert_match "USAGE: lutin <subcommand>", shell_output("#{bin}/lutin --help")
  end
end
