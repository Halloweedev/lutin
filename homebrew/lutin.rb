# typed: strict
# frozen_string_literal: true

# Homebrew formula for the Lutin CLI. Canonical copy lives in the main repo
# at homebrew/lutin.rb; it is mirrored to github.com/Halloweedev/homebrew-lutin
# under Formula/lutin.rb so users can `brew install halloweedev/lutin/lutin`.
#
# Source-build formula (no prebuilt bottle yet): `brew install` runs
# `swift build -c release` against the tagged source tarball, ~30s on first
# install with Xcode 16+ present.
class Lutin < Formula
  desc "Design, build, sign, and notarize macOS DMGs"
  homepage "https://github.com/Halloweedev/lutin"
  url "https://github.com/Halloweedev/lutin/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "20ee13385a9ec49712f7371253f1cc50b50ff7b02a3adaf56cb3e887214ab690"
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
    # Confirm the installed binary reports the version this formula declares.
    assert_match version.to_s, shell_output("#{bin}/lutin --version")
    # And that argument parsing resolves every registered subcommand.
    assert_match "USAGE: lutin <subcommand>", shell_output("#{bin}/lutin --help")
  end
end
