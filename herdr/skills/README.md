# Claude Code skills for herdr

Skills the herdr coordinator uses. Claude Code loads them from
`~/.claude/skills`, and `donburi setup` does not link them, so link each one
on every Mac, from the repo root:

```bash
mkdir -p ~/.claude/skills
ln -s "$PWD/herdr/skills/open-agent" ~/.claude/skills/open-agent
```

If `~/.claude/skills/open-agent` already exists as a plain folder, delete it
first.

| Skill | What it does |
|-------|--------------|
| `open-agent` | Opens a worker agent: a tab named after its task, a shell on the left and the agent on the right |
