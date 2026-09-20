# AGENTS.md

## Dev environment tips
- **Platform & Target**: macOS app built with SwiftUI and AppKit, targeting macOS 15.0+ (Sequoia).
- **Concurrency & Architecture**: Swift 6 language mode with default `@MainActor` isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). ViewModels use the modern `@Observable` macro from the Observation framework.
- **Formatting & Linting**:
  - Format a file in-place: `swift format format -i <file.swift>`
  - Format the entire project: `swift format format -i -r Simfiles`
  - Check lint issues: `swift format lint <file.swift>` or `swift format lint -r Simfiles`
  - Strict linting (warnings as errors): `swift format lint -s -r Simfiles`
- **App Sandbox**: App Sandbox is intentionally disabled (`ENABLE_APP_SANDBOX = NO`) because the app requires direct access to CoreSimulator sandboxes in `~/Library/Developer/CoreSimulator/Devices/`.
- **Project Structure**:
  - `Simfiles/App`: Application entry point (`SimfilesApp.swift`, `AppDelegate.swift`).
  - `Simfiles/Models`: Data models (`SimulatorDevice`, `InstalledApp`, `FileItem`, `SandboxDirectory`, `AlertItem`).
  - `Simfiles/ViewModels`: `@Observable @MainActor` state managers (`AppViewModel`, `SidebarViewModel`, `AppListViewModel`, `FileBrowserViewModel`).
  - `Simfiles/Views`: SwiftUI components organized into `Sidebar/`, `AppList/`, and `FileBrowser/`.
  - `Simfiles/Services`: Core business logic decoupled with protocols (`FileManagerService`, `DirectoryMonitor`, `SimctlClient`, `AppScanner`, `SimulatorManager`, `PasteboardService`, `WorkspaceService`).
- **File Management in Xcode**: The project uses Xcode 16's File System Synchronized Groups (`PBXFileSystemSynchronizedRootGroup`). Any Swift files added under the `Simfiles/` directory are automatically tracked and compiled without manually modifying `project.pbxproj`.
- **Simulator CLI**: Use `xcrun simctl list devices` to inspect available and booted simulators during development.

## Testing instructions
- **Lint check**: Run `swift format lint -r Simfiles` and ensure all style issues are fixed or auto-formatted via `swift format format -i -r Simfiles`.
- **Build verification**: Run the following command from the project root to check compilation and Swift 6 concurrency errors:
  ```bash
  xcodebuild build -scheme Simfiles -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
  ```
- **Clean build**: If encountering cached build artifacts or stale derived data:
  ```bash
  xcodebuild clean build -scheme Simfiles -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
  ```
- **Unit & UI tests**: When test targets or test plans are added, execute them using:
  ```bash
  xcodebuild test -scheme Simfiles -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
  ```
  To focus on a specific test suite or case, use `-only-testing:<TargetName>/<SuiteName>/<testCase>`.
- **Concurrency checks**: Ensure zero Swift 6 warnings and errors (data-race safety, non-Sendable closures, and actor-isolation violations).
- **Fix until green**: Do not commit changes that fail compilation, lint checks, or cause runtime crashes.

## PR instructions
- **Title & Commit format**: Conventional Commits style `<type>(<scope>): <description>` or `<type>: <description>` (e.g., `chore: initial commit`, `feat: add drag-and-drop file import`, `fix: resolve app sandbox path`, `refactor: extract directory monitor`).
  - Types: `feat`, `fix`, `refactor`, `chore`, `style`, `test`, `docs`.
- **Pre-commit checks**:
  1. Run `swift format lint -r Simfiles` (or auto-format with `swift format format -i -r Simfiles`).
  2. Run `xcodebuild build -scheme Simfiles -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` to ensure clean compilation.
  3. Run `git status` to verify no temporary files (e.g., `.DS_Store`, `*.xcuserdata`, or personal build schemes) are tracked.
- **Commit style**: Follow Conventional Commits in lower case, imperative mood.
