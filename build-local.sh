#!/usr/bin/env bash
# Build Cat Trap Adventure locally (Mac/Linux) — run from VS Code's terminal
set -e

echo "=== Cat Trap Adventure — local build ==="

# --- checks ---
command -v node >/dev/null || { echo "❌ Node.js not found — install from nodejs.org"; exit 1; }
command -v java >/dev/null || { echo "❌ Java not found — install Temurin JDK 21 from adoptium.net"; exit 1; }
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
  echo "❌ ANDROID_HOME not set. See LOCAL-BUILD-VSCODE.md step 3."; exit 1;
fi
echo "✅ node $(node -v) | java $(java -version 2>&1 | head -1 | cut -d'"' -f2)"

# --- dependencies ---
[ -d node_modules ] || npm install

# --- generate android project on first run ---
if [ ! -d android ]; then
  echo "→ Generating Android project..."
  npx cap add android
fi

# --- target API 36 (required by Google Play from Aug 31, 2026) ---
sed -i.bak 's/compileSdkVersion = .*/compileSdkVersion = 36/' android/variables.gradle
sed -i.bak 's/targetSdkVersion = .*/targetSdkVersion = 36/'   android/variables.gradle
rm -f android/variables.gradle.bak

# --- AdMob App ID ---
APPID="${ADMOB_APP_ID:-ca-app-pub-3940256099942544~3347511713}"
[ -z "$ADMOB_APP_ID" ] && echo "⚠️  Using Google TEST AdMob App ID (set ADMOB_APP_ID to override)"
python3 - "$APPID" <<'PY'
import sys
appid = sys.argv[1]
p = 'android/app/src/main/AndroidManifest.xml'
x = open(p).read()
if 'gms.ads.APPLICATION_ID' not in x:
    meta = ('        <meta-data\n'
            '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
            f'            android:value="{appid}"/>\n')
    open(p,'w').write(x.replace('    </application>', meta + '    </application>'))
    print('→ AdMob App ID injected')
PY

# --- build ---
npx cap sync android
cd android
chmod +x gradlew
./gradlew bundleRelease assembleRelease --no-daemon
cd ..

mkdir -p out
find android/app/build/outputs -name "*.aab" -exec cp {} out/ \;
find android/app/build/outputs -name "*.apk" -exec cp {} out/ \;

# --- sign if a keystore is present ---
if [ -f release.jks ]; then
  read -rsp "Keystore password: " KSPASS; echo
  read -rp  "Key alias: " ALIAS
  AAB=$(find out -name "*.aab" | head -1)
  jarsigner -keystore release.jks -storepass "$KSPASS" \
    -sigalg SHA256withRSA -digestalg SHA-256 "$AAB" "$ALIAS"
  jarsigner -verify "$AAB" >/dev/null && echo "✅ Signed: $AAB"
else
  echo "⚠️  No release.jks found — output is UNSIGNED (cannot upload to Play)."
  echo "   Create one:  keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cattrap"
fi

echo ""
echo "=== Done. Files in ./out ==="
ls -la out/
