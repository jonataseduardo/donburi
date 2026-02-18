---
name: create-pr
description: Create a well-structured pull request with conventional commits, pre-flight checks, and a diff-aware description. Use when asked to create a PR, submit changes, or open a pull request.
disable-model-invocation: true
allowed-tools: Bash(git *) Bash(gh *) Bash(prek *)
---

# Create Pull Request

Create a high-quality, reviewable pull request following project conventions.

## Workflow

### 1. Pre-flight checks

Before creating the PR, run all checks and fix any issues:

```bash
# Run all hooks (shellcheck + stylua)
prek run --all-files
```

If StyLua fails, it will auto-format the files. Stage the fixes and run `prek run --all-files` again to confirm it passes. Commit any formatting changes before proceeding.

Fix any failures before proceeding. Do not skip checks.

### 2. Update changelog and version

**Always run this step when the PR targets `main`.**

Invoke the changelog and versioning skill to bump `VERSION` and update `CHANGELOG.md`:

```
/changelog
```

This will:
1. Auto-detect the bump type from conventional commits on the branch (`feat` -> minor, `fix` -> patch, breaking -> major)
2. Generate changelog entries grouped by type (Added, Changed, Fixed)
3. Present the entries for review before writing
4. Update `VERSION` and `CHANGELOG.md`, then commit as `chore(release): bump version to X.Y.Z and update changelog`

If the user provided a bump type override, pass it through (e.g. `/changelog minor`).

If the PR does **not** target `main` (e.g. merging into `dev`), skip this step.

### 3. Stage and commit with conventional commits

This project uses [Conventional Commits](https://www.conventionalcommits.org/). Every commit message must follow this format:

```
<type>(<scope>): <short description>
```

**Types:**
- `feat` -- new feature or capability
- `fix` -- bug fix
- `refactor` -- code change that neither fixes a bug nor adds a feature
- `chore` -- maintenance tasks (deps, CI, release bumps)
- `docs` -- documentation only
- `test` -- adding or updating tests
- `style` -- formatting, whitespace (no logic change)

**Scopes** (optional, use when changes are contained to one area):
- `nvim`, `zsh`, `tmux`, `aerospace`, `sketchybar`, `btop`, `ghostty`, `keybinds`
- Omit scope for cross-cutting changes

**Examples from this repo:**
```
feat(nvim): add octo.nvim for GitHub PR code review
fix: add network resilience, sync enterprise package lists, and harden CI
refactor: simplify AGENT.md with key file index and task-oriented sections
chore(release): bump version to 0.4.1 and update changelog
```

**Rules:**
- Use imperative mood ("add", "fix", "update" -- not "added", "fixes", "updated")
- Keep the first line under 72 characters
- Focus on *why* the change was made, not *what* changed (the diff shows what)
- If a commit addresses a GitHub issue, add `Fixes #<number>` or `Closes #<number>` in the commit body

### 4. Analyze the diff

Before writing the PR description, gather context:

```bash
# Identify the base branch
git log --oneline main..HEAD

# Full diff against base
git diff main...HEAD

# Changed files only
git diff main...HEAD --name-only

# Check if there are related issues
gh issue list --state open
```

Use the actual diff output to write an accurate summary. Do not guess or generalize.

### 5. Write the PR description

Use this structure:

```markdown
## Summary

<1-3 sentences explaining the motivation and what this PR achieves. Link to any related issues.>

Fixes #<issue-number> (if applicable)

## Changes

- <Concrete change 1, referencing specific files or components>
- <Concrete change 2>
- ...

## Testing

- <How the changes were verified>
- <Commands run, checks passed>

## Notes for reviewers

- <Anything reviewers should pay attention to>
- <Areas of uncertainty or trade-offs made>
```

### 6. Create the PR

```bash
gh pr create --title "<conventional commit style title>" --body "$(cat <<'EOF'
<PR body from step 4>
EOF
)"
```

**Title format:** Use the same conventional commit format as commit messages. If the PR contains multiple commits, use the most significant change type.

## Reviewability guidelines

Follow these principles to keep PRs easy to review:

- **One concern per PR.** Don't mix a bug fix with a refactor with a new feature.
- **Small is better.** Under 400 lines changed is ideal. If larger, explain why in the PR description.
- **Self-contained.** The PR should make sense on its own without requiring context from Slack or verbal discussions.
- **No dead code.** Don't include commented-out code or unused imports.
- **Update docs if needed.** If the change affects README.md, AGENT.md, or user-facing behavior, update them in the same PR.

## Arguments

When invoked with arguments, interpret them as context:
- `/create-pr` -- create PR from current branch state
- `/create-pr Fixes #42` -- create PR and link to issue 42
- `/create-pr --draft` -- create as draft PR
