# HP Printer Fix for macOS (Sequoia, Tahoe, macOS 27 and Later)

Fix HP printer driver installation and printing errors on macOS Sequoia, Tahoe, macOS 27, and future versions — fully tested and working on both **Apple Silicon (M1/M2/M3/M4)** and **Intel** Macs.

The official HP drivers fail to install on modern macOS versions due to an artificial version check in the installer package. Furthermore, on Apple Silicon Macs, print jobs often fail with *"The printer software is not compatible with this device"* because HP's legacy driver filters are Intel-only binaries. This repository provides the pre-built fixed package, an automated patch script, and an in-depth explanation of how the fix works.

---

## ⚡ Quick Start: Download the Pre-Patched Package

If you don't want to extract or modify files manually, download the ready-to-install package directly:

👉 **[Download HewlettPackardPrinterDrivers-fixed.pkg (Latest Release)](../../releases/latest)**

1. Download `HewlettPackardPrinterDrivers-fixed.pkg`.
2. Double-click to install (or run `sudo installer -pkg HewlettPackardPrinterDrivers-fixed.pkg -target /`).
3. If you are on an Apple Silicon Mac, make sure Rosetta 2 is installed (see [Apple Silicon Requirement](#apple-silicon-m-series-requirement-rosetta-2) below).
4. Go to **System Settings > Printers & Scanners**, add your printer, and select your model under **Select Software...**.

---

## Supported Printer Models

The `HewlettPackardPrinterDrivers.pkg` contains drivers for many HP LaserJet and OfficeJet models. This fix has been confirmed to work with:

- **HP LaserJet P1102 / Pro P1102 / Pro P1102w**
- **HP LaserJet P1108**
- **HP LaserJet Pro M1136**
- **HP LaserJet M12 / M12W / M13 series**
- **HP LaserJet P1007**
- **HP LaserJet 4000N**
- *(And other HP LaserJet/OfficeJet models using the Apple HewlettPackardPrinterDrivers package)*

> If this fix works for your printer model, please [open an issue](../../issues) to let us know so we can add it to the list!

---

## 🔍 What Happened: Root Cause Analysis

### Problem 1: The Installer Version Ceiling Check
When you attempt to run Apple's official `HewlettPackardPrinterDrivers.pkg` (v5.1.1) on macOS Sequoia (15.1+), Tahoe (26.x), or macOS 27.x, the installer abruptly aborts with:
> `installer: Error - This update requires macOS version 15.0 or earlier.`

**Why this happens:**
The package's internal `Distribution` XML contains an embedded JavaScript check:
```javascript
function InstallationCheck(prefix) {
    if (system.compareVersions(system.version.ProductVersion, '15.0') > 0) {
        my.result.message = system.localizedStringWithFormat('ERROR_25CBFE41C7', '15.0');
        my.result.type = 'Fatal';
        return false;
    }
    return true;
}
```
Previous community workarounds attempted to replace `'15.0'` with `'27.0'`. However, on minor updates like **macOS 27.0.1** (or 27.1), `system.compareVersions('27.0.1', '27.0') > 0` evaluates to **true**, which trips the fatal check again!

### Problem 2: "The printer software is not compatible with this device" on Apple Silicon
After successfully bypassing the installer check and installing the driver, sending a print job from apps like Microsoft Word or Preview resulted in the queue stopping with:
> **"The printer software is not compatible with this device."**
> **"Stopped, ... 'Data' failed"**

**Why this happens:**
HP's printer driver filters (for example, `/Library/Printers/hp/laserjet/p1100_1560_1600series/hpRaster.bundle/Contents/MacOS/rastertozjs`) are compiled strictly for Intel (`x86_64`) architecture.
When CUPS attempts to invoke `rastertozjs` on an Apple Silicon (`arm64`) Mac that does not have **Rosetta 2** installed, the kernel rejects the binary with POSIX error 86 (`Bad CPU type in executable`). macOS catches this execution failure and displays the "not compatible with this device" warning in the print queue.

---

## 🛠️ How All the Fixes Were Done

### 1. Permanent Bypass of the Distribution Check
Instead of replacing the version number with another temporary version ceiling, we patched the `Distribution` file so that `InstallationCheck` unconditionally succeeds:
- Inserted `return true;` at the beginning of `function InstallationCheck(prefix)` so that it immediately exits without executing any version comparisons.
- Bumped comparison targets (`'15.0'`, `'27.0'`) to `'999.0'` as an additional safety fallback.
- Added `arm64` to `<options hostArchitectures="x86_64"/>` (`hostArchitectures="x86_64,arm64"`), allowing macOS Installer to cleanly validate the package for Apple Silicon architectures.

### 2. Apple Silicon M-Series Requirement: Rosetta 2
Because the underlying HP rasterizer binaries (`rastertozjs`, `usbink`, etc.) are legacy 64-bit Intel binaries, Rosetta 2 is required to translate and execute them on Apple Silicon.

To install Rosetta 2, simply run in Terminal:
```bash
softwareupdate --install-rosetta --agree-to-license
```
Once Rosetta 2 is installed, `rastertozjs` executes smoothly without recompilation, and macOS sends raster data directly to the printer.

---

## 🚀 Installation Methods

### Method 1: Pre-Patched Package (Easiest)
Download `HewlettPackardPrinterDrivers-fixed.pkg` from the [Releases](../../releases/latest) page and double-click to install.

### Method 2: Automated Script
1. Download the official [HP Mac Printer Driver](https://support.hp.com/us-en/drivers/closure/hp-laserjet-pro-p1102-drucker/model/4110303).
2. Open the `.dmg` and copy `HewlettPackardPrinterDrivers.pkg` into a folder.
3. Download [`install-driver.sh`](install-driver.sh) into the same folder.
4. Run:
   ```bash
   chmod +x install-driver.sh
   ./install-driver.sh
   ```
5. Install the generated `HewlettPackardPrinterDrivers-fixed.pkg`.

### Method 3: Browser-Based Web Tool
Use the client-side tool at **[pavelbinar.github.io/hp-printer-fix-macos](https://pavelbinar.github.io/hp-printer-fix-macos/)** (or in this repo under `/docs/index.html`). Drag and drop your `.pkg` file into the browser to generate the fixed installer.

### Method 4: Manual Command Line Patch
```bash
# 1. Expand the original package
pkgutil --expand HewlettPackardPrinterDrivers.pkg drivers

# 2. Patch the Distribution file to bypass version checks and add arm64 support
sed -i '' "s/function InstallationCheck(prefix) {/function InstallationCheck(prefix) { return true;/g" drivers/Distribution
sed -i '' "s/'15.0'/'999.0'/g" drivers/Distribution
sed -i '' 's/hostArchitectures="x86_64"/hostArchitectures="x86_64,arm64"/g' drivers/Distribution

# 3. Repackage the fixed driver
pkgutil --flatten drivers HewlettPackardPrinterDrivers-fixed.pkg

# 4. Clean up
rm -rf drivers
```

---

## 🖨️ Adding the Printer in macOS

Once the driver package is installed:

1. Connect your HP printer via USB (or your network).
2. Go to **System Settings > Printers & Scanners**.
3. Click **Add Printer, Scanner, or Fax...** (`+`).
4. Select your HP printer from the list.
5. In the **Use** dropdown menu, click **Select Software...**.
6. Search for your model (e.g. `HP LaserJet Professional P1102` or `P1108`).
7. Click **OK**, then **Add**.

---

## ❓ Troubleshooting

### "The printer software is not compatible with this device" / "Stopped, Data failed"
- **Cause:** You are on an Apple Silicon Mac without Rosetta 2 installed.
- **Fix:** Run `softwareupdate --install-rosetta --agree-to-license` in Terminal. Afterwards, remove and re-add the printer in System Settings to refresh the queue.

### "Must be run as root to install this package"
- Run the installer with `sudo` in Terminal:
  ```bash
  sudo installer -pkg HewlettPackardPrinterDrivers-fixed.pkg -target /
  ```
  Or double-click the `.pkg` file in Finder and enter your Mac password when prompted.

---

## Disclaimer

This is an unofficial community fix and is not officially affiliated with or supported by HP or Apple. Use at your own discretion.

## Credits

- Original workaround and investigation by [Kartones](https://blog.kartones.net/post/macos-sequoia-hp-laserjet-p1102-drivers/).
- Tahoe and packaging improvements by [@3l500nfy](https://github.com/3l500nfy).
- Web tool implementation by [@pavelbinar](https://github.com/pavelbinar).
- macOS 27+ version bypass, Apple Silicon / Rosetta 2 fixes, and universal package release by [@PratyushKumar16](https://github.com/PratyushKumar16).
