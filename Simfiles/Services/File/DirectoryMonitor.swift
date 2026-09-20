//
//  DirectoryMonitor.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation
import Synchronization

/// Observes file system modification events within a directory using POSIX kernel events and DispatchSource.
public protocol DirectoryMonitorProtocol: AnyObject, Sendable {
    /// Closure invoked whenever a change is detected in the monitored directory.
    nonisolated var onDirectoryChanged: (@Sendable () -> Void)? { get set }

    /// Starts monitoring changes in the specified directory URL.
    ///
    /// If another directory is currently monitored, the previous monitoring session is stopped first.
    /// - Parameter url: The file system directory URL to monitor.
    nonisolated func startMonitoring(url: URL)

    /// Stops monitoring the current directory and releases file descriptors.
    nonisolated func stopMonitoring()
}

/// Thread-safe directory change monitor leveraging `DispatchSourceFileSystemObject` and `Synchronization.Mutex`.
///
/// Handles high-frequency write/delete/rename events by debouncing notifications over a configurable interval.
nonisolated public final class DirectoryMonitor: DirectoryMonitorProtocol, Sendable {
    private struct State {
        var fileDescriptor: CInt = -1
        var source: DispatchSourceFileSystemObject?
        var debounceGeneration: UInt64 = 0
        var onDirectoryChanged: (@Sendable () -> Void)?
    }

    private let state: Mutex<State>
    private let monitorQueue = DispatchQueue(label: "com.simfiles.directorymonitor")
    private let debounceInterval: TimeInterval

    /// Closure invoked when file system events occur after the debouncing window expires.
    public var onDirectoryChanged: (@Sendable () -> Void)? {
        get {
            state.withLock { $0.onDirectoryChanged }
        }
        set {
            state.withLock { $0.onDirectoryChanged = newValue }
        }
    }

    /// Creates a directory monitor with a custom debounce interval.
    ///
    /// - Parameter debounceInterval: Debounce delay in seconds before triggering notifications. Defaults to 0.3 seconds.
    public init(debounceInterval: TimeInterval = 0.3) {
        self.debounceInterval = debounceInterval
        self.state = Mutex(State())
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring(url: URL) {
        stopMonitoring()

        let path = (url.standardizedFileURL.path as NSString).fileSystemRepresentation
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: monitorQueue
        )

        source.setEventHandler { [weak self] in
            self?.notifyChangeWithDebounce()
        }

        source.setCancelHandler {
            close(descriptor)
        }

        state.withLock {
            $0.fileDescriptor = descriptor
            $0.source = source
        }

        source.resume()
    }

    public func stopMonitoring() {
        let sourceToCancel = state.withLock { state -> DispatchSourceFileSystemObject? in
            let source = state.source
            state.source = nil
            state.fileDescriptor = -1
            state.debounceGeneration &+= 1
            return source
        }

        sourceToCancel?.cancel()
    }

    private func notifyChangeWithDebounce() {
        let (currentGen, handler) = state.withLock { state -> (UInt64, (@Sendable () -> Void)?) in
            state.debounceGeneration &+= 1
            return (state.debounceGeneration, state.onDirectoryChanged)
        }

        monitorQueue.asyncAfter(deadline: .now() + debounceInterval) { [weak self] in
            guard let self else { return }
            let shouldNotify = self.state.withLock { state -> Bool in
                state.debounceGeneration == currentGen && state.source != nil
            }
            if shouldNotify {
                handler?()
            }
        }
    }
}
