# AirCard 🎴

> **Apple Wallet Card Skinner & Lockscreen Passcode Themer for iOS 18+ (No Jailbreak Required)**  
> **Tested on iOS 27 release.**
> Powered by the `airlift` AirTraffic sync exploit.

<p align="left">
  <a href="https://www.paypal.com/donate/?hosted_button_id=98QRTC2HFRA4Y"><img src="https://img.shields.io/badge/Donate-PayPal-00457C?style=flat-square&logo=paypal" alt="Donate with PayPal" /></a>
</p>

---

## Features
- 🎨 **Custom Card Skins:** Assign custom artwork, textures, or bank logos to Apple Pay and Wallet cards.
- 🔢 **Lock Screen Passcode Themes (.passthm):** Apply custom keypad button artwork from popular `.passthm` themes directly to iOS 18+ lockscreen.
- 🧩 **Passcode Theme Creator:** Create custom themes from a single wallpaper (Seamless Poster Slicing) or build key-by-key (Individual Keys).
- 🔍 **Interactive Photo Framing:** Pan and zoom artwork directly inside keypad buttons with real-time iPhone preview.
- ✏️ **Edit Existing .passthm Themes:** Open any Cowabunga or Nugget theme package directly in the creator, tweak button artwork, reposition photos, and re-export or flash.
- ⚡ **Per-Card & Bulk Customization:** Set unique artwork for each card or apply one design across all cards with a single click.
- 📱 **Zero-Hassle Card Detection:** Tap any card in your iPhone's Wallet app to detect its hash in real-time.
- 🚀 **100% Standalone (Universal):** Native support for both **Apple Silicon** and **Intel (x86)** Macs. All required device-communication utilities and image engines are pre-bundled inside the app.
- 📦 **Zero Prerequisites:** No Homebrew, Python packages, or terminal setup required for macOS users.

---

## Installation

### macOS (Universal DMG)
1. Download **`AirCard.dmg`** from [Releases](https://github.com/mak5er/AirCard/releases).
2. Open `AirCard.dmg` and drag **`AirCard.app`** into your **Applications** folder.
3. Fully compatible with both **Apple Silicon** and **Intel (x86)** Macs.

> [!NOTE]
> **First Launch on macOS (Gatekeeper):**
> If macOS displays an unidentified developer prompt on first launch:
> - **Method 1 (UI):** Right-click (or Control-click) `AirCard.app` in Applications ➔ click **Open** ➔ click **Open**.
> - **Method 2 (Terminal):**
>   ```sh
>   sudo xattr -cr /Applications/AirCard.app
>   ```

---

## How to Customize Apple Wallet Cards
1. Connect your iPhone to your Mac via USB cable and ensure it is unlocked and trusted.
2. In AirCard, stay on the **Wallet Cards** tab and click **Scan Cards**.
3. On your iPhone:
   - **Double-click the Side (Power) button** to open Apple Pay.
   - Authenticate with **Face ID**.
   - **Tap your card** (or tap it once more) to trigger instant detection!
4. Click on any card mockup or drag & drop an image directly onto the card.
5. Click **Flash Skins**.
6. Force-close the **Wallet** app on your iPhone from the App Switcher (or reboot) to see your new custom card design!

### If scanning finds no cards

The scanner uses the iPhone's unified log service, including Info/Debug events.
On iOS 18.6.2, the legacy log service can show Wallet activity while omitting the
resource lookup messages that contain card identifiers.

Open **Log** and check for `Connected to the unified device log stream`, then
double-click the side button, authenticate, and tap or switch cards. If the log
reader stops, reconnect and unlock the iPhone, then start another scan. Values
that iOS replaces with `<private>` cannot be recovered by the scanner.

If your device previously connected but scanning found zero cards, please try
this build and report whether it helps. Include your iPhone model, iOS version,
macOS version, and the AirCard version or commit tested. Avoid posting full
device logs or card identifiers. See [scanner validation](docs/wallet-card-detection.md)
for the verified environment and remaining coverage.

---

## How to Apply Lockscreen Passcode Themes (.passthm)
1. Switch to the **Passcode Themes** tab at the top of AirCard.
2. Drag & drop any `.passthm` file into the app (or click **Choose .passthm File**).
3. AirCard will inspect the theme and display an interactive preview on the numeric keypad (0–9, *, #).
4. Click **Apply Passcode Theme**.
5. Restart your iPhone to reload the lock screen cache and see your custom passcode buttons!

> [!TIP]
> **Universal Language & Bold Text Support:**  
> AirCard automatically expands and flashes custom keypad assets for all system locales (English, Ukrainian, Russian, Spanish, German, French, etc.) and generates both standard and **Bold Text** cache bitmaps (`--white` and `--white-bold`), ensuring your theme works regardless of your iOS language or accessibility display settings!

---

## Building from Source

```sh
git clone https://github.com/mak5er/AirCard.git
cd AirCard
chmod +x build.sh
./build.sh
```
This builds universal binaries (`arm64` + `x86_64`), bundles dependencies into `build/AirCard.app`, and outputs `build/AirCard.dmg`.

---

## Localization

AirCard ships with six UI languages and follows the macOS **system language** automatically:

| Language | Folder |
| --- | --- |
| English (reference) | `Localizations/en.lproj` |
| 简体中文 | `Localizations/zh-Hans.lproj` |
| 繁體中文（台灣） | `Localizations/zh-Hant.lproj` |
| 日本語 | `Localizations/ja.lproj` |
| 한국어 | `Localizations/ko.lproj` |
| Tiếng Việt | `Localizations/vi.lproj` |

`build.sh` copies every `Localizations/<lang>.lproj` folder into `Contents/Resources`, where Foundation resolves it at runtime — no code change is needed to add or update a language.

### How the tables work
- **Keys are the English source strings** used in `AirCardApp.swift`. SwiftUI's `Text("...")`, `Button("...")`, `Label(...)` and `.help(...)` look these up automatically; dynamic strings go through `L()` / `Lf()` in `Localization.swift` (e.g. `Lf("Card #%d", index + 1)`).
- Progress messages from `aircard_backend.py` are emitted as a semantic `code` + `params` pair and rendered by `BackendMessage` using the same English templates, so the status bar and activity log are localized too. Older backends that only send a `message` field still display correctly.
- A missing key falls back to its English text, so partial translations degrade gracefully.
- `%@` / `%d` placeholders are part of the key and must keep the same count, type and order.
- Brand names and technical identifiers (`AirCard`, `.passthm`, `TelephonyUI-*`, `device_helper`, `airwallet`…) stay in English on purpose.

### Replacing translations
1. Open the target `Localizations/<lang>.lproj/Localizable.strings` and edit the text **after** the `=` sign only.
2. Never rename the keys on the left.
3. Keep `**bold**` markers and `\n` escapes intact.

### Adding a new language
1. Copy `Localizations/en.lproj` to `Localizations/<code>.lproj` (for example `de.lproj`).
2. Translate the values, keeping every key.
3. Add the code to `CFBundleLocalizations` inside `build.sh`.
4. Run `./build.sh` — the new folder is installed automatically.

### Verifying coverage
```sh
python3 tools/check_localizations.py            # report
python3 tools/check_localizations.py --strict   # non-zero exit when incomplete
```
The script extracts the keys referenced by the Swift sources, compares them with `en.lproj`, and then reports missing, extra or placeholder-mismatched entries for every other language.

---

## Contributors
- **[@mak5er](https://github.com/mak5er)** (Developer) — [GitHub](https://github.com/mak5er) · [Twitter / X](https://x.com/mak5er)
- **[@Lumid-Off](https://github.com/Lumid-Off)** (Contributor & Developer) — [GitHub](https://github.com/Lumid-Off) · [Twitter / X](https://x.com/LumidOff)
- **[AirLift](https://github.com/0xjohnnydev/airlift)** by **[0xjohnny (@0xjohnnydev)](https://github.com/0xjohnnydev)**: Original AirTraffic/ATAirlock sandbox escape and proof of concept underlying `AirliftFFI`.

## Credits
- Core exploit based on `airlift` (AirTraffic sync escape).

---

## Support

If you find AirCard useful, you can support future development:

- **PayPal**: [Donate via PayPal](https://www.paypal.com/donate/?hosted_button_id=98QRTC2HFRA4Y)
- **TON**: `UQBm9KPhtMw-XVVjirUoa09wzrlyWsbeZhKfefl1Uw-qNZ-r`
- **USDT (TRC20)**: `TDkDMCyjYxgvkWUnQiF5Erk2RyPQMT6G1n`
- **USDT / BNB (BEP20)**: `0x0954dc491c502849d04956ef74634aa5931a08e8`
