> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: adopt claude code managed worktrees (#233)

## Approach

`.claude` is a committed symlink to `.agents`, and that single fact is what makes every worktree in this repository a manual affair. Claude Code only treats a worktree as managed when the repository's `.claude/worktrees` directory is its own realpath, and through the symlink that path resolves into `.agents/worktrees` instead. The comparison fails, so entering a worktree prompts every time and `--worktree` refuses to create one at all. Turning `.claude` into a real directory that holds one relative symlink per file in `.agents` restores the equality while keeping the fallback lookup those files exist for.

The old convention was written against that limitation. It named three fixed sibling checkouts outside the repository and reused them across issues, because a folder Claude Code could manage did not exist. Once the managed path works, the convention that replaces it is the one the tool already assumes: a worktree per issue, created with its branch, removed when the branch is. Deleting the old section without writing the new one would leave the `implement` skill's "where the owner keeps a worktree per branch" hook pointing at nothing.

Two things the new convention has to say, because neither is discoverable from the tool. A stack takes one worktree for all of its branches: `gh stack sync` and `gh stack rebase` rewrite every branch in the stack, and git refuses to move a branch that is checked out in another worktree, so a worktree per branch fails a cascade rebase partway through. And a fresh worktree carries none of this repository's gitignored state, so `config/master.key` has to be copied in and the database seeded before `bin/ci` will run there.

The nesting is the part worth proving rather than assuming. A worktree under `.claude/worktrees/` sits inside the root checkout's own working tree, so the root's tooling could plausibly walk into a second copy of the whole application. Measured on a throwaway worktree before this plan was written: `git status`, `bin/rubocop --list-target-files` and `rspec --dry-run` in the root all report nothing from it, and with no `.bundle/config` in the repository the gems are system-wide, so a new worktree needs no `bundle install`.

## Steps

- Replace the committed `.claude` symlink with a real directory holding one relative symlink per file in `.agents`, keeping mode `120000` on each entry in the index
- Retarget the machine-local settings rule in `.gitignore` to the real path, and add the rule that keeps created worktrees out of the tree
- Replace the retired worktree section of `.agents/gh-solo.md` with the convention that supersedes it: one worktree per issue under the managed path, the root left on the default branch, the stack exception, the gitignored state a new worktree lacks, and removing the worktree before the branch
- Watch the two new ignore rules fail first, against a probe file each, before trusting them
- Prove the root checkout's git, RuboCop and RSpec all ignore a worktree created under `.claude/worktrees/`, against a control file each tool does report

## Verification

- `bin/ci` passes
- `test "$(git ls-files -s .claude | grep -c '^120000')" = "$(ls .agents/*.md | wc -l)"` exits 0, which is one symlink in the index per file in `.agents`
- `test "$(realpath .claude)" = "$PWD/.claude"` exits 0, which is the equality the managed-location check performs
- `git check-ignore -q .claude/worktrees/probe .claude/settings.local.json` exits 0
- `bin/rubocop --list-target-files | grep -q '^\.claude/'` exits 1 with a probe Ruby file present under a worktree path, having been seen to exit 0 for a control file elsewhere in the tree
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore '.claude/worktrees/*' --ignore '.claude/settings.local.json'` exits 0 over this plan

No gate here reads the harness. Whether entering the worktree actually stops prompting is a property of Claude Code's own permission check, observed by running it rather than asserted by an exit code, and the same is true of `--worktree` becoming usable. Nor can any gate see whether a future session follows the convention: `.agents/gh-solo.md` is read by an agent, not enforced by one.

## Open questions

- The bootstrap line says to copy `config/master.key` into a new worktree. On the probe worktree, `bin/rails runner` succeeded without one, so the failure is narrower than "every `bin/rails` command", and which commands actually break is unpinned. The line is right to keep either way; the question is whether it should name the failure.
- This branch's own worktree sits at a path that exists only because the root checkout is holding this change uncommitted. It resolves the moment the change is on the default branch, and every issue after this one starts from a root that already has the directory. Nothing to do, but a reviewer will notice it.

## Settled

None yet.
