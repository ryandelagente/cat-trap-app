# Building in VS Code (no Android Studio IDE)

**The honest version:** VS Code is an editor, not a build system. The Android
build always needs a JDK, the Android SDK, and Gradle — whichever editor you use.
What you *can* skip is Android Studio's IDE. Install the **command-line tools
only** (~600MB vs 1GB+) and run everything from VS Code's terminal.

| Approach | Install size | Build time | Best for |
|----------|--------------|------------|----------|
| GitHub Actions (cloud) | 0 | ~6 min | Just shipping to Play |
| **VS Code + cmdline tools** | **~900MB** | **~2 min after first** | **Iterating on the game** |
| Android Studio | ~2.5GB | ~2 min | Native debugging you won't need |

Use both: VS Code day-to-day, GitHub Actions for release builds.

---

## Step 1 — Install Node.js and a JDK

- Node.js LTS: https://nodejs.org
- Temurin JDK 21: https://adoptium.net

Verify in VS Code's terminal (`` Ctrl+` ``):
```bash
node -v
java -version
```

## Step 2 — Install Android command-line tools

Download **"Command line tools only"** (not the full Studio) from the bottom of
https://developer.android.com/studio

Extract so the path ends up like:
```
~/android-sdk/cmdline-tools/latest/bin/sdkmanager
```
The `latest` folder name matters — sdkmanager fails without it.

## Step 3 — Set environment variables

**Mac/Linux** — add to `~/.zshrc` or `~/.bashrc`:
```bash
export ANDROID_HOME=$HOME/android-sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
```
Then `source ~/.zshrc`.

**Windows** — System Properties → Environment Variables → New:
```
ANDROID_HOME = C:\Users\<you>\android-sdk
```
Add to `Path`:
```
%ANDROID_HOME%\cmdline-tools\latest\bin
%ANDROID_HOME%\platform-tools
```
**Restart VS Code afterwards** — it caches environment variables at launch.
This is the #1 cause of "ANDROID_HOME not set" when you just set it.

## Step 4 — Install the SDK packages

```bash
sdkmanager --licenses          # accept all (press y repeatedly)
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

API 36 is required by Google Play for new submissions from August 31, 2026.

---

## Step 5 — Build

Open the project folder in VS Code, then either:

**Press `Ctrl+Shift+B`** (runs the default build task), or use
**Terminal → Run Task** and pick from:

| Task | What it does |
|------|--------------|
| ▶ Play game in browser | Serves `www/` at localhost:5000 — instant testing, no build |
| 🔨 Build Android AAB | Full release build → `out/` |
| 🔄 Sync web changes to Android | Copies `www/` changes into the Android project |
| 📱 Run on connected phone | Installs and launches on a USB-connected device |
| 🧹 Clean Android build | Clears Gradle output when things get weird |

First build downloads Gradle and dependencies (~5-10 min). After that, ~1-2 min.

---

## Day-to-day workflow

For game changes you do **not** need to rebuild the Android app every time:

1. Run **▶ Play game in browser** → edit `www/index.html` → refresh
2. Only when you're happy: **🔨 Build Android AAB**

Ads won't appear in the browser (no native SDK) — the code no-ops there by
design, and the rewarded "skip level" button still works so you can test the flow.

---

## Testing on your actual phone

1. Phone: Settings → About → tap **Build number** 7 times → Developer options →
   enable **USB debugging**
2. Connect by USB, then:
   ```bash
   adb devices        # should list your phone
   ```
3. Run task **📱 Run on connected phone**

This is the fastest way to feel whether the touch controls and difficulty land
right — the game plays very differently on a phone than with a keyboard.

---

## Signing for Play upload

```bash
keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias cattrap
```

Put `release.jks` in the project root. `build-local.sh` / `build-local.ps1`
detects it and signs the AAB automatically, prompting for the password.

🔴 `.gitignore` already excludes `*.jks` — never commit it. Back it up to Google
Drive + USB. Lose it and you can never update the published app.

To use your real AdMob App ID instead of the test one:
```bash
export ADMOB_APP_ID="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"   # Mac/Linux
$env:ADMOB_APP_ID="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"     # Windows
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `ANDROID_HOME not set` | Restart VS Code after setting it |
| `sdkmanager: command not found` | The `cmdline-tools/latest/` folder name is wrong |
| `Failed to install the following SDK components` | Run `sdkmanager --licenses` again |
| `gradlew: Permission denied` | `chmod +x android/gradlew` |
| Gradle hangs on first run | Normal — it's downloading ~500MB. Leave it. |
| Changes to the game don't show in the app | Run **🔄 Sync web changes** first |
| `adb devices` shows "unauthorized" | Accept the USB debugging prompt on the phone |
