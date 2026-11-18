# Creates Android + Windows Flutter runners then patches Android for TV discovery.
# Execute from the source root. Requires Flutter SDK and Visual Studio C++ desktop workload.
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '..'))
$flutter = Get-Command flutter -ErrorAction Stop
flutter create --project-name sanseth_play --platforms android,windows .
if ($LASTEXITCODE -ne 0) { throw 'flutter create failed' }
# Keep our real widget test; flutter create's default test references obsolete MyApp.
$defaultWidgetTest = Join-Path (Get-Location) 'test/widget_test.dart'
if ((Test-Path $defaultWidgetTest) -and ((Get-Content -Raw $defaultWidgetTest) -match 'MyApp\(')) {
  throw 'flutter create generated obsolete MyApp test; use the packaged SanSethApp widget_test.dart'
}
$manifestPath = Join-Path (Get-Location) 'android/app/src/main/AndroidManifest.xml'
[xml]$xml = Get-Content -Raw $manifestPath
$androidNs = 'http://schemas.android.com/apk/res/android'
$root = $xml.manifest
$permission = @($root.SelectNodes('uses-permission') | Where-Object { $_.GetAttribute('name', $androidNs) -eq 'android.permission.INTERNET' })
if ($permission.Count -eq 0) {
  $node = $xml.CreateElement('uses-permission')
  $node.SetAttribute('name', $androidNs, 'android.permission.INTERNET')
  [void]$root.PrependChild($node)
}
# local_auth uses OS biometrics/device credentials; never embedded master PIN.
$biometric = @($root.SelectNodes('uses-permission') | Where-Object { $_.GetAttribute('name', $androidNs) -eq 'android.permission.USE_BIOMETRIC' })
if ($biometric.Count -eq 0) {
  $node = $xml.CreateElement('uses-permission')
  $node.SetAttribute('name', $androidNs, 'android.permission.USE_BIOMETRIC')
  [void]$root.PrependChild($node)
}
foreach ($featureName in @('android.hardware.touchscreen', 'android.software.leanback')) {
  $existing = @($root.SelectNodes('uses-feature') | Where-Object { $_.GetAttribute('name', $androidNs) -eq $featureName })
  if ($existing.Count -eq 0) {
    $node = $xml.CreateElement('uses-feature')
    $node.SetAttribute('name', $androidNs, $featureName)
    $node.SetAttribute('required', $androidNs, 'false')
    [void]$root.AppendChild($node)
  }
}
$activity = $xml.SelectSingleNode('/manifest/application/activity')
if ($null -eq $activity) { throw 'Could not find Android launcher Activity' }
$intentFilter = $xml.CreateElement('intent-filter')
$action = $xml.CreateElement('action')
$action.SetAttribute('name', $androidNs, 'android.intent.action.MAIN')
[void]$intentFilter.AppendChild($action)
$category = $xml.CreateElement('category')
$category.SetAttribute('name', $androidNs, 'android.intent.category.LEANBACK_LAUNCHER')
[void]$intentFilter.AppendChild($category)
$exists = $false
foreach ($f in $activity.SelectNodes('intent-filter')) {
  foreach ($c in $f.SelectNodes('category')) {
    if ($c.GetAttribute('name', $androidNs) -eq 'android.intent.category.LEANBACK_LAUNCHER') { $exists = $true }
  }
}
if (-not $exists) { [void]$activity.AppendChild($intentFilter) }
# TV launchers display banner artwork. Copy a real 320x180 brand image into drawable-nodpi.
$drawable = 'android/app/src/main/res/drawable-nodpi'
New-Item -ItemType Directory -Path $drawable -Force | Out-Null
Copy-Item 'assets/branding/android_tv_banner_320x180.png' (Join-Path $drawable 'tv_banner.png') -Force
# Same finalized S emblem in every Android launcher density, no wordmark.
foreach ($density in @('mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi')) {
  $resourceDir = "android/app/src/main/res/mipmap-$density"
  New-Item -ItemType Directory -Path $resourceDir -Force | Out-Null
  Copy-Item "tool/native_assets/ic_launcher_$density.png" (Join-Path $resourceDir 'ic_launcher.png') -Force
}
# Original full brand lockup for pre-Android-12 native launch screen.
# On Android 12+ the OS system splash icon is the brand S, per OS requirements;
# the native full artwork cannot be guaranteed 9:16 by Android system splash.
$launchDir = 'android/app/src/main/res/drawable-nodpi'
New-Item -ItemType Directory -Path $launchDir -Force | Out-Null
Copy-Item 'tool/native_assets/launch_logo.png' (Join-Path $launchDir 'launch_logo.png') -Force
$launchXml = 'android/app/src/main/res/drawable/launch_background.xml'
$launchXmlContent = @'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/black" />
    <item>
        <bitmap android:gravity="center" android:src="@drawable/launch_logo" />
    </item>
</layer-list>
'@
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $launchXml), $launchXmlContent)
$application = $xml.SelectSingleNode('/manifest/application')
$application.SetAttribute('banner', $androidNs, '@drawable/tv_banner')
$application.SetAttribute('icon', $androidNs, '@mipmap/ic_launcher')
# Android encrypted key material may not survive cloud backup/restore.
# Disable automatic app backup until a credential-safe recovery flow exists.
$application.SetAttribute('allowBackup', $androidNs, 'false')
# Local-only cleartext allowance for the temporary HLS DVR proxy.
# Do not broadly enable HTTP to arbitrary hosts for the timeshift feature.
$netSecDir = 'android/app/src/main/res/xml'
New-Item -ItemType Directory -Path $netSecDir -Force | Out-Null
$netSecXml = @'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
'@
[System.IO.File]::WriteAllText((Join-Path (Get-Location) (Join-Path $netSecDir 'network_security_config.xml')), $netSecXml)
# Fail early before Gradle if the generated Android network security XML changes unexpectedly.
[xml]$checkedNetSec = $netSecXml
$baseConfig = $checkedNetSec.SelectSingleNode('/network-security-config/base-config')
$domainConfig = $checkedNetSec.SelectSingleNode('/network-security-config/domain-config')
$domains = @($checkedNetSec.SelectNodes('/network-security-config/domain-config/domain'))
$expectedHosts = @('127.0.0.1', 'localhost')
if ($null -eq $baseConfig -or $baseConfig.GetAttribute('cleartextTrafficPermitted') -ne 'false' -or
    $null -eq $domainConfig -or $domainConfig.GetAttribute('cleartextTrafficPermitted') -ne 'true' -or
    $domains.Count -ne 2) {
  throw 'Android network security configuration must deny global cleartext and allow only the two local DVR hosts'
}
foreach ($domain in $domains) {
  if ($expectedHosts -notcontains $domain.InnerText -or $domain.GetAttribute('includeSubdomains') -ne 'false') {
    throw 'Android network security configuration includes an invalid domain or a missing includeSubdomains=false attribute'
  }
}

$application.SetAttribute('networkSecurityConfig', $androidNs, '@xml/network_security_config')
# PiP is opt-in and requires Android 8+ plus OS/device support.
$activity.SetAttribute('supportsPictureInPicture', $androidNs, 'true')

$xml.Save($manifestPath)
Write-Host 'Android Mobile + Windows native runners and Android TV launcher manifest ready.'

# Generate a native Android bridge only on Android Flutter runner; Windows remains unchanged.
# Flutter create defaults to com.example.sanseth_play unless organization is customized.
$gradleKts = 'android/app/build.gradle.kts'
$gradleGroovy = 'android/app/build.gradle'
$packageId = 'com.example.sanseth_play'
foreach ($gradlePath in @($gradleKts, $gradleGroovy)) {
  if (Test-Path $gradlePath) {
    $gradleText = Get-Content -Raw $gradlePath
    if ($gradleText -match 'namespace\s*[= ]\s*["'']([^"'']+)["'']') { $packageId = $Matches[1]; break }
  }
}
$kotlinRoot = 'android/app/src/main/kotlin'
$activityPath = Join-Path $kotlinRoot (($packageId -replace '\.', '/') + '/MainActivity.kt')
New-Item -ItemType Directory -Path (Split-Path $activityPath) -Force | Out-Null
$templatePath = Join-Path (Get-Location) 'tool/native_media_activity.kt.template'
if (-not (Test-Path $templatePath)) { throw 'Missing Android bridge template' }
$activitySource = [System.IO.File]::ReadAllText($templatePath).Replace('__PACKAGE__', $packageId)
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $activityPath), $activitySource)
Write-Host 'Android PiP + native MediaSession bridge prepared.'

# Google Cast Sender SDK. Required only for Android; Android TV is primarily
# a receiver and will not offer the sender control unless supported by GMS.
$castProviderTemplate = Join-Path (Get-Location) 'tool/cast_options_provider.kt.template'
$providerPath = Join-Path $kotlinRoot (($packageId -replace '\.', '/') + '/SanSethCastOptionsProvider.kt')
$providerSource = [System.IO.File]::ReadAllText($castProviderTemplate).Replace('__PACKAGE__', $packageId)
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $providerPath), $providerSource)
[xml]$castManifest = Get-Content -Raw $manifestPath
$appNode = $castManifest.SelectSingleNode('/manifest/application')
$existingCast = @($appNode.SelectNodes('meta-data') | Where-Object {
  $_.GetAttribute('name', $androidNs) -eq 'com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME'
})
if ($existingCast.Count -eq 0) {
  $meta = $castManifest.CreateElement('meta-data')
  $meta.SetAttribute('name', $androidNs, 'com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME')
  $meta.SetAttribute('value', $androidNs, "$packageId.SanSethCastOptionsProvider")
  [void]$appNode.AppendChild($meta)
}
$castManifest.Save($manifestPath)
$castDependency = 'implementation("com.google.android.gms:play-services-cast-framework:22.3.1")'
if (Test-Path $gradleKts) {
  $gradle = Get-Content -Raw $gradleKts
  if ($gradle -notmatch 'play-services-cast-framework') {
    if ($gradle -notmatch 'dependencies\s*\{') { $gradle += "`ndependencies {`n    $castDependency`n}`n" }
    else { $gradle = ([regex]::new('dependencies\s*\{')).Replace($gradle, "dependencies {`n    $castDependency", 1) }
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $gradleKts), $gradle)
  }
} elseif (Test-Path $gradleGroovy) {
  $gradle = Get-Content -Raw $gradleGroovy
  if ($gradle -notmatch 'play-services-cast-framework') {
    $gradle += "`ndependencies {`n    implementation 'com.google.android.gms:play-services-cast-framework:22.3.1'`n}`n"
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $gradleGroovy), $gradle)
  }
}
Write-Host 'Android Google Cast Sender SDK sources prepared (receiver device testing required).'
