# KeyRemapper

<p align="center">
  <img src="images/readme-icon.png" width="128" alt="KeyRemapper icon">
</p>

Keyboard remapper for macOS, configured with a JSON file. It seizes the keyboards via IOKit and posts the remapped events, so no driver is needed.

## Installation

Requires macOS 26 or later. Download `KeyRemapper-<version>.dmg` from the [latest release](https://github.com/goerwin/key-remapper/releases/latest), open it, and drag `KeyRemapper.app` to `/Applications`.

Releases are signed with an Apple Development certificate but are not notarized. If macOS blocks the first launch, choose **Open Anyway** in **System Settings > Privacy & Security**. Use **Check for Updates…** in the menu to install new releases.

## Permissions

On first launch, allow KeyRemapper in **System Settings > General > Login Items & Extensions**, then enable **Accessibility** and **Input Monitoring** under **System Settings > Privacy & Security**. These permissions let KeyRemapper remap keys system-wide.

## Config

Choose **Open Config folder** from the menu to edit `~/KeyRemapperMac/config.json`. Saving any JSON file there reloads the active profile.

```jsonc
{
  "profiles": [
    {
      "name": "My profile",
      // optionals, in ms
      "tapDelay": 200,
      "holdDelay": 400,
      "delayUntilRepeat": 300,
      "keyRepeatInterval": 25,
      "doubleClickSpeed": 500,

      "remaps": [],
      "rules": [],
      "tests": []
    }
  ]
}
```

Key names come from [symbols.json](KeyRemapper/Resources/symbols.json). The app's _Logger_ shows the current app and keyboard names. Mistakes (unknown fields or keys) are reported when the profile loads.

### Remaps

One to one, before the rules. The first one that matches wins.

```jsonc
[
  { "from": "CmdL", "to": "AltL", "keyboard": "50475:1133" },
  { "from": "Caps", "to": "F18" }
]
```

### Rules

The first rule that matches the pressed key replaces it, until it's released. Keys without a rule pass through.

```jsonc
[
  {
    "from": ["H"], // any of these keys
    "modifiers": ["CmdL"], // held, the others can't be (optional)
    "optional": ["ShiftL"], // can also be held, ["any"] for all (optional)
    "app": "com.google.Chrome", // or ["com.google.Chrome", "com.apple.finder"] (optional)
    "keyboard": "50475:1133", // productId:vendorId, a string or array too (optional)
    "if": "myVar", // these variables are on, a string or array (optional)
    "unless": "myVar", // these variables are off, a string or array (optional)

    "to": "LeftArrow", // on key down, without it the key is silenced
    "tap": "Esc", // released within tapDelay, without pressing other keys
    "doubleTap": "CmdL+F", // tapped twice
    "hold": "CmdL+W", // held for holdDelay, without other key events
    "afterKeyUp": "Esc" // on release, after the tap
  }
]
```

Only `from` is required. Any key can be a modifier (eg. `["F18", "F"]`), but only the real modifiers (Cmd, Alt, Ctrl, Shift and Fn) have to be listed in `modifiers` or `optional` to be held. The keys sent by the `modifiers` are released while the rule's key is pressed, so `Cmd + H` sending `LeftArrow` doesn't send `Cmd + LeftArrow`. After it's released, only the real modifiers are pressed again (any other key would be typed again).

Each action is space separated. Like Karabiner, the last key of `to` and `hold` is held until the key is released, the others are tapped. `tap`, `doubleTap` and `afterKeyUp` come on release, so all their keys are tapped. The keys of `hold` don't repeat.

```jsonc
"to": "C"                      // C, held
"to": "CmdL+ShiftL+C"          // with modifiers
"to": "Tab delay:250 Tab"      // waits 250ms
"to": "currentKey"             // the pressed key
"to": "AltL:up LeftClick"      // releases Alt, then holds the click
"to": "set:myVar"              // turns on a variable, unset:myVar turns it off
```

With several keys, an action can also have one item per key:

```jsonc
{
  "from": ["H", "J", "K", "L"],
  "modifiers": ["F18"],
  "optional": ["any"],
  "to": ["LeftArrow", "DownArrow", "UpArrow", "RightArrow"]
}
```

### Variables

Like Karabiner's `set_variable`, a variable stays on or off until an action changes it, and `if` and `unless` check it on key down. Reloading the profile turns them all off. Here F18 + F + H selects only if F is pressed after F18. If F is pressed first, it's typed and H only moves:

```jsonc
[
  {
    "from": ["F"],
    "modifiers": ["F18"],
    "optional": ["any"],
    "to": "set:vimShift",
    "afterKeyUp": "unset:vimShift"
  },
  { "from": ["H"], "modifiers": ["F18"], "if": "vimShift", "to": "ShiftL+LeftArrow" },
  { "from": ["H"], "modifiers": ["F18"], "to": "LeftArrow" }
]
```

A mode that a tap toggles:

```jsonc
[
  { "from": ["F19"], "unless": "myMode", "tap": "set:myMode" },
  { "from": ["F19"], "if": "myMode", "tap": "unset:myMode" }
]
```

For a click mode, a variable can track the physical modifier while `:up` releases its output. This avoids pressing the modifier again when the drag ends. Normal modifier shortcuts work before entering click mode; afterward, release and press the modifier again to use it normally. The same pattern works with Cmd, Ctrl, or any other key:

```jsonc
[
  {
    "from": ["AltL"],
    "optional": ["any"],
    "to": "AltL set:clickMode",
    "afterKeyUp": "unset:clickMode"
  },
  {
    "from": ["C"],
    "optional": ["any"],
    "if": "clickMode",
    "to": "AltL:up LeftClick"
  }
]
```

An explicit `:up` works in any action and releases the named key even when another rule pressed it. It doesn't release the physical key or turn off variables, so repeated C presses still click until Alt is physically released.

### Sharing parts of the config

`"%import(file.json)"` is replaced by that file, relative to the one importing it. In an array, an imported array is spread into it (see [Tests/imports.json](Tests/imports.json) or my [config](https://github.com/goerwin/dotfiles/blob/master/src/keyRemapperMac/config.json)).

```jsonc
{
  "remaps": "%import(_remaps.json)",
  "rules": ["%import(_vimMode.json)", { "from": ["A"], "to": "B" }]
}
```

### Tests

Each profile can have `tests`: pairs of input key events and the expected events sent to the OS. Inputs can also have `delay:{ms}`, `app:{name}` and `keyboard:{id}`.

```jsonc
"tests": [
  ["Caps", "Esc"],
  ["Caps:down delay:250 Caps:up", ""],
  ["app:com.google.Chrome CmdL:down H CmdL:up", "CmdL:down CmdL:up LeftArrow CmdL:down CmdL:up"]
]
```

## Development

```sh
make test                            # engine tests (Tests/)
make test-runtime                    # Mac runtime tests: key events in, posted events out (Tests/runtime.mm)
make test-app                        # builds, installs and drives the signed app's menu (Tests/app.sh)
make test-config [CONFIG=...]        # tests of each profile (default ~/KeyRemapperMac/config.json)
make build                           # unsigned Debug build of the Mac app
make install                         # builds, installs in /Applications, and launches the signed Release app
make dev-app                         # quits the app, builds and runs a local signed Debug app
make dev [CONFIG=... PROFILE=1 LOG=1] # run the remapper from the terminal
make icon                            # regenerates the app and menu bar icons from images/*.svg
```

- Use `$HOME` instead of `~` in `CONFIG`, zsh doesn't expand it there
- `make install` (or `Scripts/install.sh`) uses your Xcode signing identity, waits for the app and daemon to quit, and safely replaces `/Applications/KeyRemapper.app`. It asks for admin access only if needed. `Scripts/install.sh --no-build` reuses the last install build.
- To select a specific certificate, run `make install CODE_SIGN_IDENTITY="<certificate name or SHA-1>"`. This uses manual signing for both the app and daemon.
- `make test-app` replaces the installed app and needs _Accessibility_ for the terminal app. It briefly saves an invalid config to check reloading, and restores yours after. Physical keystrokes can't be automated (it would need a virtual HID driver), so try a few keys after it
- `make dev-app` launches `build/dev-app/Build/Products/Debug/KeyRemapper.app` without replacing the installed app or running tests. It uses your existing config and signing identity.
- `make dev` needs no app, helper or signing. Quit KeyRemapper first and grant _Input Monitoring_ and _Accessibility_ to the terminal app. Stop it with Ctrl+C
- Xcode: open `KeyRemapper.xcodeproj` and sign both targets (KeyRemapper, Daemon) with your Apple Development certificate. The daemon only accepts apps signed by the same team
- The app only restarts the daemon when its version changes, so after changing the daemon bump the version
- Icons: `images/icon.svg` and `images/menubar-icon.svg` are the sources, edit them and run `make icon` (needs `brew install librsvg`). Don't edit the files in `Assets.xcassets` directly

More dev notes in [NOTES.md](NOTES.md).

## Release

Push to `main`, then run `make release-patch`, `make release-minor` or `make release-major`. It previews the new version and its commits and, after confirmation, pushes an annotated tag. The [release workflow](.github/workflows/release.yml) builds the app and publishes its DMG, using the commits as release notes, and the `appcast.xml` that the installed apps check for updates ([Sparkle](https://sparkle-project.org)).

The workflow can also be run manually (_Actions > Run workflow_) to build without releasing.

The Mac build is signed with these repository secrets:

- `MAC_BUILD_CERTIFICATE_BASE64`: the Apple Development certificate (`.p12`) in base64 (`base64 -i certificate.p12`)
- `MAC_BUILD_CERTIFICATE_BASE64_PASSWORD`: its password
- `MAC_APP_CERTIFICATE`: its name, eg. `Apple Development: me@email.com (XXXXXXXXXX)`

And the updates with:

- `SPARKLE_PRIVATE_KEY`: the private EdDSA key whose public key is `SUPublicEDKey` in `KeyRemapper/Info.plist`. Sparkle's `generate_keys` keeps it in the login keychain (account `keyremapper`), `generate_keys --account keyremapper -x key.txt` exports it

## Troubleshooting

If you see **"Couldn't register the Daemon: The operation couldn't be completed. Operation not permitted"** on a Mac that had an older KeyRemapper version installed, a leftover legacy daemon may be blocking registration. Quit KeyRemapper, open Terminal, and run:

```sh
sudo launchctl remove co.goerwin.KeyRemapperDaemon
sudo rm -f /Library/LaunchDaemons/co.goerwin.KeyRemapperDaemon.plist
sudo rm -f /Library/PrivilegedHelperTools/co.goerwin.KeyRemapperDaemon
```

Then reopen KeyRemapper and allow it under **System Settings > General > Login Items & Extensions** if prompted.

## License

KeyRemapper's source code is licensed under the [MIT License](LICENSE). The KeyRemapper name, logo, app icon, menu bar icon, and artwork in `images/` and `KeyRemapper/Assets.xcassets/` are not covered by that license and are all rights reserved. Unofficial forks and redistributions must use their own branding and must not imply endorsement or affiliation.
