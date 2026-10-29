#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C O N T R O L   E X T R A S                                            │
# │   control centre · image search and song recognition                     │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""The two control centre tiles that call outside tools.

`tools` reports which of them are installed; the shell lists a tile only when
its tools exist. `lens` selects a region, uploads it to uguu.se (temporary
public hosting) and opens Google Lens on the address; `music` listens to what
the speakers play and names the song. Both end in a notification, success or
not. Nothing is uploaded unless the shell started `lens`, which it does only
with the `lensUpload` setting on.
"""

import json
import shutil
import subprocess
import sys
import threading
import time
from urllib.parse import quote

UPLOAD_ADDRESS = "https://uguu.se/upload"
LENS_ADDRESS = "https://lens.google.com/uploadbyurl?url="

# How long `music` listens before giving up.
LISTEN_SECONDS = 30

TOOLS = ("grim", "slurp", "curl", "songrec")


def notify(title, body="", urgency="normal"):
    """Through the shell's own notification daemon, so it lands on the island."""
    subprocess.run(["notify-send", "-u", urgency, title, body],
                   stdin=subprocess.DEVNULL, check=False)


def run(command, **kwargs):
    """Run a tool with stdin closed unless it is given input.

    Children inherit a pipe from the shell, and a tool that reads stdin when it
    is not a terminal (slurp, for one) would block on it forever.
    """
    if "input" not in kwargs:
        kwargs.setdefault("stdin", subprocess.DEVNULL)
    try:
        return subprocess.run(command, capture_output=True, timeout=120, **kwargs)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"{command[0]} failed: {error}", file=sys.stderr)
        return None


def tools():
    print(json.dumps({name: bool(shutil.which(name)) for name in TOOLS}))


def lens(wait_s):
    # The control centre is closing; the selection must not catch it.
    time.sleep(wait_s)
    selection = run(["slurp"], text=True)
    if selection is None or selection.returncode != 0 or not selection.stdout.strip():
        return  # cancelled with Escape
    shot = run(["grim", "-g", selection.stdout.strip(), "-"])
    if shot is None or shot.returncode != 0 or not shot.stdout:
        notify("Lens", "The region could not be captured", "critical")
        return
    upload = run(["curl", "-sF", "files[]=@-;filename=lens.png", UPLOAD_ADDRESS],
                 input=shot.stdout)
    try:
        address = json.loads(upload.stdout)["files"][0]["url"]
        if not address.startswith("https://"):
            raise ValueError(address)
    except (AttributeError, ValueError, KeyError, IndexError, TypeError):
        notify("Lens", "The upload did not work", "critical")
        return
    run(["xdg-open", LENS_ADDRESS + quote(address, safe="")])


def monitor_source():
    """The default sink's monitor source: what the machine plays, not the microphone."""
    if not shutil.which("pactl"):
        return ""
    result = run(["pactl", "get-default-sink"], text=True)
    if result is None or result.returncode != 0 or not result.stdout.strip():
        return ""
    return result.stdout.strip() + ".monitor"


def music():
    source = monitor_source()
    if not source:
        notify("Song recognition", "There is no output to listen to", "critical")
        return
    notify("Listening…", "Recognising the song that is playing")
    listener = subprocess.Popen(
        ["songrec", "listen", "--audio-device", source, "--request-interval", "2",
         "--json", "--disable-mpris"],
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, text=True)
    # A silent room prints nothing, so a read loop alone would never end.
    limit = threading.Timer(LISTEN_SECONDS, listener.kill)
    limit.start()
    found = None
    try:
        for line in listener.stdout:
            try:
                track = json.loads(line).get("track")
            except (ValueError, AttributeError):
                continue
            if isinstance(track, dict) and track.get("title"):
                found = track
                break
    finally:
        limit.cancel()
        listener.kill()
        listener.wait()
    if found is None:
        notify("Song recognition", "No song recognised")
        return
    notify("Song recognised", " — ".join(filter(None, [found["title"], found.get("subtitle")])))


def main():
    arguments = sys.argv[1:]
    action = arguments[0] if arguments else "tools"
    if action == "tools":
        tools()
    elif action == "lens":
        wait_s = float(arguments[2]) if len(arguments) > 2 and arguments[1] == "--wait" else 0.0
        lens(wait_s)
    elif action == "music":
        music()
    else:
        print("usage: control_extras.py [tools | lens [--wait SECONDS] | music]",
              file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
