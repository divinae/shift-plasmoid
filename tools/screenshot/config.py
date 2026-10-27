"""Writes plasmawindowedrc for a screenshot: a week of sample history and a cycle state."""
import datetime
import json
import sys
import time

config_dir, state = sys.argv[1], sys.argv[2]
position_state = state.split("-")[0]
offline = state.endswith("-offline")

today = datetime.date.today()
minutes = [95, 130, 125, 40, 0, 135, 70]
history = {(today - datetime.timedelta(days=6 - i)).isoformat(): m for i, m in enumerate(minutes)}

# Saved a second ago: the widget throws away a state saved in the future or too long ago.
now = int(time.time() * 1000) - 1000
MIN = 60000
cycle = {
    "sit": {"position": "sit", "elapsedMs": 28 * MIN, "dueSinceMs": 0},
    "due": {"position": "sit", "elapsedMs": 47 * MIN, "dueSinceMs": now - 2 * MIN},
    "stand": {"position": "stand", "elapsedMs": 6 * MIN, "dueSinceMs": 0},
}[position_state]
cycle.update({"snoozeUntil": 0, "awaySinceMs": 0, "pausedUntilMs": 0, "savedAt": now})

if offline:
    height_cmd = "sh -c 'echo Failed to connect >&2; exit 1'"
else:
    height_cmd = "echo %s meters" % ("1.08" if cycle["position"] == "stand" else "0.67")

with open(config_dir + "/plasmawindowedrc", "w") as f:
    f.write(f"""[Applets][1]
immutability=1
plugin=com.dv.stand

[Applets][1][Configuration]
geometry=0,0,420,760

[Applets][1][Configuration][General]
stand_history={json.dumps(history, separators=(",", ":"))}
cycle_state={json.dumps(cycle, separators=(",", ":"))}
desk_enabled=true
desk_height_cmd={height_cmd}
desk_sit_cmd=true
desk_stand_cmd=true
sit_height_cm=67
stand_height_cm=108
""")
