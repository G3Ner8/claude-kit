"""Worktree attribution in the sitrep collector.

Run from the repo root: python3 -m unittest discover -s tests/work-core
"""
import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "collect", ROOT / "plugins/work-core/skills/sitrep/collect.py")
collect = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collect)


def git(*args, cwd):
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def make_repo(path):
    path.mkdir(parents=True)
    git("init", "-q", "-b", "main", cwd=path)
    git("-c", "user.email=t@example.com", "-c", "user.name=t",
        "commit", "-q", "--allow-empty", "-m", "init", cwd=path)
    return path


class WorktreeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        # resolve() because macOS hands out /var paths that git reports as /private/var
        self.root = Path(self.tmp.name).resolve()

    def tearDown(self):
        self.tmp.cleanup()

    def test_main_checkout_is_its_own_main(self):
        repo = make_repo(self.root / "shop" / "admin")
        self.assertEqual(collect.main_worktree(str(repo)), str(repo))

    def test_linked_worktree_resolves_to_main_checkout(self):
        repo = make_repo(self.root / "shop" / "admin")
        wt = self.root / "worktrees" / "admin" / "feat-1-r2"
        git("worktree", "add", "-q", "-b", "feat/1-r2", str(wt), cwd=repo)
        self.assertEqual(collect.main_worktree(str(wt)), str(repo))

    def test_linked_worktree_of_a_submodule_resolves_to_the_submodule(self):
        sub_src = make_repo(self.root / "src" / "web")
        outer = make_repo(self.root / "suite")
        git("-c", "protocol.file.allow=always", "submodule", "add", "-q",
            str(sub_src), "web", cwd=outer)
        sub = outer / "web"
        wt = self.root / "worktrees" / "web" / "fix-2"
        git("worktree", "add", "-q", "-b", "fix/2", str(wt), cwd=sub)
        self.assertEqual(collect.main_worktree(str(wt)), str(sub))
        self.assertEqual(collect.project_group(collect.main_worktree(str(wt)),
                                               path_map=self.root / "none.json"), "suite")

    def test_not_a_repo_returns_the_path_unchanged(self):
        self.assertEqual(collect.main_worktree(str(self.root / "gone")), str(self.root / "gone"))

    def test_removed_worktree_matches_a_single_known_repo(self):
        known = {"/w/shop/admin", "/w/shop/buyer"}
        cwd = "/home/u/.coord/worktrees/admin/feat-1-r4/src/app"
        self.assertEqual(collect.removed_worktree_repo(cwd, known), "/w/shop/admin")

    def test_removed_worktree_with_no_or_two_matches_is_left_alone(self):
        self.assertIsNone(collect.removed_worktree_repo(
            "/x/worktrees/unknown/feat", {"/w/shop/admin"}))
        self.assertIsNone(collect.removed_worktree_repo(
            "/x/worktrees/admin/feat", {"/w/a/admin", "/w/b/admin"}))
        self.assertIsNone(collect.removed_worktree_repo("/x/project", {"/w/shop/admin"}))
        self.assertIsNone(collect.removed_worktree_repo("/x/worktrees", {"/w/worktrees"}))

    def test_repo_set_drops_linked_worktrees(self):
        repo = make_repo(self.root / "shop" / "admin")
        wt = self.root / "worktrees" / "admin" / "feat-1"
        git("worktree", "add", "-q", "-b", "feat/1", str(wt), cwd=repo)
        cache = self.root / "repos.json"
        kept, _, _ = collect.repo_set({str(repo), str(wt)}, path=cache)
        self.assertEqual(kept, [str(repo)])
        self.assertNotIn(str(wt), cache.read_text())


if __name__ == "__main__":
    unittest.main()
