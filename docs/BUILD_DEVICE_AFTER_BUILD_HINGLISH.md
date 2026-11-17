# Device detection sirf build ke baad

SanSeth Play v0.1.0+1 — Android phone aur TV ke liye pehle Flutter test/format/analyze/build hota hai. Connected device **build start karne ki condition nahi**.

- Mobile build without device: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`
- TV build without device: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1`
- Later install already-built APK on phone: `powershell -NoProfile -ExecutionPolicy Bypass -File .\INSTALL_BUILT_ANDROID.ps1 -Target mobile`
- Later install already-built APK on Android TV: `powershell -NoProfile -ExecutionPolicy Bypass -File .\INSTALL_BUILT_ANDROID.ps1 -Target tv`
- Full pipeline: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_TEST_INSTALL_GITHUB.ps1`

Zero matching devices at post-build install is a **skip**, not a build failure. More than one matching device requires explicit `-DeviceSerial`. APK is reused for mobile/TV; do not assume APK content differs by running same Flutter build twice. GitHub push remains blocked unless both install receipts plus Windows installer verification pass in the current master run. A device connected after master exited can be installed with the standalone script; the master release gate should be rerun to approve a push (existing receipt does not automatically grant push). Codec, DVR, Cast, TV remote and UI acceptance still require physical hardware tests.
