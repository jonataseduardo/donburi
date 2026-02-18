---
name: changelog
description: Update CHANGELOG.md and bump VERSION file based on conventional commits. Use when asked to update changelog, bump version, or prepare a release.
disable-model-invocation: true
allowed-tools: Bash(git *) Bash(date *) Read Edit Write
---

# Changelog & Version Bump

Update `CHANGELOG.md` and bump the `VERSION` file following semver and [Keep a Changelog](https://keepachangelog.com/) conventions.

## Workflow

### 1. Read current version

```bash
cat VERSION
```

Store the current version as `CURRENT_VERSION` (e.g. `0.4.2`).

### 2. Collect commits since last release

```bash
# Get all commits on the current branch that are not yet in main
git log --oneline main..HEAD
```

If the branch is `main` itself (e.g. amending the latest release), use the last tag instead:

```bash
git log --oneline "$(git describe --tags --abbrev=0)"..HEAD
```

### 3. Determine bump type

**Auto-detection rules** (applied in priority order):

| Condition | Bump |
|-----------|------|
| Any commit body contains `BREAKING CHANGE:` or type has `!` suffix (e.g. `feat!:`) | **major** |
| Any commit type is `feat` | **minor** |
| All other cases (`fix`, `refactor`, `chore`, `docs`, `test`, `style`) | **patch** |

**Override:** If the user passed an argument (`/changelog patch`, `/changelog minor`, `/changelog major`), use that instead of auto-detection.

Compute the new version by applying the bump to `CURRENT_VERSION`:

- **major**: `X.Y.Z` -> `(X+1).0.0`
- **minor**: `X.Y.Z` -> `X.(Y+1).0`
- **patch**: `X.Y.Z` -> `X.Y.(Z+1)`

### 4. Generate changelog entries

Parse each conventional commit and group into [Keep a Changelog](https://keepachangelog.com/) sections:

| Commit type | Changelog section |
|-------------|-------------------|
| `feat` | `### Added` |
| `fix` | `### Fixed` |
| `refactor`, `style`, `chore`, `docs`, `test` | `### Changed` |
| Any with `BREAKING CHANGE` or `!` | `### Breaking Changes` (listed first) |

**Entry format:**
- Each entry should be a clear, human-readable bullet point
- Include the **scope** in bold if present: `- **nvim**: Add octo.nvim for GitHub PR code review`
- Use imperative mood matching the commit message
- Group related commits into a single entry when they address the same concern
- Omit merge commits and trivial formatting-only changes

### 5. Present for review

Before writing any files, present the following to the user and ask for confirmation:

```
Version bump: CURRENT_VERSION -> NEW_VERSION (bump_type)

Changelog entries:

## [NEW_VERSION] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...

Does this look correct? Any entries to add, remove, or edit?
```

Wait for the user to confirm or request edits. Apply any requested changes before proceeding.

### 6. Write changes

After the user confirms:

1. **Update `VERSION`**: Replace the contents with the new version string (single line, no trailing newline beyond what's standard).

2. **Update `CHANGELOG.md`**: Insert the new version section immediately after the `# Changelog` header line (before the first existing `## [...]` entry). Use today's date in `YYYY-MM-DD` format.

   The new section must be separated by a blank line above and below.

### 7. Stage and commit

```bash
git add VERSION CHANGELOG.md
git commit -m "chore(release): bump version to NEW_VERSION and update changelog"
```

## Arguments

- `/changelog` -- auto-detect bump type from commits, generate entries, review, and write
- `/changelog patch` -- force patch bump
- `/changelog minor` -- force minor bump
- `/changelog major` -- force major bump
- `/changelog --dry-run` -- show what would change without writing any files

## Examples

```
# Auto-detect and update
/changelog

# Force a minor bump
/changelog minor

# Preview without writing
/changelog --dry-run
```
