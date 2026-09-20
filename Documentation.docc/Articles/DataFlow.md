# Data Flow & Execution Lifecycles

Explore the primary execution lifecycles, background pipelines, and real-time synchronization flows in Simfiles.

## Overview

Data in Simfiles flows through three primary pipelines:
1. **Simulator Discovery**: Querying available devices and monitoring boot states.
2. **App & Container Scanning**: Correlating app bundles with sandbox data containers.
3. **Real-time File Browsing**: Navigating sandbox directories with live change monitoring and clipboard management.

---

## 1. Simulator Discovery Pipeline

Simulator devices are retrieved by querying Xcode's `simctl` command-line utility in a detached background task.

```
xcrun simctl list devices available -j
          │
          ▼ (JSON Parsing & Filtering)
  Device Records [Dictionary]
          │
          ▼ (Runtime formatting & Sorting)
 [SimulatorDevice] (Booted first, then Runtime, then Name)
          │
          ▼
   SimulatorManager.devices
          │
          ▼
   SidebarViewModel.groupedDevices (Grouped by Runtime)
```

1. ``SimctlClient/listDevices()`` executes `/usr/bin/xcrun simctl list devices available -j` inside `Task.detached`.
2. The output JSON is parsed into raw dictionaries, extracting UDID, name, state (Booted/Shutdown), `dataPath`, and last used timestamps.
3. Raw runtime identifiers (e.g. `com.apple.CoreSimulator.SimRuntime.iOS-18-2`) are formatted into user-friendly names (e.g. `iOS 18.2`).
4. Devices are sorted (booted devices first, then runtime descending, then alphabetically by name) and wrapped into ``SimulatorDevice`` instances.
5. ``SimulatorManager`` publishes the updated list, and ``SidebarViewModel`` groups devices by runtime for hierarchical presentation.

---

## 2. App & Sandbox Discovery Pipeline

Installed applications are discovered by inspecting simulator container directories on disk rather than relying on private APIs.

```
Device.dataContainersURL (Data/Application)
  │
  ├─► Scan folder entries
  ├─► Read .com.apple.mobile_container_manager.metadata.plist
  │     └─► Extract MCMMetadataIdentifier (Bundle ID)
  │
  ▼ Match with
Device.bundleContainersURL (Bundle/Application)
  │
  ├─► Scan .app bundles & Info.plist
  ├─► Extract CFBundleDisplayName, CFBundleShortVersionString
  └─► Extract AppIcon PNG data
          │
          ▼
     [InstalledApp]
```

1. ``AppScanner/scanInstalledApps(for:)`` scans the device's `Containers/Bundle/Application` directory to inspect `.app` bundles, reading `Info.plist` to obtain bundle IDs, display names, version strings, and icon assets.
2. It scans `Containers/Data/Application` folders, reading `.com.apple.mobile_container_manager.metadata.plist` to obtain the sandbox container's bundle identifier (`MCMMetadataIdentifier`).
3. Bundle metadata is merged with data container paths to construct ``InstalledApp`` models.
4. User-installed applications are prioritized over built-in Apple system apps (`com.apple.*`).

---

## 3. Real-time File Browsing Pipeline

When an application's sandbox is viewed, the directory contents are listed and monitored for live changes.

```
User Navigates / Folder Opens
          │
          ▼
 FileBrowserViewModel.navigateToURL(url)
   ├─► FileManagerService.listFiles(at:) ──► [FileItem] ──► UI Update
   └─► DirectoryMonitor.startMonitoring(url:)
              │
              ▼ (POSIX open O_EVTONLY)
       DispatchSourceFileSystemObject
              │
              ▼ (File event: write / delete / rename)
     notifyChangeWithDebounce() (300ms)
              │
              ▼
   onDirectoryChanged Handler
              │
              ▼ (@MainActor)
 FileBrowserViewModel.reloadFiles() ──► UI Update
```

* **Live Monitoring**: ``DirectoryMonitor/startMonitoring(url:)`` opens a POSIX file descriptor with `O_EVTONLY` and attaches a `DispatchSourceFileSystemObject` to observe write, delete, rename, and attribute events.
* **Debouncing**: Rapid successive file writes are coalesced using a 300ms debounce timer to prevent excessive re-renders.
* **MainActor Dispatch**: Upon debounce expiry, the change notification triggers ``FileBrowserViewModel/reloadFiles()`` on the main actor to refresh the UI table.

---

## 4. File Clipboard & Manipulation Lifecycle

* **Copy / Cut**: ``FileClipboardService`` stores the selected file URLs along with the active ``ClipboardOperation`` (`.copy` or `.cut`).
* **Paste**:
  * In copy mode, ``FileManagerServiceProtocol/copyFiles(from:to:)`` copies the files into the target folder, appending incremental numeric suffixes (e.g. `file 1.txt`) if a naming collision occurs.
  * In cut mode, ``FileManagerServiceProtocol/moveFiles(from:to:)`` relocates the files with cycle prevention (ensuring a parent directory cannot be moved into its own child) and clears the clipboard upon completion.
* **Safe Deletion**: Deletions invoke `FileManager.default.trashItem(at:resultingItemURL:)` to move items to the macOS Trash instead of permanently unlinking them.
