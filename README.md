# AppMover (Fork)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

Framework for moving your application bundle to Applications folder on launch.

![OGSwitch for macOS](screen.png "AppMover")

Requirements
------------
Builds and runs on macOS 10.15 or higher. Does NOT support sandboxed applications.


## Installation (Carthage)
Configure your Cartfile to use `AppMover`:

```github "iamcalledrob/AppMover" ~> 1.0```

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

You can also specify a `installedName` if you'd like to guarantee that the app is named a
particular way in the Applications folder. e.g. ```AppMover.moveApp(installedName: .CFBundleName)```
to use the CFBundleName, which can be useful to prevent propogation of suffixes added by Archive Utility,
like "MyApp-1.app"

User Interface strings can be customised by passing in a `stringBuilder` parameter, e.g.
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

The `replaceNewerVersions` parameter can also be specified to control whether the app should
replace an existing installed app with a newer `CFBundleShortVersionString` (`true`), or switch
to the installed app instead (`false`).

## Credits

Inspired by [LetsMove](https://github.com/potionfactory/LetsMove/).

## License
The MIT License (MIT)

Copyright (c) 2020 Oskar Groth

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
