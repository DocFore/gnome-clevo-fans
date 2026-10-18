#!/bin/sh
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# User part (no sudo): daemon, systemd service, GNOME extension.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
UUID=ventilo@local
BIN=$HOME/.local/bin
EXTS=$HOME/.local/share/gnome-shell/extensions
UNITS=$HOME/.config/systemd/user

mkdir -p "$BIN" "$EXTS/$UUID" "$UNITS"

install -m 0755 "$HERE/ventilo" "$BIN/ventilo"
install -m 0644 "$HERE/systemd/ventilo.service" "$UNITS/ventilo.service"
install -m 0644 "$HERE/extension/$UUID/metadata.json" "$HERE/extension/$UUID/extension.js" "$EXTS/$UUID/"

systemctl --user daemon-reload
systemctl --user enable ventilo.service
systemctl --user restart ventilo.service

python3 - "$UUID" <<'PY'
import ast, subprocess, sys
uuid = sys.argv[1]
out = subprocess.run(["gsettings", "get", "org.gnome.shell", "enabled-extensions"],
                     capture_output=True, text=True, check=True).stdout
exts = ast.literal_eval(out.replace("@as ", "").strip())
if uuid not in exts:
    exts.append(uuid)
    subprocess.run(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(exts)], check=True)
PY

echo "Installed. Log out and back in to load the extension (Wayland)."
