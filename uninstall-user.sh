#!/bin/sh
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
set -eu
UUID=ventilo@local
systemctl --user disable --now ventilo.service 2>/dev/null || true
rm -f "$HOME/.local/bin/ventilo" "$HOME/.config/systemd/user/ventilo.service"
rm -rf "$HOME/.local/share/gnome-shell/extensions/$UUID" "$HOME/.config/ventilo"
systemctl --user daemon-reload
python3 - "$UUID" <<'PY'
import ast, subprocess, sys
out = subprocess.run(["gsettings", "get", "org.gnome.shell", "enabled-extensions"],
                     capture_output=True, text=True, check=True).stdout
exts = [e for e in ast.literal_eval(out.replace("@as ", "").strip()) if e != sys.argv[1]]
subprocess.run(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(exts)], check=True)
PY
echo "Removed."
