# Changelog

## 1.1.0 — 2026-10-21

A desk that does not answer no longer gets in the way, and the panel says more plainly when
it is time to switch.

**Working without the desk** when it is off, out of range or asleep. A height read that
fails no longer raises an error. The popup says the desk is not reachable, and until it
answers again, Sit and Stand record where you are as if there were no desk: a move the desk
never got counts as done, on the assumption you used its own buttons. **Try again** checks
at once, and the minute-by-minute read switches back on its own. A desk that answers but
stops short of the preset still notifies, since something may be in its way.

**A clear arrow when a switch is due.** The panel used to show a small amber badge with a
thin arrow in the corner, hard to make out at panel size and covering half the figure. Now
the figure gives way to a thick arrow, up or down, inside the amber ring.

**Middle-click the panel icon** to switch between sitting and standing without opening the
popup.

### Fixed

- A desk move that stops short is retried after half a second instead of three. Each
  idasen command already spends about six seconds connecting over Bluetooth, so a retry
  still takes a few seconds before the desk moves again.

## 1.0.0 — 2026-10-19

The first release. Stand is a Plasma 6 widget that keeps you switching between sitting and
standing, and can move a motorized desk to match.

**A sit/stand cycle.** 45 minutes sitting and 15 standing by default, with a notification
when it is time to switch: **Stand now** or **Snooze**. The panel shows a sitting or
standing figure inside a ring that fills toward the next switch. When a switch is due, the
ring turns amber and a small arrow shows which way to go.

**The desk moves for you.** The Sit and Stand buttons drive the desk through a command-line
tool, [idasen](https://github.com/newAM/idasen) by default (IKEA Idåsen and other Linak
desks). A move that stops short, which Linak desks do now and then, is sent again until the
desk gets there, up to 8 times. Two moves in a row that go nowhere stop the retries: the
desk may be stopping on something in its way. **Use current height** in the settings saves
the desk's height as the sitting or standing preset, both in the widget and in idasen. The
widget also reads the height every minute, so moving the desk with its own buttons counts.

**Standing time.** Today against a daily goal, a streak of days that met it, and the last
seven days as a chart.

**It stays out of the way.** **Pause** for a meeting, for a set time or until you resume.
Optional working hours stop the cycle in the evenings and at weekends, and each working
day starts fresh. Reminders wait while Do Not Disturb is on, and the cycle pauses while the
screen is locked.
