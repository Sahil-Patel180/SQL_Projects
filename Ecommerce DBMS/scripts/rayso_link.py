#!/usr/bin/env python3
"""
rayso_link.py — turn any file (or a line range of it) into a
https://ray.so/ share URL, so a query/proc/trigger/view can be
turned into a shareable code snippet image without hand-copying
into the ray.so editor.

ray.so reads its state from the URL hash:
  https://ray.so/#title=<urlencoded>&theme=<name>&language=<lang>
                 &padding=<16|32|64|128>&background=<bool>
                 &darkMode=<bool>&code=<base64 of the code>

Usage:
    python3 rayso_link.py <file> [start_line] [end_line]
    python3 rayso_link.py sql/09_triggers.sql 34 63
    python3 rayso_link.py sql/05_queries.sql          # whole file

Options (edit the constants below if you want a different theme):
    THEME    one of: breeze, candy, crimson, falcon, meadow,
              midnight, raindrop, sunset
    PADDING  16, 32, 64 or 128
"""
import base64
import sys
import urllib.parse

THEME = "midnight"
PADDING = 32
LANGUAGE = "sql"


def build_url(code: str, title: str) -> str:
    encoded_code = base64.b64encode(code.encode("utf-8")).decode("ascii")
    encoded_code = urllib.parse.quote(encoded_code, safe="")
    encoded_title = urllib.parse.quote(title, safe="")
    return (
        "https://ray.so/#background=true&darkMode=true"
        f"&padding={PADDING}&theme={THEME}&language={LANGUAGE}"
        f"&title={encoded_title}&code={encoded_code}"
    )


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    path = sys.argv[1]
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    if len(sys.argv) >= 4:
        start, end = int(sys.argv[2]), int(sys.argv[3])
        code = "".join(lines[start - 1:end])
        title = f"{path.split('/')[-1]} (L{start}-{end})"
    else:
        code = "".join(lines)
        title = path.split("/")[-1]

    print(build_url(code, title))


if __name__ == "__main__":
    main()
