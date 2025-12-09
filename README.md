# <img src="https://raw.githubusercontent.com/ComputerElite/ShockAlarmApp/refs/heads/main/web/icons/Icon-192.png" width="30" height="30" alt="Logo"> ShockAlarm
[<img src="https://github.com/user-attachments/assets/713d71c5-3dec-4ec4-a3f2-8d28d025a9c6"
    alt="Get it on Obtainium"
    height="80">](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/ComputerElite/ShockAlarmApp)&nbsp;
[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
    alt="Get it on F-Droid"
    height="80">](https://f-droid.org/packages/de.computerelite.shockalarm)

A powerful app for controlling [OpenShock](https://openshock.org/) shockers and setting alarms with custom tones.

A web version (for IOS, ...) can be found [here](https://computerelite.github.io/ShockAlarmApp/) (does not support live controls).

# Features
ShockAlarm is a powerful tool for controlling your Shockers via OpenShock. It allows you to fully manage your shockers, logs, shares, hubs, share links, tokens and sessions. On top it also allows you to seamlessly use ShareLinks.

There is advanced functionality like controlling multiple shockers at the same time, specifying a random interval for intensity, duration and a delay, live controls with patterns and alarms.

It's fully material you themed just like the standard Android apps you're already used to and provides a responsive ui with a nice design.

Furthermore it fixes some layout flaws of the official OpenShock Frontend like having shared and own shockers in separate tabs (which is annoying). On top it also has lots of info buttons you can press to get more insight on what something does.

You can also log in on multiple OpenShock instances at once. ShockAlarm will show all shockers from all instances seamlessly at a glance!

## Other information
I cannot guarentee that all features work with all possible configurations. I try to make them work with each other but sometimes I miss them. For example a random intensity won't work with the shock confirmation dialog. However a hard limit will.

### Not supported in Web Version
Everything with websockets is currently not supported due to authentication problems with websockets. This includes:
- OTA Updates
- Enabling/Disabling the captive portal
- Live control

# Installation on Android
## Through Obtainium (recommended as you get the updates the fastest)
[<img src="https://github.com/user-attachments/assets/713d71c5-3dec-4ec4-a3f2-8d28d025a9c6"
    alt="Get it on Obtainium"
    height="80">](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/ComputerElite/ShockAlarmApp)
1. Download [Obtainium](https://obtainium.imranr.dev/) either via [their website](https://obtainium.imranr.dev/) or [FDroid](https://f-droid.org/)
2. Add ShockAlarm by clicking [here](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/ComputerElite/ShockAlarmApp) or putting `github.com/ComputerElite/ShockAlarmApp` as th app source

## FDroid
[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
    alt="Get it on F-Droid"
    height="80">](https://f-droid.org/packages/de.computerelite.shockalarm)
1. [Download FDroid](https://f-droid.org/)
2. Search for ShockAlarm and install it. As easy as that!

## GitHub
Install the apk file from the [releases](https://github.com/ComputerElite/ShockAlarmApp/releases/latest)

# Installation on Linux
## Through the AUR
Use your favorite aur helper like [paru](https://github.com/Morganamilo/paru) or [yay](https://github.com/Jguer/yay) and install `shock-alarm`. [link to aur](https://aur.archlinux.org/packages/shock-alarm)

# Installation on Windows
## Installer
You can download a Windows installer from the [releases](https://github.com/ComputerElite/ShockAlarmApp/releases/latest) and then execute it.

## Portable
You can download a Portable version (zip file) from the [releases](https://github.com/ComputerElite/ShockAlarmApp/releases/latest), unzip and then execute it.

# Screenshots
![ShockAlarm](fastlane/metadata/android/en-US/images/phoneScreenshots/1.png)
![ShockAlarm](fastlane/metadata/android/en-US/images/phoneScreenshots/2.png)

[More images](fastlane/metadata/android/en-US/images/phoneScreenshots)

# Planned features
- [x] (Un)Pausing of shockers
- [x] Login with username/email and password
- [x] Random delay
- [x] Renaming of shockers (global)
- [x] Viewing of logs
- [x] Change sharing limits
- [x] Create share codes
- [x] Redeem share codes
- [x] Adding of shockers
- [x] Creation, editing and pairing of hubs
- [x] Add option to repeat default shock/vibration... option for one minute (perhaps adjustable in settings). Needs reworking of the alarm stop feature
- [x] Websocket controlling
- [x] Alarm tones
- [x] Grouping of shockers
- [x] Redo settings
- [x] Random intensity and duration
- [x] Safety warning
- [x] Share link management
- [x] Allow setting initial limits when adding a shocker
- [x] Add ui to rename tones
- [x] Better desktop support (keybinds)
- [x] Better desktop support (layout)
- [x] Better desktop support (dynamic layout)
- [x] Show 3 point menu when 1 shocker is selected
- [x] Share codes sometimes can't be claimed when the app is already open (treating as fixed for now)
- [x] Show loading animation when share codes are loading in after shares loaded
- [x] Allow toggling of the captive portal
- [x] Add alarm renaming
- [x] Finally code weekday scheduling for alarms
- [x] Add changing of shocker type (and even hub and rfId)
- [x] save last opened tab (and load it on start)
- [x] Random shocking (specify random delay between shocks, min and max intensity/duration)
- [x] Random shocking -> Add background task + notification (works without notification???)
- [x] Fix alarms not sending controls when app is minimized (seems to work)
- [x] Live controls
- [x] Allow alarm tones to be used as patterns
- [x] Request permissions only when needed
- [x] fix reloading problems in settings after login?
- [ ] ~~(Big controls mode)~~ fuck this shit, there's no space
- [x] Improved login for web (aka using token requests)
- [x] Web support (alarms working via AlarmServer)
- [x] Linux support (alarms working via AlarmServer)
- [x] Alarm support for Linux and web via https://dev1.rui2015.me
- [x] Add separate slider for shock and vibrate intensity
- [x] Add Alarm tone support for AlarmServer
- [x] Add info about alarm server
- [x] Code cleanup, add multiple predefined dialogs
- [x] Add online indicator for hubs on web
- [x] Add OTA Updates
- [x] Add Share Link support
- [ ] Fix WS on web
- [x] Add Patterns to live controls
- [x] Flaschendrehen
- [x] Add shock confirmation above adustable intensity and duration.
- [x] Adapt to new Backend duration limit
- [x] Add confirmation on live system as well. 
- [x] Add global limit for self.
- [x] Stop live playback when changing type
- [x] Make sure text in popups is scrollable so it can be read completely
- [x] Implement login V2 (Android only currently)
- [x] Implement Shares V2 (once officially declared done in backend and implementation in official frontend exists. Can't make sense of the api rn without explenation)

# Planned settings
- [x] Hide/unhiding of the delay option
- [x] Slider instead of RangeSlider for delay

# Development
This app is based on flutter and thus you need to first install flutter: https://docs.flutter.dev/get-started/install

Afterwards clone the repository and get all dependencies:

1. `git clone https://github.com/ComputerElite/ShockAlarmApp`
2. `cd ShockAlarmApp`
3. `flutter pub get`

# Publishing
## Steps for making a new release
1. Test functionality of app on Android, Web and Linux.
2. (when adding new packages) Test the Android build pipeline by [manually triggering](https://github.com/ComputerElite/ShockAlarmApp/actions/workflows/build_android.yml)
3. Bump the version in [pubspec.yaml](pubspec.yaml) and [main.dart](main.dart)
4. Create a changelog at [fastlane/metadata/android/en-US/changelogs](fastlane/metadata/android/en-US) in a file names `<versioncode>.txt`. It should be markdown formatted.
5. Create a new tag (or release) and push it to the repo. Actions will spin up to compile the binaries and add the previously created changelog to the release
6. (optional) Update the screenshots in [fastlane/metadata/android/en-US/images/phoneScreenshots/](fastlane/metadata/android/en-US/images/phoneScreenshots/) for FDroid and the ReadMe

## Publishing on FDroid
FDroid will publish the update autonomously once a build cycle starts. The changelog we created earlier will be added to the FDroid page automatically
