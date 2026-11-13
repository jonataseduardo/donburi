---
name: open-agent
description: "Herdr coordinator: open a new worker coding agent for Jonatas in a project's herdr workspace (a task-named tab, or a new workspace if none, with the agent in the right pane and a shell on the left), start Claude there, and hand it the task. Use for \"open an agent on <repo>\", \"start a worker for X\", \"open a section on <repo>\", \"spin up claude in <project>\", \"put an agent on this\", \"open it in the right pane\". Requires HERDR_ENV=1."
---

# Open a worker agent

You are the herdr coordinator. Do not do the work yourself: open a worker, give it
the task, report back in one line. Follow `herdr --skill` for CLI details; parse
every ID from JSON responses, never guess them.

## 1. Resolve the project directory

Project roots differ per Mac (the coordinator's folder is set per Mac), so find
the folder; never assume a root.

- An agent may already work there: `herdr agent list` gives each agent's `cwd`
  and `workspace_id`.
- Otherwise look in your own folder, next to it, and in `~/c`:
  `ls -d ./*<word>* ../*<word>* ~/c/*<word>* 2>/dev/null`.
- If more than one dir matches (e.g. `anomaly_detector` vs `internal_anomaly_detector`)
  or none, ask Jonatas. Do not pick one.

## 2. Find or create the place

```bash
herdr workspace list
```

- **Workspace already exists for the project** (its label, or the `workspace_id`
  of an agent in that folder) → new tab:
  `herdr tab create --workspace <wid> --cwd <dir> --label <short-task-label> --no-focus`
  → pane = `.result.root_pane.pane_id`
- **None** → new workspace labelled after the project:
  `herdr workspace create --cwd <dir> --label <project> --no-focus`
  → pane = `.result.root_pane.pane_id`
- **Always** put the agent in the right pane of a named tab (label = short task,
  never a number); the left pane stays a shell:
  `herdr pane split <pane> --direction right --cwd <dir> --no-focus`
  → use the new `.result.pane.pane_id`. If the workspace was just created, rename
  its tab: `herdr tab rename <tab_id> <short-task-label>`.

Useful one-liner: `... 2>&1 | python3 -c "import json,sys;d=json.load(sys.stdin)['result'];print(d['root_pane']['pane_id'])"`

## 3. Start Claude

```bash
herdr agent start <name> --kind claude --pane <pane>
```

- `<name>`: role + project, `[a-z][a-z0-9_-]{0,31}`, unique, e.g. `web-review`,
  `aging-incident`, `anomaly-guidelines`. Never `coordinator`.
- Default model/effort. Append `-- --model <m> --effort <e>` **only** when he names one.
- Two workers editing the same repo → separate git worktrees (tell the worker).

### When start fails

- `agent_not_ready` / timeout on a **new folder**: Claude is showing the
  folder-trust prompt. Do NOT answer it. Run `herdr agent focus <pane>` (or
  `herdr pane read <pane> --source visible` first to confirm) and tell him:
  "pick *Yes, I trust this folder*, then Ctrl+a back". After he's back, retry `agent start`
  only if `herdr agent list` doesn't already show the agent.
- Timeout with no Claude visible: read `herdr pane read <pane> --source visible`.
  Commonly oh-my-zsh's `Would you like to update? [Y/n]` ate the first char of
  `claude`. Tell him (or, if he says so, let him answer it), then retry `agent start`.
- Never send keys to a pane showing a prompt yourself.

## 4. Give it the task

```bash
herdr agent prompt <name> "<task>"
```

- No `--wait`; the feed reports when it finishes.
- Pass his request as he said it, plus the context you already know (repo, ticket,
  channel, existing worktree). For a long brief, write it to your scratchpad as
  Markdown and prompt `Read and do the task in <abs path>`.
- Always end with the guardrails: "Do not post to GitHub, Slack or Jira, and do not
  restart, deploy or change shared infra, until Jonatas confirms. Report a short summary."
- If the prompt is rejected because the agent is blocked, say so; don't retry blindly.

## 5. Reply

One line, marker from `herdr agent list` (`.tokens.mark`) + pane + name + workspace:

`▲ w1B:p2 (aging-incident) in ai_aging: started, investigating #ds-alerts`
