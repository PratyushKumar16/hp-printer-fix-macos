#!/bin/bash

# HP Printer Driver Installer for macOS Sequoia, Tahoe and later
# Based on: https://blog.kartones.net/post/macos-sequoia-hp-laserjet-p1102-drivers/
# Modifies the Distribution file to bypass the macOS version check (blocks versions > 15.0)

# Print colored output
print_green() {
    echo -e "\033[0;32m$1\033[0m"
}

print_yellow() {
    echo -e "\033[0;33m$1\033[0m"
}

print_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# Determine source: .pkg file or already-expanded package
DRIVERS_DIR=""
CLEANUP_AFTER=0

if [ -f "HewlettPackardPrinterDrivers.pkg" ]; then
    print_green "Expanding the HP driver package..."
    pkgutil --expand HewlettPackardPrinterDrivers.pkg drivers
    DRIVERS_DIR="drivers"
    CLEANUP_AFTER=1
elif [ -f "Distribution" ]; then
    print_green "Using already-expanded package in current directory..."
    DRIVERS_DIR="."
else
    print_red "Error: HewlettPackardPrinterDrivers.pkg or expanded package not found."
    print_yellow "Please extract the .pkg from the HP driver .dmg, or run this script from the expanded package directory."
    exit 1
fi

# Check if the Distribution file exists
if [ ! -f "$DRIVERS_DIR/Distribution" ]; then
    print_red "Error: Distribution file not found."
    exit 1
fi

# Modify the Distribution file to bypass the macOS version check
# Make InstallationCheck return true unconditionally and bump version check to 999.0
print_green "Modifying the Distribution file to bypass macOS version check..."
sed -i '' "s/function InstallationCheck(prefix) {/function InstallationCheck(prefix) { return true;/g" "$DRIVERS_DIR/Distribution"
sed -i '' "s/'15.0'/'999.0'/g" "$DRIVERS_DIR/Distribution"
sed -i '' "s/'27.0'/'999.0'/g" "$DRIVERS_DIR/Distribution"

# Also allow installation on Apple Silicon (arm64) architectures
sed -i '' 's/hostArchitectures="x86_64"/hostArchitectures="x86_64,arm64"/g' "$DRIVERS_DIR/Distribution"

# Check if the modification was successful
if grep -q "function InstallationCheck(prefix) { return true;" "$DRIVERS_DIR/Distribution" || grep -q "'999.0'" "$DRIVERS_DIR/Distribution"; then
    print_green "Distribution file successfully modified."
else
    print_red "Error: Failed to modify the Distribution file."
    exit 1
fi

# Create the modified package
print_green "Creating the modified package..."
pkgutil --flatten "$DRIVERS_DIR" HewlettPackardPrinterDrivers-fixed.pkg

# Check if the new package was created
if [ ! -f "HewlettPackardPrinterDrivers-fixed.pkg" ]; then
    print_red "Error: Failed to create the modified package."
    exit 1
fi

# Clean up temporary directory (only if we expanded from .pkg)
if [ "$CLEANUP_AFTER" -eq 1 ]; then
    print_green "Cleaning up temporary files..."
    rm -rf drivers
fi

print_green "Installation package successfully created!"
print_green "The modified driver package is: HewlettPackardPrinterDrivers-fixed.pkg"
echo ""
print_yellow "To install the driver, you can either:"
print_yellow "1. Run the terminal command:"
print_yellow "   sudo installer -pkg HewlettPackardPrinterDrivers-fixed.pkg -target /"
print_yellow "2. Or double-click 'HewlettPackardPrinterDrivers-fixed.pkg' in Finder."

# Check if running on Apple Silicon and check Rosetta 2
if [ "$(uname -m)" = "arm64" ]; then
    if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
        echo ""
        print_yellow "=========================================================="
        print_yellow "Notice: Apple Silicon (M-series Mac) detected."
        print_yellow "HP legacy drivers are Intel (x86_64) binaries and require Rosetta 2."
        print_yellow "If printing fails with a 'filter failed' error, install Rosetta via:"
        print_yellow "   softwareupdate --install-rosetta --agree-to-license"
        print_yellow "=========================================================="
    fi
fi

exit 0
