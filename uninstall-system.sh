#!/bin/sh
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Removes tuxedo_io only; the keyboard driver stays installed.
# Usage: sudo ./uninstall-system.sh
set -eu
trap 'status=$?; [ "$status" -eq 0 ] || echo "Uninstallation failed (exit code $status)." >&2' EXIT

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo: sudo $0" >&2
	exit 1
fi

PKG=rgb-keyboard-clevo/1.0
SRC=/usr/src/rgb-keyboard-clevo-1.0

rmmod tuxedo_io 2>/dev/null || true
rm -f /etc/udev/rules.d/90-ventilo.rules /etc/modules-load.d/ventilo.conf /etc/udev/rules.d/70-ventilo.rules
udevadm control --reload

if [ -f "$SRC/dkms.conf" ] && grep -q tuxedo_io "$SRC/dkms.conf"; then
	# Drop the tuxedo_io block (name, location, destination, blank line) and its Kbuild line
	sed -i '/^BUILT_MODULE_NAME\[[0-9]*\]="tuxedo_io"/,+3d' "$SRC/dkms.conf"
	sed -i '/tuxedo_io/d' "$SRC/src/Kbuild"
	rm -rf "$SRC/src/tuxedo_io"
	dkms remove "$PKG" --all >/dev/null 2>&1 || true
	dkms install "$PKG"
	modprobe clevo_wmi
fi
echo "tuxedo_io removed."
