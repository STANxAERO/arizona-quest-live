# ARIZONA Quest Live

[Русская инструкция](README.ru.md) · [Downloads](https://github.com/STANxAERO/arizona-quest-live/releases)

Local, wireless, single-eye viewing for up to four Meta Quest headsets. Built for teaching VR graffiti at ARIZONA Hip-Hop Culture Center. No cloud relay, subscription, or WebStream VR required. This is an independent launcher around [scrcpy](https://github.com/Genymobile/scrcpy) and Android Debug Bridge (ADB), not a Meta product or a fork of WebStream VR.

## Download and install

**Windows 11 x64:** download the Windows ZIP from Releases, extract all files into a writable folder, and open `ARIZONA Quest Live.exe`. On first run, approve downloading the official scrcpy 5.0.1 archive; its SHA-256 is verified. The launcher uses Windows PowerShell 5.1 and .NET Framework 4.x. No administrator rights normally needed. If Windows marks downloaded scripts as remote, inspect the release checksum and source, then use Properties → Unblock on the trusted ZIP before extracting again (or unblock only these scripts). Do not disable SmartScreen or change your system-wide PowerShell execution policy.

**macOS 14+ on Apple Silicon:** download the macOS ZIP, extract it, and move the app to Applications. Install [Homebrew](https://brew.sh/) if needed; open Terminal and run:
```sh
brew install scrcpy python@3.13
brew install --cask android-platform-tools
```
Alternatively, run the included Install dependencies.command. Then open ARIZONA Quest Live.app. The first public build is locally ad-hoc signed, not Developer ID signed or notarized. Verify the checksum and inspect the source before allowing the specific app in System Settings → Privacy & Security if macOS blocks it. Allow local network access if prompted. Intel Macs are not included in this release.

## First-time setup (each headset, on each computer)

1. Enable Developer Mode on the Quest using Meta's official developer setup instructions; enable USB debugging.
2. Connect the desktop/laptop and headset to the same trusted private LAN. Connect **one** headset by USB data cable, put it on, and approve USB debugging for this computer. A new Mac or PC has its own ADB authorization.
3. Open the launcher. For Headset 1, click **USB / Wi-Fi** (Windows: **Set up USB / Wi-Fi**). Confirm the network ADB setup. This registers the headset by serial number and remembers its current address.
4. Once Wi-Fi connection succeeds, unplug the cable. Repeat for Headsets 2–4 as needed, one at a time.
5. Open a VR application such as Graffism. Click **Start all**, or reopen the launcher. Each registered, reachable headset opens in its own window.

## Daily use

Wake the registered headsets, connect them to the same LAN, launch the VR app, then open Quest Live. The launcher tries known ADB transports and cached addresses, then scans port 5555 on the directly connected private IPv4 LAN (bounded to /24 or smaller), verifies the serial number, and reconnects missing viewers. No router modification or internet connection is required for the video itself. Stop a stream with **Stop**; simply closing its viewer window may trigger automatic reopening. Close the launcher to end all streams.

Both versions support left/right eye, 16:9 crop, a 30 FPS target and automatic reconnection. Eye and aspect ratio changes automatically restart only the affected requested stream; stopped streams stay stopped. The per-headset settings are saved. Headsets 3 and 4 are collapsed by default; expand either header to access its controls. The main window adjusts its height without an internal scroll area. Windows uses rounded graphite panels and blue selection accents. macOS additionally offers quality presets (including a 60 FPS cap), automatically applied to requested streams, a manual restart fallback, and a Graffism shortcut. Actual FPS/latency depend on headset, Wi-Fi and scene.

## Troubleshooting and safety

- A full Quest reboot can disable TCP ADB; repeat USB setup. The launcher cannot remotely authorize a new computer or enable a disabled ADB listener.
- If no headset is found, verify Developer Mode, USB authorization, private LAN, client isolation and TCP 5555. Use the same Wi-Fi/LAN; discovery is not designed for routed subnets, guest networks or VPNs.
- Black screen: open a VR app and restart viewing. Some Horizon OS builds render black in system menus. This tool does not bypass protected content or OS security. If an external tool has changed Android's display size, restore its normal setting yourself; the launcher reports an override and does not change it.
- Use only your own or explicitly authorized devices, with informed consent of viewers/participants (and guardians where appropriate). Do not expose ADB port 5555 to the Internet. For sessions with students use a trusted, isolated LAN; stop viewing when finished. Disconnect ADB and switch back to USB debugging when network debugging is no longer needed (while connected, `adb -s <headset-address> usb`).
- Up to four registered slots are supported. Existing two-slot settings are migrated automatically. The public build starts with empty settings. To replace a registered headset, quit the app and back up/delete its local settings.json, then register your headsets again. Windows: `%LOCALAPPDATA%\ARIZONA Quest Live Public\settings.json`; macOS: `~/Library/Application Support/ARIZONA Quest Live Public/settings.json`. Never publish these settings or ADB keys.
- Offline Windows setup: obtain the official v5.0.1 win64 archive from the scrcpy release page, verify its SHA-256 (see windows/Setup.ps1), extract its contents into a folder named scrcpy next to the launcher.
- The app is a preview. Tested on the author's two Quest 3S headsets with different Horizon OS builds, Windows 11 and Apple Silicon macOS using the original local version. Public packaging and checks are documented in the release notes. Other headset models, OS versions, cold reboot and actual IP changes are not certified.

## Build / source

Windows: `windows/Launcher.cs` is the native .NET bootstrap; `QuestLive.ps1` is the WinForms UI, `DiscoverQuest.ps1` the discovery engine. Compile Launcher.cs using .NET Framework csc with `/target:winexe /reference:System.Windows.Forms.dll`; keep the three PowerShell files beside the resulting executable. PowerShell scripts must be UTF-8 with BOM on Windows PowerShell 5.1.

macOS: `bash macos/build.sh` builds an Apple Silicon app using the Xcode Swift toolchain. Python discovery is bundled as a resource; runtime ADB, Python and scrcpy are external Homebrew dependencies.

MIT license applies only to our launcher code. scrcpy is a separate Apache-2.0 project by Genymobile; Android SDK platform-tools are governed by Google's applicable terms. Dependencies are obtained separately from their official distribution channels. No third-party binaries, private keys, personal settings or Meta proprietary casting service are in the release archives. See [third-party notices](docs/THIRD_PARTY.md).

## Four-headset capacity / Четыре шлема

Four independent viewer slots; the default target bitrate is 5 Mbit/s per stream (20 Mbit/s total for four, excluding overhead). Four physical devices have not yet been tested together. Two-device physical validation is not a four-device capacity guarantee.

## Language and viewing mode (v0.3.0)

Use the **RU / EN** switch at the top right to change the application interface immediately. The language and viewing mode are remembered. Below RU / EN, the **Mode** control shows a circular grid (Fisheye, original single-eye view via scrcpy) and a straight square grid (Correction), with localized tooltips. Correction applies a radial FFmpeg lens correction and a central crop. Switching modes restarts only requested streams. Correction is an approximate profile checked against Quest 3S footage, not a calibrated optical model; it reduces the field of view and may add decoding/filtering load and latency. It does not modify the headset. No video files are retained: the corrected stream uses a private local FIFO (macOS) or named pipe (Windows).

Correction needs FFplay from FFmpeg. On Apple Silicon use `brew install ffmpeg` if ffplay is missing. On Windows install a build with ffplay from [FFmpeg's download page](https://ffmpeg.org/download.html) and ensure ffplay.exe is in PATH (restart the launcher after installation). The original mode does not require FFmpeg. LensViewer.exe must be beside the Windows launcher. To build the helper, compile windows/LensViewer.cs with the .NET Framework C# compiler using /target:winexe /platform:x64.

Preview: two live corrected windows were launched on both systems; the Mac corrected image was visually verified. Windows RU/EN switching and transitions were exercised, but intermittent initial window availability was observed. Latency, sustained four-device correction, and other headset optical profiles remain unmeasured.
