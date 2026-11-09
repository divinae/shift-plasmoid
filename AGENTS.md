# Shift: notes for AI agents

Shift (formerly "Stand") is a KDE Plasma 6 widget that reminds you to switch between sitting
and standing (45/15 min by default), counts standing time against a daily goal with a streak
and a 7-day chart, and can drive a motorized desk through a command-line tool (default
[idasen](https://github.com/newAM/idasen) for IKEA Idåsen / Linak). Plugin Id `com.dv.stand`
(kept through the rename so installs keep settings and history), Name `Shift`, license
GPL-3.0-or-later, author Jakub Lipiński (GitHub `divinae`). Code at
https://github.com/divinae/shift-plasmoid (moved from GitLab), KDE Store
https://store.kde.org/p/2379558/. Push target: `origin`
(`git@github.com:divinae/shift-plasmoid.git`), branch `main`, committed directly. Pure
QML/JS, no compiled parts.

## Layout

- `package/metadata.json`: KPlugin metadata; `Version` is the single source of the version.
- `package/contents/config/main.xml`: kcfg, one `General` group (~24 entries).
  `config.qml`: two pages, `configGeneral.qml` and `configDesk.qml`.
- `package/contents/ui/main.qml` (~780 lines): the `PlasmoidItem`: cycle timer, reminders,
  lock/DND handling, working hours, pause, persistence, panel icon, popup.
- `package/contents/ui/lib/cycle.js` (cycle and stats) and `lib/desk.js` (building desk
  commands, parsing height output): plain JS, unit-tested. `lib/ExecUtil.qml` runs shell
  commands; `lib/Utils.js` helpers.
- `Desk.qml` (desk control, retries), `WeekChart.qml`, `ProgressCircle.qml`,
  `NotificationManager.qml`, `Sfx.qml`, `FormPathDelegate.qml`.
- `package/contents/icons/`: `person-sit.svg`, `person-stand.svg`, `arrow-next.svg`.
  `package/contents/screenshot.png`: the Add Widgets icon (generated, see below).
- `tests/`: `tst_cycle.qml`, `tst_desk.qml` (qmltestrunner), `config_audit.py`,
  `theme_audit.py`.
- `tools/icon/make_icon.py`: draws `package/contents/screenshot.png` and
  `screenshots/logo.png`. `tools/screenshot/{shoot.sh,config.py,crop.py}`: README
  screenshots in a headless KWin with sample data.
- `releases/*.plasmoid`: tracked release archives (`stand_v1.x` before the rename,
  `shift_v1.2.x` after). `.github/FUNDING.yml`: Ko-fi sponsor button.
- Untracked, not yours to touch: `docs/kde-store.md`, `shift_v*.plasmoid` in the root
  (gitignored via `/*.plasmoid`).

## Build, run, test

From the `Makefile`:

- `make check` = `lint` + `audit` + `test`.
- `make lint`: `/usr/lib/qt6/bin/qmllint --unqualified disable --missing-property disable`
  over `ui/*.qml` and `ui/lib/*.qml` (override with `QMLLINT=...`).
- `make test`: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests`.
- `make audit`: `python3 tests/config_audit.py` and `python3 tests/theme_audit.py` (run from
  the repo root).
- `make install` / `make upgrade` also run `make icons`, which copies the posture SVGs to
  `$XDG_DATA_HOME/icons/hicolor/scalable/apps/` as `com.dv.stand.svg`, `com.dv.stand-sit.svg`,
  `com.dv.stand-stand.svg` (Plasma looks a widget icon up by name; it cannot point into the
  package). `make uninstall` removes widget and icons.
- `make package` builds `shift_v<Version>.plasmoid`; `make release` also copies it into
  `releases/`; `make clean` deletes root `*.plasmoid`.

See a change live (only if the user asks): isolated try-out as in the README,
`XDG_DATA_HOME=/tmp/stand-test make install` then
`XDG_DATA_HOME=/tmp/stand-test plasmawindowed com.dv.stand`; errors in
`journalctl --user -f`. For the real panel: `make upgrade` then
`systemctl --user restart plasma-plasmashell`.
Screenshots: `tools/screenshot/shoot.sh STATE OUT.png` (`sit`, `due`, `stand`, optional
`-offline` suffix); needs `kwin_wayland`, `plasmawindowed`, `spectacle`, Python with Pillow.

## Conventions

- QML/JS as in Fokus: 4-space indent, semicolons, explanatory *why* comments. Testable logic
  goes into `lib/*.js` with tests in `tests/tst_*.qml`.
- Config: a new setting needs a `main.xml` entry plus a `cfg_<key>` on a config page and must
  pass `make audit`.
- i18n: user strings use `i18n()` / `i18np()`, but there is no `Messages.sh`, no `po/`, and no
  translation domain set up; the config page names in `config.qml` are not wrapped.
- No SPDX headers; license stated in `metadata.json` (`GPL-3.0-or-later`) and `LICENSE`.
- Versioning: semver. CHANGELOG has an `## Unreleased` section on top, then
  `## X.Y.Z — YYYY-MM-DD` with prose paragraphs, bold leads, and `### Fixed` lists.
  A release is one commit `Release X.Y.Z` touching `CHANGELOG.md`, `metadata.json`, the
  version in the README install snippet, and adding `releases/shift_vX.Y.Z.plasmoid`
  (`make release`); tagged `vX.Y.Z`. Tag the commit that contains the version bump: 1.2.2
  exists only because the `v1.2.1` tag pointed at the commit before it.
- Commit subjects: plain imperative sentences, capitalised, no prefixes ("Wait for
  confirmation before counting a manual switch", "Move the project to GitHub"); bodies
  explain why; `Co-Authored-By:` trailer when AI-assisted.

## Gotchas

- Do not change the plugin Id `com.dv.stand` or the `stand` naming of internal files/icons:
  the rename to Shift deliberately kept them so existing installs survive.
- Theme colours are read once in a palette block in `main.qml`; `tests/theme_audit.py`
  forbids per-delegate reads (a libplasma `PlasmaTheme::syncColors` segfault took
  plasmashell down in Fokus; same rule applied here).
- "Away" is the screen lock, not idle time: KDE's Wayland session answers
  `org.freedesktop.ScreenSaver.GetSessionIdleTime` with `NotSupported`. Away 5+ minutes
  restarts the cycle; turning the lock check off mid-absence must not leave it paused.
- Standing time is flushed to config once a minute (not every second), so a crash or a
  midnight crossing loses / misattributes at most a minute. Stored state saved in the future
  or too long ago is discarded.
- Desk: Qt 6 has no QML Bluetooth API, so everything goes through `sh` commands with
  `{cm}`/`{mm}`/`{m}` placeholders; height output may be in m, cm or mm. Height is polled
  every minute. A short move is retried up to 8 times; two non-moves stop retries
  (anti-collision). An unreachable desk is shown, not raised as an error; a requested switch
  then waits for the user's Done. "Move the desk when it is time to switch" is off by
  default for safety; keep it so.
- The popup cannot show height while moving (idasen holds the only BLE connection).
- `tools/screenshot/shoot.sh` runs without window-manager scripts on purpose (a tiling
  script would resize the window).

## Related

- Parts are taken from Fokus (`../focus-plasmoid`) per the README:
  `ExecUtil.qml`, `NotificationManager.qml`, `Sfx.qml`, `ProgressCircle.qml`,
  `FormPathDelegate.qml`, the Makefile and the `tests/` audits. They are copies, not shared
  files: `ProgressCircle.qml` and `FormPathDelegate.qml` are currently identical,
  `ExecUtil.qml`, `Sfx.qml` and `NotificationManager.qml` have diverged.
- Glance (`../glance-plasmoid`) contains a copy of Shift in
  `package/contents/ui/stand/` (imported 2026-11-03, Glance commit `7283f48`): `cycle.js`,
  `desk.js`, `Desk.qml`, `WeekChart.qml`, icons, with `main.qml` split into
  `StandController.qml` + `StandView.qml` and settings as Glance's `stand_*` keys. No sync
  mechanism; the copies have diverged (Glance's `cycle.js` gained weekend handling,
  `isWeekend`/`weekendsOff`). This repo is the source of truth for the standalone widget
  only; fixes must be ported by hand in either direction.
