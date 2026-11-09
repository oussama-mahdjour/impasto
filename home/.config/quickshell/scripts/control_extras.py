#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C O N T R O L   E X T R A S                                            │
# │   control centre · image search                                          │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""The control centre tile that calls outside tools.

`tools` reports which of them are installed; the shell lists the tile only
when its tools exist. `lens` selects a region, uploads it to uguu.se
(temporary public hosting) and opens Google Lens on the address; it ends in a
notification when it fails. Nothing is uploaded unless the shell started
`lens`, which it does only with the `lensUpload` setting on. The Song tile is
`song.py`'s.
"""

import json
import shutil
import subprocess
import sys
import time
from urllib.parse import quote

UPLOAD_ADDRESS = "https://uguu.se/upload"
LENS_ADDRESS = "https://lens.google.com/uploadbyurl?url="

TOOLS = ("grim", "slurp", "curl")


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


def main():
    arguments = sys.argv[1:]
    action = arguments[0] if arguments else "tools"
    if action == "tools":
        tools()
    elif action == "lens":
        wait_s = float(arguments[2]) if len(arguments) > 2 and arguments[1] == "--wait" else 0.0
        lens(wait_s)
    else:
        print("usage: control_extras.py [tools | lens [--wait SECONDS]]",
              file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
