cask "claude-status" do
  version "1.0.0"
  sha256 "091a726a607e721a7761086d13c6ec208bbc06c62326ae6cd4d259d0f423dd8a"

  url "https://github.com/sklinov/claude-status/releases/download/v#{version}/ClaudeStatus-#{version}.zip"
  name "Claude Status"
  desc "macOS menu bar app that monitors Claude service status"
  homepage "https://github.com/sklinov/claude-status"

  depends_on macos: ">= :monterey"

  app "Claude Status.app"

  zap trash: [
    "~/Library/Preferences/com.sklinov.claude-status.plist",
  ]
end
