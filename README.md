# ventilo — fan modes for Clevo-based laptops

A small tool with a **"Fans"** tile in GNOME Quick Settings (the top-right menu
next to Wi-Fi and Bluetooth) offering three modes: **Silent**, **Automatic**
and **Maximum**.

Tested on a Gigabyte AORUS 5 KB (Clevo chassis, two fans: CPU and GPU), Ubuntu
with kernel 7.0 and GNOME Shell 50. It complements
[rgb-keyboard-clevo](https://github.com/DocFore/rgb-keyboard-clevo) and reuses its DKMS package. Other Clevo
laptops exposing the Clevo WMI interface (`ABBC0F6D-8EA1-11D1-00A0-C90629100000`
in `/sys/bus/wmi/devices/`) should work too.

| Component | Purpose |
|---|---|
| `driver/tuxedo_io/` | `tuxedo_io` kernel module from [tuxedo-drivers](https://github.com/tuxedocomputers/tuxedo-drivers) (GPL, commit in `driver/UPSTREAM_COMMIT`). Exposes `/dev/tuxedo_io` (fan read/write through the Clevo WMI interface). |
| `udev/70-ventilo.rules` | Gives the logged-in user access to `/dev/tuxedo_io` (`uaccess`). |
| `ventilo` | Python daemon (`systemd --user` service) and command-line tool. |
| `systemd/ventilo.service` | Starts the daemon at login. |
| `extension/ventilo@local/` | GNOME Shell 50 extension (the Quick Settings tile). |

## Modes

- **Automatic**: the firmware drives the fans (original behavior).
- **Maximum**: both fans at 100 %.
- **Silent**: a quieter curve than the firmware's, in steps with hysteresis:
  fans off below 60 °C, then 30 % (≥ 60 °C), 45 % (≥ 70 °C), 60 % (≥ 78 °C).
  **Safety net**: if the CPU reaches 84 °C or the GPU 80 °C, the daemon hands the
  fans back to the firmware (automatic) until the temperature drops by 8 °C, and
  the tile says so. The steps are the constants at the top of the `ventilo` file.

Temperatures: CPU from `coretemp` (sysfs), GPU from the embedded controller's
sensor (same value as `nvidia-smi`, without waking the GPU). A GPU reading
of 1 °C or less means the GPU is off and is ignored by the curve.

## Requirements

- The keyboard driver installed (see [rgb-keyboard-clevo](https://github.com/DocFore/rgb-keyboard-clevo)),
  `dkms` and kernel headers (`linux-headers-$(uname -r)`).
- GNOME Shell 50 and `systemd --user`.
- Secure Boot: same rules as the keyboard driver (the MOK key must be enrolled).

## Installation

```sh
sudo ./install-system.sh   # adds tuxedo_io to the DKMS package, udev rule, load at boot
./install-user.sh          # daemon, systemd service, GNOME extension
```

Then **log out and back in** so GNOME loads the extension (Wayland).

## Usage

- **Quick Settings** (top right): the "Fans" tile shows the current mode and fan
  speed; the arrow opens the menu with the three modes and the CPU/GPU
  temperatures. Clicking the tile itself switches between Automatic and the
  last fixed mode (Silent by default), so one click can stop the fans.
- **Command line**:

  ```sh
  ventilo mode silent|auto|max   # the extension follows
  ventilo --auto                 # give the fans back to the firmware
  ```

The chosen mode is saved to `~/.config/ventilo/state.json`; the daemon publishes
its status (mode, fan speed, temperatures) in `$XDG_RUNTIME_DIR/ventilo/status.json`.

## Good to know

- When the daemon stops normally (shutdown, logout, `systemctl stop`, Ctrl-C),
  the fans go back to automatic. A `kill -9` or a hard crash leaves the last
  fixed setting in place until the daemon restarts.
- Running the keyboard project's `install-system.sh` again **removes**
  `tuxedo_io` from the DKMS package: run ventilo's afterwards.
- `/dev/tuxedo_io` also gives access to the webcam, touchpad and performance
  profile switches; access is limited to the active session.
- After a suspend, the daemon rewrites the mode within 30 s.
- If silent mode makes the fans "pump" (repeated on/off around 55–60 °C), raise
  `HYSTERESIS` or start the curve at 25 % (`DUTIES`) in `ventilo`.

## Language

The interface (Quick Settings tile and command-line messages) follows the
system language: **French** when it is French (`LANGUAGE`, `LC_ALL`,
`LC_MESSAGES` or `LANG` starting with `fr`), **English** otherwise. In French,
the tile is called "Ventilateurs" and the modes "Silencieux", "Automatique"
and "Maximal". To add a language, add a dictionary next to `FRENCH` in `ventilo`
and `extension.js`.

## Uninstallation

```sh
./uninstall-user.sh
sudo ./uninstall-system.sh   # removes tuxedo_io only; the keyboard driver stays
```

## License

- Everything except `driver/`: [PolyForm Noncommercial 1.0.0](LICENSE.md).
  Free to use, modify and share for any **noncommercial** purpose; commercial
  use is not permitted.
- `driver/`: GNU GPL v2 or later (see `driver/LICENSE`), as published by
  TUXEDO Computers. That code keeps its original license.

## Trademarks

This project is not affiliated with or endorsed by Clevo Co., Gigabyte
Technology or TUXEDO Computers. Clevo, AORUS and TUXEDO are trademarks of
their respective owners and are used here only to describe compatible
hardware and the origin of the driver code.
