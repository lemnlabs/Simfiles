# Architecture

This document describes the architectural layers, concurrency model, and dependency injection patterns in Simfiles.

---

## 1. Overview

Simfiles is a native macOS desktop utility built using the **MVVM (Model-View-ViewModel)** architectural pattern. It decouples high-level SwiftUI presentation workflows from low-level POSIX filesystem interactions and `simctl` CLI calls through protocol-based service abstractions.

```text
┌────────────────────────────────────────────────────────┐
│                   Views (SwiftUI)                      │
│     SidebarView  │  AppListView  │ FileBrowserTableView│
└───────────────────────────▲────────────────────────────┘
                            │ Observation (@Observable)
┌───────────────────────────▼────────────────────────────┐
│                      ViewModels                        │
│   SidebarViewModel │ AppListViewModel │ FileBrowser... │
└───────────────────────────▲────────────────────────────┘
                            │ Calls protocols
┌───────────────────────────▼────────────────────────────┐
│                    Service Layer                       │
│  SimctlClientProtocol       FileManagerServiceProtocol │
│  DirectoryMonitorProtocol   WorkspaceServiceProtocol   │
└───────────────────────────▲────────────────────────────┘
                            │ System interop
┌───────────────────────────▼────────────────────────────┐
│           System CLI / POSIX / macOS Subsystem         │
│     xcrun simctl   │   DispatchSource   │  NSWorkspace │
└────────────────────────────────────────────────────────┘
```

---

## 2. Architectural Layers

### 1) Presentation Layer (SwiftUI Views)
- Built with modern macOS SwiftUI paradigms (`NavigationSplitView`, `Table`, `Toolbar`, custom drop overlays).
- Views remain declarative and stateless where possible, delegating user intents to view models and binding to reactive state via the `Observation` framework.
- Integrates native desktop interactions including drag-and-drop, context menus, keyboard shortcuts, and Quick Look previews.

### 2) ViewModel Layer (State & Intent)
- All view models (`AppViewModel`, `SidebarViewModel`, `AppListViewModel`, `FileBrowserViewModel`) are isolated to `@MainActor` and annotated with `@Observable`.
- They transform raw domain events into presentation-ready states (e.g., grouped simulators, filtered applications, sorted file rows).
- View models interact with services exclusively through protocols, enabling effortless unit testing and mocking.

### 3) Service Layer (Business Logic & System Interop)
Encapsulates all interactions with external processes and the macOS kernel:
- **Simulator Management (`SimctlClientProtocol`, `SimulatorManager`)**: Executes `xcrun simctl` CLI commands asynchronously and maintains cached device and process state.
- **App Inspection (`AppScanner`)**: Discovers installed apps by inspecting container metadata (`.com.apple.mobile_container_manager.metadata.plist`) and cross-referencing `.app` bundles.
- **File Operations (`FileManagerServiceProtocol`)**: Handles directory listing, conflict-free copying, recursive moves, and safe deletion via macOS Trash.
- **File System Monitoring (`DirectoryMonitorProtocol`)**: Uses low-level file descriptors (`O_EVTONLY`) and `DispatchSourceFileSystemObject` to observe directory modifications in real time.
- **System Integration (`WorkspaceServiceProtocol`, `PasteboardServiceProtocol`)**: Controls Finder reveals, default app launching, and clipboard access.

---

## 3. Concurrency & Isolation Model

Simfiles strictly adheres to the Swift 6 language mode with complete data-race safety:

- **MainActor Isolation**: UI state holders and view models are isolated to `@MainActor` to prevent race conditions during UI updates.
- **Detached Background Execution (`Task.detached`)**: Heavy I/O operations—such as spawning CLI processes with `xcrun simctl` or deep directory scanning—are dispatched via `Task.detached(priority: .userInitiated)` to avoid blocking the main thread.
- **Thread-Safe Synchronization**: Components bridging Grand Central Dispatch (GCD) queues with Swift Concurrency—such as `DirectoryMonitor`—use the Swift 6 `Synchronization.Mutex` primitive to protect internal state across threads without data races.

---

## 4. Dependency Injection

View models declare their dependencies as protocol-typed arguments with production defaults in their initializers:

```swift
init(
    device: SimulatorDevice,
    app: InstalledApp,
    fileService: FileManagerServiceProtocol = FileManagerService(),
    clipboardService: FileClipboardService = FileClipboardService(),
    directoryMonitor: DirectoryMonitorProtocol = DirectoryMonitor(),
    simulatorManager: SimulatorManager? = nil,
    simctlClient: SimctlClientProtocol = SimctlClient(),
    workspaceService: WorkspaceServiceProtocol = WorkspaceService(),
    pasteboardService: PasteboardServiceProtocol = PasteboardService()
)
```

This pattern provides zero-boilerplate instantiation in production while allowing seamless test doubles and mocks during testing.
