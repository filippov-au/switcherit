# switcherit

switcherit switches keyboard layout with the Caps Lock key and runs quietly from the Windows tray.

## Usage

- **CapsLock** changes keyboard layout.
- **Alt+CapsLock** enables or disables switcherit.

## Administrator programs

Windows blocks a normal unelevated process from reliably controlling elevated programs. To switch layout inside programs running with administrator privileges, switcherit must also run with administrator privileges.

switcherit does not auto-elevate. Run it normally or as administrator depending on how you want to use it. This does not apply to secure desktop screens such as the UAC approval prompt itself.

## Build

Install Odin, MSVC, and the Windows SDK. Odin on Windows requires the Visual Studio C++ toolchain and Windows SDK.

```powershell
.\build.ps1
```

The executable is written to:

```text
build\switcherit.exe
```

The default build uses the Windows subsystem, so it starts as a tray app without opening a terminal window.

For a debug build:

```powershell
.\build.ps1 -Configuration debug
```

For stdout debug logs, build a console executable and launch it from PowerShell:

```powershell
.\build.ps1 -Configuration debug -Console
.\build\switcherit.exe --debug
```
