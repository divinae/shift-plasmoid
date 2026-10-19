# Stand

A Plasma 6 widget that reminds you to switch between sitting and standing, and can move a
motorized desk for you.

- A sit/stand cycle with its own timer: 45 minutes sitting, 15 standing by default.
- A notification when it is time to switch, with **Sit/Stand now** and **Snooze**.
- Daily standing time against a goal, and a streak of days that met it.
- Paused while the screen is locked. Away 5 minutes or more starts the cycle over.

## Install

```sh
make install     # first time
make upgrade     # after changes
```

Then add **Stand** to a panel or the desktop.

## Desk control

Qt 6 has no QML API for Bluetooth, so the widget drives the desk through a command-line
tool. The defaults use [idasen](https://github.com/newAM/idasen), which works with IKEA
Idåsen and other Linak desks:

```sh
pipx install idasen
idasen init        # finds the desk and writes ~/.config/idasen/idasen.yaml
idasen height      # should print the height
```

Pair the desk in System Settings → Bluetooth first. The sit and stand heights for
`idasen sit` / `idasen stand` live in idasen's own config file.

Then, in the widget's settings, under **Desk**:

1. Turn on **Control a motorized desk**.
2. Press **Test connection**. It runs the height command and shows what it read.
3. Set the sitting and standing heights. Above their midpoint counts as standing.

Any other tool works too. The commands run with `sh`, and `{cm}`, `{mm}` and `{m}` are
replaced with the preset height, for example `linak-controller --move-to {mm}`. The height
command may print the height in metres, centimetres or millimetres.

The widget reads the height every minute, so moving the desk with its own buttons is
noticed too and the standing time stays right.

**Move the desk when it is time to switch** is off by default. A desk that moves on its
own can catch a chair arm, a cable or a shelf. Turn it on only if nothing can be caught.

## Limitations

- Away is the screen lock, not idle time. KDE's Wayland session answers
  `org.freedesktop.ScreenSaver.GetSessionIdleTime` with `NotSupported`. Plasma locks after
  its own idle timeout, so in practice this follows idleness too.
- Standing time is credited to the day it is saved on, once a minute, so at most a minute
  of a session that spans midnight lands on the wrong day.

## Development

```sh
make check       # qmllint, config and theme audits, qmltestrunner
```

The testable logic is plain JavaScript in `package/contents/ui/lib/`: `cycle.js` for the
cycle and stats, `desk.js` for building desk commands and reading their output.

To try changes without touching the installed copy:

```sh
XDG_DATA_HOME=/tmp/stand-test make install
XDG_DATA_HOME=/tmp/stand-test plasmawindowed com.dv.stand
```

QML errors show up in `journalctl --user -f`.

Several parts are taken from Fokus: `ExecUtil.qml`, `NotificationManager.qml`, `Sfx.qml`,
`ProgressCircle.qml`, `FormPathDelegate.qml`, the Makefile and the audits in `tests/`.
