# Cat Trap Adventure — Cloud Build (no Android Studio needed)

GitHub Actions compiles and signs your Android App Bundle for free.
You upload the resulting `.aab` straight to the Play Console.

---

## Step 1 — Create your signing keystore (once, ~2 minutes)

This is the ONE thing that must happen on your own machine, because the private
key must never touch a server you don't control.

You need `keytool`, which ships with any JDK. If you don't have Java:
download Temurin JDK from https://adoptium.net (~200MB, much smaller than
Android Studio).

```bash
keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias cattrap
```

It asks for a password and some name/organization details (any values are fine).

🔴 **BACK UP `release.jks` AND THE PASSWORDS.** Google Drive + USB + password
manager. If you lose this file you can never update your app on Play again.

Now convert it to text so GitHub can store it:

```bash
# Mac/Linux
base64 -i release.jks -o keystore-base64.txt

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks")) > keystore-base64.txt
```

---

## Step 2 — Create the GitHub repo

1. Go to https://github.com/new → create a **private** repo named `cat-trap-app`
2. Upload every file in this folder (drag-and-drop works: **Add file → Upload
   files**). Make sure the `.github/workflows/` folder and the `www/` folder
   are included.

⚠️ **Never commit `release.jks` itself.** It goes in Secrets only (next step).

---

## Step 3 — Add your secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**.

| Secret name | Value |
|-------------|-------|
| `KEYSTORE_BASE64` | the entire contents of `keystore-base64.txt` |
| `KEYSTORE_PASSWORD` | your keystore password |
| `KEY_ALIAS` | `cattrap` |
| `KEY_PASSWORD` | your key password (same as above unless you set a different one) |
| `ADMOB_APP_ID` | `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` from AdMob |

If you skip these, the build still runs but produces an **unsigned** file that
Play will reject — useful only for testing that the build works.

---

## Step 4 — Build

Repo → **Actions** tab → **Build Android App** → **Run workflow**.

Enter:
- **versionCode**: `1` (increase by 1 for EVERY upload to Play — `2`, `3`, ...)
- **versionName**: `1.0.0`

Wait ~5–8 minutes. When it turns green, scroll to **Artifacts** at the bottom of
the run page and download **cat-trap-android-build**.

Inside: `cat-trap-adventure-release.aab` → this is what you upload to the Play
Console. An `.apk` is also produced if you want to sideload it onto your own
phone for a quick test.

---

## Step 5 — Change the package ID (do this BEFORE your first Play upload)

Edit `capacitor.config.json` and replace `com.nayrevil.cattrap` with your own
reverse-domain ID. **It can never be changed after publishing.**

---

## Updating the app later

1. Edit `www/index.html` (game changes) or config
2. Commit the change
3. Actions → Run workflow with versionCode **increased by 1**
4. Upload the new `.aab` to Play Console

---

## Swapping test ads for real ads

Before your production release, open `www/index.html`, find the `Ads.ids`
object near the bottom, and replace all three Google test unit IDs with your
real Banner / Interstitial / Rewarded unit IDs from AdMob.

Keep test IDs during closed testing. Clicking your own live ads gets your AdMob
account permanently banned.

---

## If the build fails

Open the failed run and read the red step:

| Error | Fix |
|-------|-----|
| `npm install` fails | Capacitor version mismatch — try `npm install` locally once and commit `package-lock.json` |
| Gradle "SDK not found" | Re-run the workflow; the SDK action occasionally times out |
| `jarsigner: keystore password was incorrect` | `KEYSTORE_PASSWORD` / `KEY_PASSWORD` secret is wrong |
| AAB rejected by Play: "not signed" | `KEYSTORE_BASE64` secret is missing or truncated |
| Play: "version code already used" | Increase versionCode and rebuild |
