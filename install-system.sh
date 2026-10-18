#!/bin/sh
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# System part: adds the tuxedo_io module to the rgb-keyboard-clevo DKMS package,
# loads it at boot, gives the session user access to /dev/tuxedo_io.
# Usage: sudo ./install-system.sh
set -eu
trap 'status=$?; [ "$status" -eq 0 ] || echo "Installation failed (exit code $status)." >&2' EXIT

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo: sudo $0" >&2
	exit 1
fi

HERE=$(cd "$(dirname "$0")" && pwd)
PKG=rgb-keyboard-clevo/1.0
SRC=/usr/src/rgb-keyboard-clevo-1.0
MODULES="tuxedo_io clevo_acpi clevo_wmi tuxedo_keyboard tuxedo_compatibility_check"

if [ ! -f "$SRC/dkms.conf" ]; then
	echo "The DKMS package $PKG is missing: install the keyboard driver first" >&2
	echo "(install-system.sh of the rgb-keyboard-clevo project)." >&2
	exit 1
fi

BACKUP=$(mktemp -d)
cp "$SRC/dkms.conf" "$BACKUP/dkms.conf"
cp "$SRC/src/Kbuild" "$BACKUP/Kbuild"

restore() {
	echo "Restoring the previous driver package." >&2
	cp "$BACKUP/dkms.conf" "$SRC/dkms.conf"
	cp "$BACKUP/Kbuild" "$SRC/src/Kbuild"
	rm -rf "$SRC/src/tuxedo_io"
	dkms remove "$PKG" --all >/dev/null 2>&1 || true
	dkms install "$PKG" >/dev/null 2>&1 || true
	modprobe clevo_wmi 2>/dev/null || true
}

# 1. Add the module to the sources and to the DKMS configuration (idempotent)
rm -rf "$SRC/src/tuxedo_io"
cp -r "$HERE/driver/tuxedo_io" "$SRC/src/tuxedo_io"
grep -q 'tuxedo_io' "$SRC/src/Kbuild" || echo 'obj-m += tuxedo_io/' >> "$SRC/src/Kbuild"
if ! grep -q 'BUILT_MODULE_NAME.*"tuxedo_io"' "$SRC/dkms.conf"; then
	# Insert before AUTOINSTALL, with the next free index
	N=$(grep -c '^BUILT_MODULE_NAME' "$SRC/dkms.conf")
	sed -i "/^AUTOINSTALL/i BUILT_MODULE_NAME[$N]=\"tuxedo_io\"\nBUILT_MODULE_LOCATION[$N]=\"src/tuxedo_io/\"\nDEST_MODULE_LOCATION[$N]=\"/updates/dkms\"\n" "$SRC/dkms.conf"
fi

# 2. Rebuild everything (restores the keyboard driver if it fails)
dkms remove "$PKG" --all >/dev/null 2>&1 || true
if ! dkms install "$PKG"; then
	restore
	exit 1
fi

# 3. Boot loading and permissions
echo tuxedo_io > /etc/modules-load.d/ventilo.conf
rm -f /etc/udev/rules.d/90-ventilo.rules
install -m 0644 "$HERE/udev/70-ventilo.rules" /etc/udev/rules.d/70-ventilo.rules
udevadm control --reload

# 4. Reload the new copies
for m in $MODULES; do
	rmmod "$m" 2>/dev/null || true
done
modprobe clevo_wmi
if ! modprobe tuxedo_io; then
	echo "tuxedo_io did not load ('sudo dmesg | tail')." >&2
	exit 1
fi
udevadm trigger --subsystem-match=tuxedo_io --action=add
udevadm settle
rm -rf "$BACKUP"

ls -l /dev/tuxedo_io
getfacl /dev/tuxedo_io 2>/dev/null | grep -q user: || echo "Note: access is granted to the active session only (uaccess)."
echo "OK. Now run ./install-user.sh (without sudo)."
