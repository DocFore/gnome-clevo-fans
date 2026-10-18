// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';

import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// Same files as the ventilo daemon
const STATE_FILE = GLib.build_filenamev([GLib.get_user_config_dir(), 'ventilo', 'state.json']);
const STATUS_FILE = GLib.build_filenamev([GLib.get_user_runtime_dir(), 'ventilo', 'status.json']);
const MODES = [
    ['silent', 'Silent'],
    ['auto', 'Automatic'],
    ['max', 'Maximum'],
];
const DEFAULT_MODE = 'auto';
const STALE_SECONDS = 10;

// --- Translations (English is the source language) ---------------------------

const FRENCH = {
    'Silent': 'Silencieux',
    'Automatic': 'Automatique',
    'Maximum': 'Maximal',
    'Fans': 'Ventilateurs',
    'Fan mode': 'Mode des ventilateurs',
    'Open fan menu': 'Ouvrir le menu des ventilateurs',
    'Daemon stopped': 'Service arrêté',
    'Silent mode paused: temperature too high': 'Mode silencieux suspendu : température trop élevée',
};

const TRANSLATIONS = GLib.get_language_names()[0].startsWith('fr') ? FRENCH : {};

function _(text) {
    return TRANSLATIONS[text] ?? text;
}

// --- Files shared with the daemon -------------------------------------------

function readJson(path) {
    try {
        const [, bytes] = GLib.file_get_contents(path);
        return JSON.parse(new TextDecoder().decode(bytes));
    } catch {
        return null;
    }
}

function loadMode() {
    const mode = readJson(STATE_FILE)?.mode;
    return MODES.some(([id]) => id === mode) ? mode : DEFAULT_MODE;
}

function saveMode(mode) {
    GLib.mkdir_with_parents(GLib.path_get_dirname(STATE_FILE), 0o755);
    GLib.file_set_contents(STATE_FILE, JSON.stringify({mode}, null, 2));
}

function monitor(path, callback) {
    GLib.mkdir_with_parents(GLib.path_get_dirname(path), 0o755);
    const m = Gio.File.new_for_path(path).monitor_file(Gio.FileMonitorFlags.WATCH_MOVES, null);
    m.connect('changed', callback);
    return m;
}

// --- User interface ---------------------------------------------------------

const FanToggle = GObject.registerClass(
class FanToggle extends QuickMenuToggle {
    constructor() {
        super({
            title: _('Fans'),
            iconName: 'weather-windy-symbolic',
            toggleMode: false,
            menuButtonAccessibleName: _('Open fan menu'),
        });
        this._mode = loadMode();
        this._lastFixedMode = this._mode === 'auto' ? 'silent' : this._mode;

        this.menu.setHeader('weather-windy-symbolic', _('Fans'), _('Fan mode'));

        this._items = new Map();
        for (const [id, label] of MODES) {
            const item = new PopupMenu.PopupMenuItem(_(label));
            item.connect('activate', () => this._select(id));
            this.menu.addMenuItem(item);
            this._items.set(id, item);
        }

        // The tile switches between automatic and the last fixed mode
        this.connect('clicked', () => this._select(this._mode === 'auto' ? this._lastFixedMode : 'auto'));

        this._monitors = [
            monitor(STATE_FILE, () => {
                this._mode = loadMode();
                this._sync();
            }),
            monitor(STATUS_FILE, () => this._sync()),
        ];
        this._sync();
    }

    _select(mode) {
        this._mode = mode;
        if (mode !== 'auto')
            this._lastFixedMode = mode;
        saveMode(mode);
        this._sync();
    }

    _sync() {
        const status = readJson(STATUS_FILE);
        const alive = status && GLib.get_real_time() / 1e6 - status.time < STALE_SECONDS;

        this.checked = this._mode !== 'auto';
        const label = _(MODES.find(([id]) => id === this._mode)[1]);
        this.subtitle = alive ? `${label} · ${Math.max(...status.duty)} %` : `${label} · ${_('Daemon stopped')}`;

        for (const [id, item] of this._items)
            item.setOrnament(id === this._mode ? PopupMenu.Ornament.DOT : PopupMenu.Ornament.NONE);

        if (alive) {
            const note = status.released ? ` — ${_('Silent mode paused: temperature too high')}` : '';
            this.menu.setHeader('weather-windy-symbolic', _('Fans'),
                `CPU ${status.cpu} °C · GPU ${status.gpu ?? '—'} °C${note}`);
        }
    }

    destroy() {
        this._monitors?.forEach(m => m.cancel());
        this._monitors = null;
        super.destroy();
    }
});

const Indicator = GObject.registerClass(
class Indicator extends SystemIndicator {
    constructor() {
        super();
        this.quickSettingsItems.push(new FanToggle());
    }

    destroy() {
        this.quickSettingsItems.forEach(item => item.destroy());
        super.destroy();
    }
});

export default class VentiloExtension extends Extension {
    enable() {
        this._indicator = new Indicator();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
