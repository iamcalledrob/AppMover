# AppMover (Fork)
Swift package to moving your application bundle to Applications folder on launch.

![OGSwitch for macOS](screen.png "AppMover")

Requirements
------------
Builds and runs on macOS 10.15 or higher. Does NOT support sandboxed applications.

Requires Swift 5.

## Installation (Swift Package Manager)
```
https://github.com/iamcalledrob/AppMover
```

Usage
-----

Call ```try AppMover.moveApp()``` at the beginning of ```applicationWillFinishLaunching```.

For example:
```swift
do {
    try AppMover.moveApp()
} catch {
    NSLog("Moving app failed: \(error)")
}

// Then, later
if AppMover.isInstalled {
    // Enable update checking or similar.
}
```

Full function signature:
```swift
public static func moveApp(
    installedName: AppName = .CFBundleName,
    stringBuilder: (_ needsAuth: Bool) -> Strings = Strings.standard,
    replaceNewerVersions: Bool = false,
    skipDebugBuilds: Bool = true
)
```

`installedName`: Specify a name if you'd like to guarantee that the app is named a particular way
when copied into the Applications folder.
```swift
public enum AppName {
    /// CFBundleName from Info.plist
    /// This can be useful to prevent propogation of suffixes added by Archive Utility, e.g. "MyApp-1.app"
    case CFBundleName
    /// Name of currently running .app in its current location on disk, e.g. "MyApp.app" or "MyApp-1.app"
    case current
    /// Arbitrary name (excluding ".app" suffix)
    case custom(String)
}
```

`stringBuilder`: User Interface strings can be customised using this parameter, e.g.
```swift
try AppMover.moveApp(stringBuilder: { needsAuth in
    Strings(
        title: "Wanna move the app to Applications?",
        body: "It's a good idea. " + (needsAuth ? "You'll need to auth" : ""),
        moveButton: needsAuth ? "Authenticate and Move" : "Move",
        cancelButton: "Nope"
    )
})
```

`replaceNewerVersions`: Specifies whether the current app should replace a newer version that's
already installed. If `false`, this app will be killed and the newer version launched instead.
This can be useful to correct accidental launches of older versions from the Downloads folder,
for example. The `CFBundleShortVersionString` is used for comparison.

`skipDebugBuilds`: If true, moving will be skipped when built in a debug configuration.

## Credits

Inspired by [LetsMove](https://github.com/potionfactory/LetsMove/).

## License
The MIT License (MIT)

Copyright (c) 2020 Oskar Groth
Forked and updated by Rob Mason in 2022.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
