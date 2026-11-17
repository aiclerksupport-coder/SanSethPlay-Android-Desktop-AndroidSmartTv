# SanSeth Play — PowerShell pipeline failure fix

## User log se confirmed problems

1. `scripts/RUN_PIPELINE.ps1` returned `catch is not recognized`; Flutter tests actually ran hi nahi.
2. Parent script subsequent stages tak chal gayi, kyunki error exit code propagate nahi hua. Fix: child pipeline explicit `exit 1` and wrappers return process exit status.
3. `PHONE_SERIAL` and `TV_IP:DEBUG_PORT` literal placeholders the, connected device IDs nahi. Ab expensive tests shuru hone se pehle validation fail hoga.
4. `FAILED_windows_installer-v0.1.0+1.log` ka actual contents user ne share nahi kiya. Runner fix ke baad bhi compiler/Inno Setup issue ho sakta hai. Original Windows failure root cause claim nahi kar sakte.

## Verify

First see devices: `adb devices -l` (phone USB-debugging allowed; TV wireless debugging requires `adb connect ACTUAL_IP:ACTUAL_PORT`).

Run tests only: `powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1`

Full command (real ADB IDs): `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_TEST_INSTALL_GITHUB.ps1 -MobileSerial "ACTUAL_PHONE_SERIAL" -TvSerial "ACTUAL_TV_IP:PORT"`

Do not push until tests, mobile install/launch, TV install/launch, Windows EXE and installer installation all pass. Manual Cast, DVR, codecs and UI overflow verification is still required.

## Source delta

Changed only scripts/RUN_PIPELINE.ps1, RUN_ALL_TESTS.ps1, BUILD_ANDROID_MOBILE.ps1, BUILD_ANDROID_TV.ps1, BUILD_WINDOWS.ps1, BUILD_TEST_INSTALL_GITHUB.ps1 and added this report. No Dart, Kotlin, assets or application version modified.
