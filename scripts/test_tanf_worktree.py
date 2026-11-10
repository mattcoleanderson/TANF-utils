"""Isolated shell utility regression tests; run with python3 -m unittest discover -s scripts."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("tanf-worktree.sh")


class NonworktreeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.main = self.root / "00-main"
        self.git("init", str(self.main))
        self.git("-C", str(self.main), "-c", "user.name=Test", "-c",
                 "user.email=test@example.com", "commit", "--allow-empty", "-m", "initial")
        self.registered = self.root / "6000-active"
        self.git("-C", str(self.main), "worktree", "add", "-b", "6000-active",
                 str(self.registered))
        self.orphan = self.root / "6035-admin-etl-trigger"
        self.orphan.mkdir()

    def git(self, *args):
        return subprocess.run(["git", *args], check=True, capture_output=True, text=True)

    def shell(self, code, stdin=""):
        env = dict(os.environ, TANF_WORKTREE_ROOT=str(self.root))
        return subprocess.run(
            ["bash", "-c", 'source "$1"; ' + code, "test", str(SCRIPT)],
            input=stdin, env=env, capture_output=True, text=True, check=True,
        )

    def test_discovery_excludes_registered_repositories_and_symlinks(self):
        other = self.root / "independent-repo"
        self.git("init", str(other))
        (self.root / "linked-directory").symlink_to(self.orphan, target_is_directory=True)
        broken = self.root / "broken-git-link"
        broken.mkdir()
        (broken / ".git").symlink_to(self.root / "missing")
        result = self.shell("nonworktree_directories")
        self.assertEqual(result.stdout.strip(), str(self.orphan))

    def test_menu_includes_orphan_in_separate_section(self):
        result = self.shell("choose_worktree", "invalid\n2\n")
        self.assertEqual(result.stdout.strip(), str(self.orphan))
        self.assertIn("Registered worktrees:", result.stderr)
        self.assertIn("Non-worktree directories", result.stderr)
        self.assertIn("Invalid selection.", result.stderr)

    def test_cleanup_preserves_files_and_requires_each_confirmation(self):
        (self.orphan / "important.txt").write_text("preserve me")
        branch = "feature/6035-admin-etl-trigger"
        self.git("-C", str(self.main), "branch", branch)
        result = self.shell('''
            resolve_tmux_session() { echo test-session; }
            tmux_windows_for_worktree() { echo @123; }
            tmux() { echo "tmux $*"; }
            cleanup_nonworktree_directory "$WORKTREE_ROOT/6035-admin-etl-trigger"
        ''', "n\nn\n")
        self.assertNotIn("tmux kill-window", result.stdout)
        self.assertEqual((self.orphan / "important.txt").read_text(), "preserve me")
        self.git("-C", str(self.main), "show-ref", "--verify", "refs/heads/" + branch)
        self.assertIn("Nonempty directory preserved", result.stdout)

    def test_confirmed_cleanup_closes_windows_deletes_safe_branch_and_empty_directory(self):
        branch = "feature/6035-admin-etl-trigger"
        self.git("-C", str(self.main), "branch", branch)
        result = self.shell('''
            resolve_tmux_session() { echo test-session; }
            tmux_windows_for_worktree() { echo @123; }
            tmux() { echo "tmux $*"; }
            cleanup_nonworktree_directory "$WORKTREE_ROOT/6035-admin-etl-trigger"
        ''', "y\ny\ny\n")
        self.assertIn("tmux kill-window -t @123", result.stdout)
        self.assertFalse(self.orphan.exists())
        branches = self.git("-C", str(self.main), "branch", "--list", branch)
        self.assertEqual(branches.stdout, "")

    def test_window_matching_uses_paths_not_issue_labels(self):
        result = self.shell('''
            tmux() {
                printf '%s\n' "@1|$WORKTREE_ROOT/6035-admin-etl-trigger" \
                    "@1|$WORKTREE_ROOT/6035-admin-etl-trigger/tdrs-backend" \
                    "@2|$WORKTREE_ROOT/6035-admin-etl-trigger-other";
            }
            tmux_windows_for_worktree test "$WORKTREE_ROOT/6035-admin-etl-trigger"
        ''')
        self.assertEqual(result.stdout.strip(), "@1")

    def test_cleanup_preserves_unmerged_candidate_branch(self):
        branch = "feature/6035-admin-etl-trigger"
        self.git("-C", str(self.registered), "checkout", "-b", branch)
        self.git("-C", str(self.registered), "-c", "user.name=Test", "-c",
                 "user.email=test@example.com", "commit", "--allow-empty", "-m", "unmerged")
        self.git("-C", str(self.registered), "checkout", "6000-active")
        result = self.shell('''
            resolve_tmux_session() { echo test-session; }
            tmux_windows_for_worktree() { :; }
            cleanup_nonworktree_directory "$WORKTREE_ROOT/6035-admin-etl-trigger"
        ''', "y\nn\n")
        self.assertIn("Branch preserved:", result.stdout)
        self.git("-C", str(self.main), "show-ref", "--verify", "refs/heads/" + branch)
        self.assertTrue(self.orphan.exists())

    def test_cleanup_rejects_registered_directory(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.shell('cleanup_nonworktree_directory "$WORKTREE_ROOT/6000-active"')
        self.assertTrue((self.registered / ".git").is_file())


if __name__ == "__main__":
    unittest.main()
