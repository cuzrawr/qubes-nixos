"""exercise native RPM signing with disposable keys and conflicting configuration."""

import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

signer = str(Path(sys.argv.pop(1)).resolve())
rpm_config = Path(sys.argv.pop(1)).resolve()
rpm_options = ["--rcfile", str(rpm_config / "rpmrc"), "--macros", str(rpm_config / "macros")]


def run(*command, env=None, check=True):
    return subprocess.run(command, env=env, check=check, capture_output=True, text=True)


class SigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.keyring = cls.root / "keyring with spaces"
        cls.keyring.mkdir(mode=0o700)
        cls.env = dict(os.environ, GNUPGHOME=str(cls.keyring))
        cls.addClassCleanup(run, "gpgconf", "--homedir", str(cls.keyring), "--kill", "all", check=False)
        run(
            "gpg",
            "--batch",
            "--no-options",
            "--homedir",
            str(cls.keyring),
            "--pinentry-mode",
            "loopback",
            "--passphrase",
            "",
            "--quick-generate-key",
            "Signing test <signing-test@example.invalid>",
            "rsa2048",
            "sign",
            "0",
        )
        keys = run("gpg", "--batch", "--no-options", "--homedir", str(cls.keyring), "--with-colons", "--list-keys")
        cls.fingerprint = next(line.split(":")[9] for line in keys.stdout.splitlines() if line.startswith("fpr:"))
        spec = cls.root / "fixture.spec"
        spec.write_text(
            "Name: signing-fixture\nVersion: 1\nRelease: 1\n"
            "Summary: Disposable signing fixture\nLicense: MIT\nBuildArch: noarch\n"
            "%description\nDisposable signing fixture.\n"
            "%install\nmkdir -p %{buildroot}/usr/share/signing-fixture\n"
            "printf fixture > %{buildroot}/usr/share/signing-fixture/marker\n"
            "%files\n/usr/share/signing-fixture/marker\n"
        )
        run(
            "rpmbuild",
            *rpm_options,
            "-bb",
            str(spec),
            "--define",
            f"_topdir {cls.root}",
            "--define",
            f"_dbpath {cls.root}/build-rpmdb",
            "--define",
            f"_tmppath {cls.root}",
            "--define",
            "_buildhost signing-test",
            "--define",
            "__os_install_post %{nil}",
        )
        cls.unsigned = next((cls.root / "RPMS/noarch").glob("*.rpm"))
        cls.digest = hashlib.sha256(cls.unsigned.read_bytes()).hexdigest()

    def sign(self, output, *, input_path=None, env=None):
        return run(
            signer,
            self.fingerprint,
            str(input_path or self.unsigned),
            str(output),
            env=env or self.env,
            check=False,
        )

    def assert_no_temporary_output(self):
        self.assertEqual(list(self.root.glob(".qubes-template.*.rpm")), [])
        self.assertEqual(hashlib.sha256(self.unsigned.read_bytes()).hexdigest(), self.digest)

    def test_sign_ignores_other_rpm_configuration(self):
        conflicting = self.root / "rpm-config"
        conflicting.mkdir()
        other_keyring = self.root / "other-keyring"
        other_keyring.mkdir(mode=0o700)
        (conflicting / "rpmrc").write_text(f"macrofiles: {conflicting}/macros\n")
        (conflicting / "macros").write_text(
            (rpm_config / "macros").read_text() + f"\n%_gpg_path {other_keyring}\n%__gpg_sign_cmd /bin/false false\n"
        )
        env = dict(self.env, RPM_CONFIGDIR=str(conflicting))
        inherited = run("rpm", "--rcfile", str(conflicting / "rpmrc"), "--eval", "%{_gpg_path}", env=env)
        self.assertEqual(inherited.stdout.strip(), str(other_keyring))
        output = self.root / "signed output.rpm"
        signed = self.sign(output, env=env)
        self.assertEqual(signed.returncode, 0, signed.stderr)
        public_key = self.root / "public-key.asc"
        public_key.write_text(run("gpg", "--batch", "--armor", "--export", self.fingerprint, env=self.env).stdout)
        database = str(self.root / "verification-rpmdb")
        run("rpm", *rpm_options, "--dbpath", database, "--import", str(public_key))
        verified = run("rpm", *rpm_options, "--dbpath", database, "--checksig", str(output))
        self.assertIn("digests signatures OK", verified.stdout)
        self.assertEqual(list(other_keyring.iterdir()), [])
        self.assert_no_temporary_output()

    def test_existing_output_is_not_overwritten(self):
        output = self.root / "existing.rpm"
        output.write_bytes(b"retain this file")
        failed = self.sign(output)
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn("output must be a new file", failed.stderr)
        self.assertEqual(output.read_bytes(), b"retain this file")
        self.assert_no_temporary_output()

    def test_dangling_symlink_is_not_overwritten(self):
        output = self.root / "dangling.rpm"
        target = self.root / "missing-target"
        output.symlink_to(target)
        failed = self.sign(output)
        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(output.readlink(), target)
        self.assertFalse(target.exists())
        self.assert_no_temporary_output()

    def test_corrupt_input_leaves_no_output(self):
        corrupt = self.root / "corrupt.rpm"
        corrupt.write_bytes(b"not an RPM")
        output = self.root / "failed.rpm"
        failed = self.sign(output, input_path=corrupt)
        self.assertNotEqual(failed.returncode, 0)
        self.assertFalse(output.exists())
        self.assertEqual(corrupt.read_bytes(), b"not an RPM")
        self.assert_no_temporary_output()

    def test_missing_key_leaves_no_output(self):
        empty_keyring = self.root / "empty-keyring"
        empty_keyring.mkdir(mode=0o700)
        self.addCleanup(run, "gpgconf", "--homedir", str(empty_keyring), "--kill", "all", check=False)
        output = self.root / "missing-key.rpm"
        failed = self.sign(output, env=dict(self.env, GNUPGHOME=str(empty_keyring)))
        self.assertNotEqual(failed.returncode, 0)
        self.assertFalse(output.exists())
        self.assert_no_temporary_output()

    def test_keyring_must_be_explicit_and_absolute(self):
        for keyring in (None, "relative", str(self.root / "absent")):
            with self.subTest(keyring=keyring):
                env = dict(self.env)
                if keyring is None:
                    del env["GNUPGHOME"]
                else:
                    env["GNUPGHOME"] = keyring
                output = self.root / "invalid-keyring.rpm"
                failed = self.sign(output, env=env)
                self.assertNotEqual(failed.returncode, 0)
                self.assertIn("GNUPGHOME", failed.stderr)
                self.assertFalse(output.exists())
                self.assert_no_temporary_output()


unittest.main()
