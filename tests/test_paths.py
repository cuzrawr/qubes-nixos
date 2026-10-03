"""Guard the packaging substitutions against changing unrelated content."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

relocator = str(Path(sys.argv.pop(1)).resolve())


class PathAdaptationTests(unittest.TestCase):
    def test_dependencies_and_wrappers_take_precedence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "hash-test-package"
            (root / "bin").mkdir(parents=True)
            (root / "bin/tool").write_text("#!/bin/sh\n")
            (root / "lib/qubes").mkdir(parents=True)
            (root / "lib/qubes/qfile-unpacker").write_bytes(b"\x7fELF\x00binary")
            script = root / "bin/entry"
            script.write_text(
                "#!/nix/store/existing-bash/bin/sh\n"
                "ExecStart=-/usr/bin/tool\n"
                "/usr/lib/qubes/qfile-unpacker\n"
                "/usr/bin/external\n"
                "/opt/usr/bin/tool\n"
                "/usr/bin/tool-other\n"
            )
            script.chmod(0o555)
            link = root / "bin/link"
            link.symlink_to("/usr/bin/external")
            mappings = Path(directory) / "paths.json"
            mappings.write_text(json.dumps({
                "/bin/sh": "/nix/store/new-bash/bin/sh",
                "/usr/bin/external": "/nix/store/dependency/bin/external",
                "/usr/lib/qubes/qfile-unpacker": "/run/wrappers/bin/qfile-unpacker",
            }))
            subprocess.run([sys.executable, relocator, str(root), str(mappings)], check=True)
            self.assertEqual(script.read_text(), (
                "#!/nix/store/existing-bash/bin/sh\n"
                f"ExecStart=-{root}/bin/tool\n"
                "/run/wrappers/bin/qfile-unpacker\n"
                "/nix/store/dependency/bin/external\n"
                "/opt/usr/bin/tool\n"
                "/usr/bin/tool-other\n"
            ))
            self.assertEqual(script.stat().st_mode & 0o777, 0o555)
            self.assertEqual(str(link.readlink()), "/usr/bin/external")
            self.assertEqual((root / "lib/qubes/qfile-unpacker").read_bytes(), b"\x7fELF\x00binary")


unittest.main()
