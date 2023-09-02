//
//  AppMover.swift
//  AppMover
//
//  Created by Oskar Groth on 2019-12-20.
//  Forked and updated by Rob Mason in 2022.

import AppKit
import os.log

public struct AppMover {
    
    /// Returns whether the current bundle is located inside any Applications folder.
    public static var isInstalled: Bool {
        return isInsideApplicationsFolder(url: Bundle.main.bundleURL)
    }
    
    /// Backwards-compatible non-throwing implementation of `moveApp`.
    public static func moveIfNecessary() {
        do {
            try moveApp(installedName: .current, replaceNewerVersions: false, skipDebugBuilds: true)
        } catch {
            os_log("Moving app: %{public}@", type: .error, String(describing: error))
        }
    }
    
    /// Moves the running app bundle into an appropriate "Applications" Folder if necessary, prompting the user first.
    ///
    /// - Parameters:
    ///    - installedName: Specifies the name the app bundle should take when copied.
    ///    - stringBuilder: Allows for customising of prompt strings, passing in whether admin authentication is needed for the install.
    ///    - replaceNewerVersions: Specifies whether the current app should replace a newer version that's already installed.
    ///      If `false`, this app will be killed and the newer version launched instead. This can be useful to correct accidental launches of
    ///      older versions from the Downloads folder, for example. The `CFBundleVersion` is used for comparison.
    ///    - skipDebugBuilds: If true, moving will be skipped when built in a debug configuration.
    ///
    /// If a move is necessary, this function will block until operations are complete.
    ///
    /// If the move is successful, this process will be killed and the function will therefore never return.
    /// If the move fails, an error of type `AppMoverError` will be thrown.
    public static func moveApp(
        installedName: AppName = .CFBundleName,
        stringBuilder: (_ needsAuth: Bool) -> Strings = Strings.standard,
        replaceNewerVersions: Bool = false,
        skipDebugBuilds: Bool = true
    ) throws {
        #if DEBUG
        if skipDebugBuilds {
            os_log("AppMover: skipping move for debug build", type: .info)
            return
        }
        #endif
        
        guard !isInsideApplicationsFolder(url: Bundle.main.bundleURL) else {
            return
        }
        
        // Activate app -- work-around for focus issues related to "scary file from
        // internet" OS dialog.
        NSApp.activate(ignoringOtherApps: true)
        
        guard let applicationsDirectoryUrl = preferredApplicationsDirectory() else {
            throw AppMoverError(info: "Applications directory could not be located")
        }
        let destinationUrl = applicationsDirectoryUrl.appendingPathComponent(installedName.string + ".app")
        
        // The following two checks are useful when the app has been re-launched from the Downloads folder after
        // previously being installed.
        
        // App at install destination is already running. Switch to that app and terminate this instance.
        // Killing another running process wouldn't be a good idea anyway.
        guard !isApplicationRunning(url: destinationUrl) else {
            os_log("Fatal: App already running at %{public}@. Switching to app then killing this process.",
                   type: .info, String(describing: destinationUrl))
            NSWorkspace.shared.open(destinationUrl)
            exit(0)
        }
        
        // App at install destination is newer than this version
        guard replaceNewerVersions == true || !isNewerApplicationInstalled(url: destinationUrl) else {
            os_log("Fatal: Newer app version installed at %{public}@. Switching to app then killing this process.",
                   type: .info, String(describing: destinationUrl))
            NSWorkspace.shared.open(destinationUrl)
            exit(0)
        }
        
        let needsAuth = needsAuth(toWriteTo: destinationUrl) || needsAuth(toWriteTo: applicationsDirectoryUrl)
        
        let strings = stringBuilder(needsAuth)
        let alert = NSAlert()
        alert.messageText = strings.title
        alert.informativeText = strings.body
        alert.addButton(withTitle: strings.moveButton)
        alert.addButton(withTitle: strings.cancelButton)
        
        // Cancel pressed
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }
        
        if !needsAuth {
            try install(to: destinationUrl)
        } else {
            let result = authenticatedInstall(to: destinationUrl)
            switch result {
            case .error(let number, let message):
                throw AppMoverError(info: "Authenticated install failed: number=\(number), message=\(message)")
            case .cancelled:
                // Catches "cancel" presses on the auth prompt.
                //
                // Instead of cancelling the whole app move, this will have the effect of returning the user
                // back to the first dialog.
                //
                // Useful if the "cancel" was a mis-click.
                try moveApp(
                    installedName: installedName,
                    stringBuilder: stringBuilder,
                    replaceNewerVersions: replaceNewerVersions)
                return
            case .success:
                break
            }
        }
        
        // Catch this one: trashing the current bundle is not strictly necessary
        do {
            try FileManager.default.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)
        } catch {
            os_log("Trashing %{public}@ failed: %{public}@",
                   type: .error, String(describing: destinationUrl), String(describing: error))
        }
        
        // Spawn a separate process to launch the new app once this process has been killed
        try launchAfterKilled(applicationAt: destinationUrl)
        
        // Kill this process.
        exit(0)
    }
    
    // MARK: - Lifecycle
    
    private static func install(to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        try FileManager.default.copyItem(at: Bundle.main.bundleURL, to: url)
        try unquarantine(url: url)
    }
    
    private enum AuthenticatedInstallResult {
        case success
        case error(number: Int16, message: String)
        case cancelled
    }
    
    private static func authenticatedInstall(to url: URL) -> AuthenticatedInstallResult {
        // The following code needs to be treated carefully.
        // It will be run with admin privileges and so malicious intent should be considered.
        let source = Bundle.main.bundleURL.absoluteURL.path
        let dest = url.absoluteURL.path
        
        let deleteCommand = "/bin/rm -rf -- '\(dest)'"
        let copyCommand = "/bin/cp -pR -- '\(source)' '\(dest)'"
        let quarantineCommand = "/usr/bin/xattr -d -r com.apple.quarantine '\(dest)'"
        let script = "do shell script \"\(deleteCommand) && \(copyCommand) && \(quarantineCommand)\" with administrator privileges"
        
        guard let script = NSAppleScript(source: script) else {
            fatalError("Unable to parse AppleScript source: \(script)")
        }
        
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        
        // Success
        guard let error = error else {
            return .success
        }
        
        // Cancel pressed
        if (error[NSAppleScript.errorNumber] as? Int16) == -128 {
            return .cancelled
        }
        
        // Some other error
        return .error(
            number:  error[NSAppleScript.errorNumber] as? Int16 ?? 0,
            message: error[NSAppleScript.errorMessage] as? String ?? ""
        )
    }
    
    private static func unquarantine(url: URL) throws {
        let task = Process()
        task.launchPath = "/usr/bin/xattr"
        task.arguments = ["-d", "-r", "com.apple.quarantine", url.absoluteURL.path]
        try task.run()
        task.waitUntilExit()
    }

    /// Spawns a new process that will launch the app at `url` once `kill -0` reports the current pid is no longer running.
    private static func launchAfterKilled(applicationAt url: URL) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.launchPath = "/bin/sh"
        let script = "(while /bin/kill -0 \(pid) >&/dev/null; do /bin/sleep 0.1; done; /usr/bin/open \"\(url.absoluteURL.path)\") &"
        task.arguments = ["-c", script]
        try task.run()
    }
    
    // MARK: - Helpers
    
    static func needsAuth(toWriteTo url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path) &&
            !FileManager.default.isWritableFile(atPath: url.path)
    }

    static func isApplicationRunning(url: URL) -> Bool {
        return NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleURL?.standardized == url.standardized
        })
    }
    
    static func isNewerApplicationInstalled(url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        
        guard let installedVersion = Bundle(url: url)?.infoDictionary?["CFBundleVersion"] as? String else {
            os_log("Failed to retrieve CFBundleVersion from app at %{public}@", type: .error, String(describing: url))
            return false
        }
        
        guard let thisVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            os_log("Failed to retrieve CFBundleVersion from current app", type: .error)
            return false
        }
                        
        // "The left operand is greater than the right operand."
        // = installedVersion > thisVersion
        return cleanedBundleVersion(installedVersion)
            .compare(cleanedBundleVersion(thisVersion), options: .numeric) == .orderedDescending
    }
    
    // Converts 1.0 -> 1.0.0 etc to workaround issue where `compare(_,options: .numeric)` will report
    // incorrectly that 1.0 > 1.0.0
    static func cleanedBundleVersion(_ version: String) -> String {
        var parts = version.split(separator: ".")
        for _ in parts.count..<3 {
            parts.append("0")
        }
        return parts.joined(separator: ".")
    }

    static func numberOfFilesInDirectory(url: URL) -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: url.path))?.count ?? 0
    }

    static func preferredApplicationsDirectory() -> URL? {
        let candidates = FileManager.default.urls(for: .applicationDirectory, in: .allDomainsMask)
        
        // Find Applications dir with the most apps that isn't system protected
        return candidates
            .map({ $0.resolvingSymlinksInPath() })
            .filter({ url in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                return isDir.boolValue && url.path != "/System/Applications"
            })
            .sorted(by: { lhs, rhs in
                return numberOfFilesInDirectory(url: lhs) < numberOfFilesInDirectory(url: rhs)
            })
            .last
    }

    static func isInsideApplicationsFolder(url: URL) -> Bool {
        let applicationDirs = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .allDomainsMask, true)
        if applicationDirs.contains(where: { url.absoluteURL.path.hasPrefix($0) }) {
            return true
        }
        
        if url.pathComponents.contains("Applications") {
            return true
        }
        
        return false
    }

}

// MARK: - Configuration

public enum AppName {
    /// CFBundleName from Info.plist
    /// This can be useful to prevent propogation of suffixes added by Archive Utility, e.g. "MyApp-1.app"
    case CFBundleName
    /// Name of currently running .app in its current location on disk, e.g. "MyApp.app" or "MyApp-1.app"
    case current
    /// Arbitrary name (excluding ".app" suffix)
    case custom(String)
    
    var string: String {
        switch self {
        case .CFBundleName:
            if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
                return name
            }
            fallthrough
        case .current:
            return (Bundle.main.bundleURL.lastPathComponent as NSString).deletingPathExtension
        case .custom(let name):
            return name
        }
    }
}

public struct Strings {
    let title: String
    let body: String
    let moveButton: String
    let cancelButton: String
    
    public init(title: String, body: String, moveButton: String, cancelButton: String) {
        self.title = title
        self.body = body
        self.moveButton = moveButton
        self.cancelButton = cancelButton
    }
    
    public static func standard(_ needsAuth: Bool) -> Strings {
        var body = "\(NSRunningApplication.current.localizedName ?? "The App") needs to move to your Applications folder in order to work properly."
        if needsAuth {
            body += " You need to authenticate with your administrator password to complete this step."
        }
        return Strings(
            title: "Move to Applications folder",
            body: body,
            moveButton: "Move to Applications Folder",
            cancelButton: "Don't Move"
        )
    }
}


public struct AppMoverError: Error {
    let info: String
}
