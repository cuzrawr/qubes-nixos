"""Resolve literal paths in installed upstream text files."""

import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
replacements = json.loads(Path(sys.argv[2]).read_text())
# References to this package's own installed files use its immutable store
# output. Explicit mappings (notably privileged wrappers) take precedence.
for directory in ("bin", "sbin", "lib/qubes", "share/qubes"):
    for path in (root / directory).rglob("*"):
        if path.is_file():
            replacements.setdefault("/usr/" + str(path.relative_to(root)), str(path))
counts = dict.fromkeys(replacements, 0)
patterns = [
    # A leading '-' is also systemd's ExecStart ignore-failure prefix.
    (old, re.compile(r"(?<![\w/.])" + re.escape(old) + r"(?![\w.-])"), new)
    for old, new in sorted(replacements.items(), key=lambda item: -len(item[0]))
]
for path in sorted(root.rglob("*")):
    if path.is_symlink() or not path.is_file():
        continue
    data = path.read_bytes()
    if b"\0" in data:
        continue
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        continue
    original = text
    for old, pattern, replacement in patterns:
        text, count = pattern.subn(lambda _: replacement, text)
        counts[old] += count
    if text != original:
        mode = path.stat().st_mode
        path.chmod(mode | 0o200)
        try:
            path.write_text(text)
        finally:
            path.chmod(mode)
report = root / "share/qubes-nixos" / (root.name.split("-", 1)[-1] + "-paths.json")
report.parent.mkdir(parents=True, exist_ok=True)
report.write_text(json.dumps({key: count for key, count in counts.items() if count}, indent=2) + "\n")
