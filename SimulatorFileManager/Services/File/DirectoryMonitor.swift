//
//  DirectoryMonitor.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation
import Synchronization

public protocol DirectoryMonitorProtocol: AnyObject, Sendable {
    nonisolated var onDirectoryChanged: (@Sendable () -> Void)? { get set }
    nonisolated func startMonitoring(url: URL)
    nonisolated func stopMonitoring()
}

nonisolated public final class DirectoryMonitor: DirectoryMonitorProtocol, Sendable {
    private struct State {
        var fileDescriptor: CInt = -1
        var source: DispatchSourceFileSystemObject?
        var debounceGeneration: UInt64 = 0
        var onDirectoryChanged: (@Sendable () -> Void)?
    }

    private let state: Mutex<State>
    private let monitorQueue = DispatchQueue(label: "com.simulatorfilemanager.directorymonitor")
    private let debounceInterval: TimeInterval

    public var onDirectoryChanged: (@Sendable () -> Void)? {
        get {
            state.withLock { $0.onDirectoryChanged }
        }
        set {
            state.withLock { $0.onDirectoryChanged = newValue }
        }
    }

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
