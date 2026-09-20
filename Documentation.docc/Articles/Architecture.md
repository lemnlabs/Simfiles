# Architecture

Understand the architectural layers, concurrency model, and dependency injection patterns in Simfiles.

## Overview

Simfiles is built as a native macOS utility following the **MVVM (Model-View-ViewModel)** architectural pattern. It decouples high-level UI workflows from low-level POSIX and CLI system interactions using protocol-based service abstractions.

```
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

## Architectural Layers

### 1. Presentation Layer (SwiftUI Views)
* Implements a responsive desktop interface using modern SwiftUI paradigms (NavigationSplitView, Table, custom overlays).
* Views remain declarative and stateless where possible, delegating user intents to view models and binding to reactive state via the `Observation` framework.
* Incorporates macOS desktop interactions such as drag-and-drop, context menus, keyboard shortcuts, and Quick Look previews.

### 2. ViewModel Layer (State & Intent)
* All view models (``AppViewModel``, ``SidebarViewModel``, ``AppListViewModel``, ``FileBrowserViewModel``) are isolated to `@MainActor` and annotated with `@Observable`.
* They transform raw domain events and user inputs into presentation-ready states (e.g., grouped simulators, filtered applications, sorted file rows).
* View models communicate with services exclusively through protocols, enabling straightforward unit testing with mock implementations.

### 3. Service Layer (Business Logic & System Interop)
Encapsulates all interactions with external processes and the macOS kernel:
* **Simulator Management**: ``SimctlClientProtocol`` executes `xcrun simctl` CLI commands asynchronously. ``SimulatorManager`` coordinates device states and cached process information.
* **App Inspection**: ``AppScanner`` inspects container metadata (`.com.apple.mobile_container_manager.metadata.plist`) and cross-references `.app` bundle packages to discover installed applications.
* **File Operations**: ``FileManagerServiceProtocol`` provides directory listing, conflict-free copying, recursive move validation, and safe deletion via macOS Trash.
* **File System Monitoring**: ``DirectoryMonitorProtocol`` uses low-level file descriptors (`O_EVTONLY`) and `DispatchSourceFileSystemObject` to observe directory modifications in real time.
* **System Integration**: ``WorkspaceServiceProtocol`` controls Finder activations and default app openers, while ``PasteboardServiceProtocol`` handles text clipboard copying.

---

## Concurrency & Isolation Model

Simfiles leverages Swift Concurrency features (async/await, `@MainActor`, `Sendable`, and `Synchronization.Mutex`):

### MainActor Isolation
All UI state holders, including view models and presentation helpers, are isolated to `@MainActor` to prevent race conditions during UI updates.

### Detached Background Execution (`Task.detached`)
Heavy I/O operations—such as spawning CLI processes with `xcrun simctl` or scanning deeply nested directories—are dispatched via `Task.detached(priority: .userInitiated)` to avoid blocking the main thread.

### Thread-Safe Synchronization
Components that bridge Grand Central Dispatch (GCD) queues with Swift Concurrency—such as ``DirectoryMonitor``—use the Swift 6 `Synchronization.Mutex` primitive to protect internal state (file descriptors, dispatch sources, and debounce counters) across threads without data races.

---

## Dependency Injection

View models declare their dependencies as protocol-typed arguments with sensible production defaults in their initializers:

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

This pattern provides zero-boilerplate instantiation in production while allowing seamless test doubles and mocks during unit testing.
