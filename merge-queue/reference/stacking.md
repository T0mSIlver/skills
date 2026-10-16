# Stacked PRs: repairs

- Keep the upper layers draft until the one below is about to merge.
- Never stack across repos, and nothing stacks on a fork PR.
- Retarget children to main before the parent branch is deleted, or GitHub
  closes them for good (`orch-mergecheck --merge` does this).
- A squash-merged parent leaves the child conflicting on shared hunks. Merge
  main into the child, or transplant its diff:
  `git checkout -B child origin/main && git diff <parent> <child> | git apply -3`.
  When merging main conflicts, resolve each conflicted file with the parent's
  last head as the base: `git merge-file -p <child-file> <parent-head-file>
  <main-file>` replays only the child's own change; a plain merge of main replays the parent
  twice and conflicts with itself.
  Never `git reset --soft` onto a newer base: the tree keeps the old base and
  silently reverts everything that landed in between.
- A conflicting PR gets no workflow run: ready and draft toggles start
  nothing. `orch-conflicts` finds them.
