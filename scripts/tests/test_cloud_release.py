import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class CloudReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / "repo"
        self.remote = Path(self.temp.name) / "remote.git"
        self.repo.mkdir()
        (self.repo / "scripts").mkdir()
        (self.repo / "MaruReader.xcodeproj").mkdir()
        shutil.copy(ROOT / "scripts/maru.py", self.repo / "scripts/maru.py")
        self.project = self.repo / "MaruReader.xcodeproj/project.pbxproj"
        shutil.copy(ROOT / "MaruReader.xcodeproj/project.pbxproj", self.project)
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "tag.gpgsign", "false")
        self.git("add", ".")
        self.git("commit", "-m", "Initial")
        self.git("init", "--bare", str(self.remote))
        self.git("remote", "add", "origin", str(self.remote))

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.repo), *args], check=True,
                              capture_output=True, text=True).stdout.strip()

    def release(self, *args, succeeds=True):
        result = subprocess.run(["python3", "scripts/maru.py", *args], cwd=self.repo,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, succeeds, result.stdout + result.stderr)
        return result

    def test_prereleases_increment_without_changing_build_number(self):
        original = self.project.read_text()
        self.release("prerelease", "9.8.7")
        self.release("prerelease")
        self.assertEqual(self.git("tag"), "v9.8.7-rc.1\nv9.8.7-rc.2")
        self.assertEqual(re.findall(r"CURRENT_PROJECT_VERSION = .*;", original),
                         re.findall(r"CURRENT_PROJECT_VERSION = .*;", self.project.read_text()))
        status = self.release("release-status").stdout
        self.assertIn("Marketing version: 9.8.7", status)
        self.assertIn("MaruReader MaruShareExtension MaruAssetDownloader", status)
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertIn("refs/tags/v9.8.7-rc.2", self.git("ls-remote", "origin"))
        self.assertNotIn("refs/heads/", self.git("ls-remote", "origin"))

    def test_release_same_version_and_duplicate(self):
        self.release("prerelease", "9.8.7")
        self.release("release")
        head = self.git("rev-parse", "HEAD")
        self.release("release", succeeds=False)
        self.assertEqual(head, self.git("rev-parse", "HEAD"))
        self.assertIn("refs/tags/v9.8.7", self.git("ls-remote", "origin"))

    def test_remote_tags_are_used_for_numbering_and_duplicates(self):
        self.git("tag", "v9.8.7-rc.5")
        self.git("tag", "v9.8.7")
        self.git("push", "origin", "--tags")
        self.git("tag", "-d", "v9.8.7-rc.5", "v9.8.7")
        self.release("release", "9.8.7", succeeds=False)
        self.release("prerelease", "9.8.7")
        self.assertIn("v9.8.7-rc.6", self.git("tag"))

    def test_dirty_tree_and_invalid_version_do_not_commit(self):
        head = self.git("rev-parse", "HEAD")
        self.release("release", "invalid", succeeds=False)
        (self.repo / "uncommitted").touch()
        self.release("prerelease", succeeds=False)
        self.assertEqual(head, self.git("rev-parse", "HEAD"))
        self.assertEqual(self.git("tag"), "")

    def test_push_failure_retains_tag_and_prints_retry(self):
        hook = self.remote / "hooks/pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        result = self.release("release", "9.8.7", succeeds=False)
        self.assertIn("git push origin refs/tags/v9.8.7", result.stderr)
        self.assertEqual(self.git("tag"), "v9.8.7")

    def test_unreachable_remote_does_not_change_version_or_commit(self):
        original = self.project.read_text()
        head = self.git("rev-parse", "HEAD")
        self.git("remote", "set-url", "origin", str(self.remote / "missing"))
        self.release("release", "9.8.7", succeeds=False)
        self.assertEqual(original, self.project.read_text())
        self.assertEqual(head, self.git("rev-parse", "HEAD"))


if __name__ == "__main__":
    unittest.main()
