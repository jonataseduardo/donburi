# Claude Code skills for herdr

Skills the herdr coordinator uses. Claude Code loads them from
`~/.claude/skills`. `donburi setup claude` (also part of `donburi setup`) links
each folder here that has a `SKILL.md` as `~/.claude/skills/<name>`.

It never replaces a skill of the same name that is already there. If
`~/.claude/skills/open-agent` exists as a plain folder or another link, setup
says so and leaves it; delete it and rerun `donburi setup claude` to use the
repo's.

| Skill | What it does |
|-------|--------------|
| `open-agent` | Opens a worker agent: a tab named after its task, a shell on the left and the agent on the right |
