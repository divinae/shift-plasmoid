#!/bin/sh
# Screenshots of the popup for the README, taken in a headless KWin of its own: no other
# windows, no window-manager scripts (a tiling script resizes the window), stock Breeze,
# English, and sample history.
#
#   tools/screenshot/shoot.sh STATE OUT.png
#
# STATE is sit, due, stand, or one of them with "-offline" (the desk does not answer).
# Needs kwin_wayland, plasmawindowed, spectacle and python3 with Pillow.
set -e
HERE=$(dirname "$(readlink -f "$0")")
ROOT=$(readlink -f "$HERE/../..")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/config" "$WORK/data"

XDG_DATA_HOME="$WORK/data" kpackagetool6 -t Plasma/Applet -i "$ROOT/package" >/dev/null
python3 -I "$HERE/config.py" "$WORK/config" "$1"

cat > "$WORK/inner.sh" <<INNER
#!/bin/sh
XDG_DATA_HOME="$WORK/data" LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US plasmawindowed com.dv.stand >"$WORK/widget.log" 2>&1 &
sleep 8
spectacle -b -n -f -o "$WORK/full.png"
sleep 1.5
INNER
chmod +x "$WORK/inner.sh"

XDG_CONFIG_HOME="$WORK/config" dbus-run-session -- kwin_wayland --virtual --width 900 --height 900 \
    --socket stand-shot --exit-with-session "$WORK/inner.sh" >"$WORK/kwin.log" 2>&1
grep -iE "error|warning" "$WORK/widget.log" >&2 || true
python3 -I "$HERE/crop.py" "$WORK/full.png" "$2" 14
