# Changelog

## 1.2.2 — 2026-10-30

The same as 1.2.1, released again because the `v1.2.1` tag points at a commit from before
that version's number was set. Install this one.

## 1.2.1 — 2026-10-30

**Stand is now Shift.** With "Stand" as the title, a notification saying "Time to sit down"
read like a contradiction. Only the name changes: the widget keeps its id, so it stays in
your panel with its settings and history.

### Fixed

- Every notification showed an up arrow, including "Time to sit down". The icon now
  follows the message: a down arrow for sitting down, an up arrow for standing up, and a
  warning sign when the desk could not be moved.

## 1.2.0 — 2026-10-28

A desk that does not answer is now plain to see, and a switch made by hand only counts
once you say it is done.

**Switches wait for your Done while the desk is out of reach.** In 1.1.0 a move the desk
never got counted as made, on the assumption you used the desk's own buttons. Now it waits:
the arrow shows in the ring, a notification asks you to raise or lower the desk by hand and
press **Done**, and the time keeps counting in the old position until you do. Confirm with
**Done** in the notification or the popup, or with another middle click on the panel icon.
While the desk is out of reach, the popup's buttons read **I'm sitting** and **I'm
standing**, and pressing one is the confirmation. The next height the desk reports settles
any switch still waiting.

**An unplugged plug on the panel icon** while the desk is out of reach, in the ring's bottom
corner, outlined so it stands clear of the figure. The tooltip says so too.

### Fixed

- The popup could reopen with empty space below its contents, at a height Plasma had saved
  before 1.1.0. It is now as tall as what it shows.

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
