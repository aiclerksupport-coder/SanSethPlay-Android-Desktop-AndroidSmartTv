# SanSeth Play - ADB startup device setup (Hinglish)

## Sabse pehle
Run `adb devices -l`. Phone par USB debugging allow karo. Android TV par Developer options / Wireless debugging enable karo. Wireless TV ke liye `adb pair <TV_IP>:<PAIR_PORT>` (jab required ho), phir `adb connect <TV_IP>:<DEBUG_PORT>`. Port TV settings se lo, guess mat karo.

## Build + Install + GitHub push
`powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_TEST_INSTALL_GITHUB.ps1 -MobileSerial "<PHONE_ADB_SERIAL>" -TvSerial "<TV_ADB_SERIAL>"`

Angle-bracket values sirf documentation examples hain; literal copy nahi karna. `adb devices -l` mein jo exact serial listed ho, wahi use karo. Two devices connected and authorized hone chahiye. Phone aur TV serial alag honge. GitHub push only after all automated tests/builds/install/launch gates pass.

## Pehle sirf tests
`powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1`

## Phone-only ya TV-only checks
`powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1 -DeviceSerial "<PHONE_ADB_SERIAL>"`
`powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "<TV_ADB_SERIAL>"`

## Failure logs
Startup error ab terminal mein reason clearly dikhayega. Log: `failure-logs/FAILED_FULL_PIPELINE-v0.1.0+1.log`. GitHub push kabhi failure ke baad attempt nahi hota.

## Important
Android TV ka ADB support model-specific ho sakta hai. Samsung Tizen / LG webOS par Android APK install nahi hogi. Ye scripts Android TV/Google TV ke liye hain.
