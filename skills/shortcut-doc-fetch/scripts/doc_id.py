#!/usr/bin/env python3
"""Print the document UUID for a Shortcut doc URL, base64 doc ID, or bare UUID.

Shortcut doc URLs look like https://app.shortcut.com/<workspace>/write/<id>,
where <id> is base64 of '"Doc":#uuid "<uuid>"'. The documents API wants the
UUID, not the base64 segment (passing the segment returns 404).

Exit status 1, with a message on stderr, when no UUID can be found.
"""
import base64
import binascii
import re
import sys

UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)


def doc_uuid(text):
    match = UUID.search(text)
    if match:
        return match.group(0).lower()
    segment = re.sub(r"[?#].*", "", text.strip()).rstrip("/")
    segment = segment.split("/write/")[-1].split("/")[0]
    segment = segment.replace("%3D", "=").replace("%3d", "=")
    segment = segment.replace("-", "+").replace("_", "/").rstrip("=")
    try:
        decoded = base64.b64decode(segment + "=" * (-len(segment) % 4))
    except (binascii.Error, ValueError):
        return None
    match = UUID.search(decoded.decode("utf-8", "replace"))
    return match.group(0).lower() if match else None


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: doc_id.py <shortcut-doc-url | base64-id | uuid>")
    found = doc_uuid(sys.argv[1])
    if not found:
        sys.exit(f"no Shortcut document UUID found in: {sys.argv[1]}")
    print(found)
