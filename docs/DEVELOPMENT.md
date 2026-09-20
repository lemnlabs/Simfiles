# Development Guide

This guide covers the local development workflow, environment setup, build commands, and testing guidelines for Simfiles.

---

## 1. Environment Requirements

- **Operating System**: macOS 15.0 (Sequoia) or later
- **IDE**: Xcode 16.0 or later
- **Language & Toolchain**: Swift 6.0 (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- **Formatting Tool**: `swift-format`

```bash
# Install swift-format via Homebrew
brew install swift-format
```

---

## 2. Project Structure

```text
Simfiles/
├── App/            # App entry point & delegate (SimfilesApp.swift, AppDelegate.swift)
├── Models/         # Domain models (SimulatorDevice, InstalledApp, FileItem, SandboxDirectory, AlertItem)
├── ViewModels/     # @Observable @MainActor state managers
├── Views/          # SwiftUI presentation components
│   ├── Sidebar/    # Simulator list and device lifecycle controls
│   ├── AppList/    # Installed application listing and filters
│   └── FileBrowser/# Sandbox file table, path bar, and status bar
├── Services/       # Business logic and system interop (protocol-driven)
│   ├── File/       # File manipulation, clipboard, real-time monitoring
│   ├── Simulator/  # simctl CLI, app scanner, simulator manager
│   └── System/     # Finder, Terminal, and pasteboard integration
└── Resources/      # App icons, asset catalogs, Localizable.xcstrings
```

> **Note**: This project utilizes Xcode 16's **File System Synchronized Groups** (`PBXFileSystemSynchronizedRootGroup`). Any Swift files created under `Simfiles/` are automatically tracked and compiled without manual changes to `project.pbxproj`.

---

## 3. App Sandbox Information

Simfiles requires direct access to CoreSimulator sandboxes in `~/Library/Developer/CoreSimulator/Devices/`. Consequently, **App Sandbox is intentionally disabled** (`ENABLE_APP_SANDBOX = NO`).

Enabling the sandbox in project settings will cause permission failures when trying to inspect simulator containers.

---

## 4. Building & Running

### From Xcode
1. Open `Simfiles.xcodeproj` in Xcode.
2. Select the `Simfiles` scheme with destination `My Mac`.
3. Press `Cmd + R` to build and run.

### From Terminal (CLI)
```bash
# Debug build
xcodebuild build -scheme Simfiles -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

# Clean build
xcodebuild clean build -scheme Simfiles -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

# Release build
xcodebuild build -scheme Simfiles -destination 'platform=macOS' -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

---

## 5. Code Style & Linting

Code formatting and style rules are configured in `.swift-format`:

```bash
# Lint entire project
swift format lint -r Simfiles

# Strict linting (warnings treated as errors)
swift format lint -s -r Simfiles

# Format a single file in-place
swift format format -i <file.swift>

# Auto-format entire project
swift format format -i -r Simfiles
```

---

## 6. Simulator CLI Utilities (`simctl`)

Helpful `simctl` commands during local development:

```bash
# List all simulators
xcrun simctl list devices

# List only booted simulators
xcrun simctl list devices booted

# Boot or shutdown a specific simulator
xcrun simctl boot <UDID>
xcrun simctl shutdown <UDID>

# Inject media assets (photos/videos) into a simulator
xcrun simctl addmedia <UDID> <media_path>
```

---

## 7. Release & Homebrew Tap Distribution

When publishing a new release:

1. **Build & Package**: Create a signed/notarized `.dmg` or archive the `.app` bundle into `Simfiles.zip`.
2. **GitHub Release**: Publish the release tag and attach the release assets (`Simfiles.dmg`).
3. **Update Homebrew Tap**: Update the Cask formula in [lemnlabs/homebrew-tap](https://github.com/lemnlabs/homebrew-tap) with the new version and SHA256 checksum:
   ```ruby
   cask "simfiles" do
     version "1.0.0"
     sha256 "<computed_sha256>"

     url "https://github.com/lemnlabs/Simfiles/releases/download/v#{version}/Simfiles.dmg"
     name "Simfiles"
     desc "macOS utility for Apple simulator sandboxes"
     homepage "https://github.com/lemnlabs/Simfiles"

     app "Simfiles.app"
   end
   ```
