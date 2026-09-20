# ``SimulatorFileManager``

A macOS desktop utility for managing Apple platform simulators and inspecting application sandbox file systems in real time.

## Overview

`SimulatorFileManager` provides an intuitive interface to discover, control, and inspect local iOS, iPadOS, watchOS, and tvOS simulators. It enables developers to explore app sandboxes (`Documents`, `Library`, `Caches`, `tmp`, etc.) with Finder-like navigation, real-time file updates, drag-and-drop support, and photo library media injection.

### Key Abstractions & Entry Points

The project is structured into clear architectural layers separating system interop, business coordination, and reactive SwiftUI presentation:

1. **Simulator Control**: ``SimulatorManager`` provides state coordination and lifecycle management, delegating low-level CLI execution to ``SimctlClientProtocol``.
2. **App Discovery**: ``AppScanner`` discovers installed applications by correlating container metadata with bundle structures.
3. **Sandbox & File Management**: ``FileManagerServiceProtocol`` handles file manipulation and safe deletion, while ``DirectoryMonitorProtocol`` delivers real-time filesystem change notifications.
4. **Application State Coordination**: Top-level selection and navigation are managed by ``AppViewModel`` alongside specialized view models for each feature area.

### Getting Started

To explore the architecture and understand the operational flows, read the following articles:

* <doc:Architecture>: High-level layer separation, concurrency model, and dependency injection patterns.
* <doc:DataFlow>: Detailed execution pipelines from simulator detection to live file monitoring.

---

## Topics

### Concepts & Architecture

- <doc:Architecture>
- <doc:DataFlow>

### Simulator Management

Discover available simulators, manage boot/shutdown lifecycles, monitor active processes, and inject media assets.

- ``SimulatorManager``
- ``SimctlClient``
- ``SimctlClientProtocol``
- ``SimulatorDevice``
- ``DeviceState``

### App Discovery & Inspection

Scan installed applications across user and system domains, correlating bundle definitions with sandbox data containers.

- ``AppScanner``
- ``InstalledApp``

### Sandbox & File Operations

Browse directory contents, perform copy/move/trash actions, create folders, and observe live filesystem events.

- ``FileManagerService``
- ``FileManagerServiceProtocol``
- ``DirectoryMonitor``
- ``DirectoryMonitorProtocol``
- ``FileClipboardService``
- ``ClipboardOperation``
- ``FileItem``
- ``SandboxDirectory``

### System Integration

Integrate with macOS desktop features including Finder selection, default app launching, and system pasteboard access.

- ``WorkspaceService``
- ``WorkspaceServiceProtocol``
- ``PasteboardService``
- ``PasteboardServiceProtocol``

### State & Presentation

Observable view models managing UI state transitions, user interactions, and alert presentations.

- ``AppViewModel``
- ``SidebarViewModel``
- ``AppListViewModel``
- ``FileBrowserViewModel``
- ``AlertItem``
