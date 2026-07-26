# Build Cat Trap Adventure locally (Windows) — run from VS Code's PowerShell terminal
$ErrorActionPreference = "Stop"

Write-Host "=== Cat Trap Adventure - local build ===" -ForegroundColor Cyan

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "Node.js not found - install from nodejs.org" }
if (-not (Get-Command java -ErrorAction SilentlyContinue)) { throw "Java not found - install Temurin JDK 21 from adoptium.net" }
if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) { throw "ANDROID_HOME not set - see LOCAL-BUILD-VSCODE.md step 3" }

if (-not (Test-Path node_modules)) { npm install }

if (-not (Test-Path android)) {
  Write-Host "-> Generating Android project..." -ForegroundColor Yellow
  npx cap add android
}

# Target API 36 (required by Google Play from Aug 31, 2026)
$v = Get-Content android/variables.gradle
$v = $v -replace 'compileSdkVersion = .*', 'compileSdkVersion = 36'
$v = $v -replace 'targetSdkVersion = .*',  'targetSdkVersion = 36'
Set-Content android/variables.gradle $v

# AdMob App ID — Cat Trap Adventure live App ID (not secret; ships in every APK).
# Override via `$env:ADMOB_APP_ID = "..."` when building a different app.
$appId = if ($env:ADMOB_APP_ID) { $env:ADMOB_APP_ID } else {
  "ca-app-pub-0733808293057598~1343445756"
}
$manifest = "android/app/src/main/AndroidManifest.xml"
$xml = Get-Content $manifest -Raw
if ($xml -notmatch "gms.ads.APPLICATION_ID") {
  $meta = "        <meta-data`n            android:name=`"com.google.android.gms.ads.APPLICATION_ID`"`n            android:value=`"$appId`"/>`n"
  $xml = $xml -replace "    </application>", "$meta    </application>"
  Set-Content $manifest $xml
  Write-Host "-> AdMob App ID injected" -ForegroundColor Green
}

npx cap sync android

Push-Location android
./gradlew.bat bundleRelease assembleRelease --no-daemon
Pop-Location

New-Item -ItemType Directory -Force -Path out | Out-Null
Get-ChildItem -Path android/app/build/outputs -Recurse -Include *.aab,*.apk | Copy-Item -Destination out

if (Test-Path release.jks) {
  $ksPass = Read-Host "Keystore password" -AsSecureString
  $plain  = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ksPass))
  $alias  = Read-Host "Key alias"
  $aab    = (Get-ChildItem out -Filter *.aab | Select-Object -First 1).FullName
  jarsigner -keystore release.jks -storepass $plain -sigalg SHA256withRSA -digestalg SHA-256 $aab $alias
  jarsigner -verify $aab
  Write-Host "Signed: $aab" -ForegroundColor Green
} else {
  Write-Host "WARNING: No release.jks found - output is UNSIGNED (cannot upload to Play)." -ForegroundColor Yellow
  Write-Host "  Create one: keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cattrap"
}

Write-Host "`n=== Done. Files in .\out ===" -ForegroundColor Cyan
Get-ChildItem out
