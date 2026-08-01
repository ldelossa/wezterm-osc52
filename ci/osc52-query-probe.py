#!/usr/bin/env python3
"""Query OSC 52 from inside a terminal and write a machine-readable result."""

import base64
import os
import re
import select
import sys
import termios
import time
import tty

output_path = os.environ["OSC52_PROBE_OUTPUT"]
startup_delay = float(os.environ.get("OSC52_PROBE_STARTUP_DELAY", "0.75"))
timeout = float(os.environ.get("OSC52_PROBE_TIMEOUT", "5"))

fd = sys.stdin.fileno()
old = termios.tcgetattr(fd)
response = bytearray()
time.sleep(startup_delay)
try:
    tty.setraw(fd)
    os.write(sys.stdout.fileno(), b"\x1b]52;c;?\x1b\\")
    deadline = time.monotonic() + timeout
    while b"\x1b\\" not in response and time.monotonic() < deadline:
        readable, _, _ = select.select([fd], [], [], max(0, deadline - time.monotonic()))
        if not readable:
            break
        response.extend(os.read(fd, 4096))
finally:
    termios.tcsetattr(fd, termios.TCSADRAIN, old)

match = re.search(rb"\x1b\]52;c;([^\x1b]*)\x1b\\", response)
if not match:
    result = f"ERROR:no OSC52 response:{response!r}\n"
    status = 1
else:
    try:
        decoded = base64.b64decode(match.group(1), validate=True).decode("utf-8")
        result = f"OK:{decoded}\n"
        status = 0
    except Exception as exc:
        result = f"ERROR:invalid OSC52 response:{exc}:{response!r}\n"
        status = 1

with open(output_path, "w", encoding="utf-8") as output:
    output.write(result)
sys.exit(status)
