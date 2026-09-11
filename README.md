# TANF development utilities

This repository stores the local OpenCode configuration, agent skills, and personal utilities used while developing TANF-app. Its `.agents` directory is linked into the main TANF-app checkout and into each worktree created by `tanf-worktree.sh`.

The repository can be renamed without changing the worktree script because the script locates `.agents` and `opencode.json` relative to itself.

## Expected layout

By default, the worktree helper expects these paths:

```text
~/repos/work/
|-- TANF-utils/
|   |-- .agents/
|   |-- opencode.json
|   `-- personal/
|       `-- scripts/
`-- TANF-app/
    |-- 00-main/
    `-- <issue worktrees>
```

`00-main` must be the main TANF-app checkout. New issue and review worktrees are created beside it under `TANF-app/`.

Configure the repository locations in your shell startup file. `TANF_WORKTREE_ROOT` must be the directory containing `00-main`:

```bash
export TANF_WORKTREE_ROOT="$HOME/repos/work/TANF-app"
export TANF_UTILS_ROOT="$HOME/repos/work/TANF-utils"
export PATH="$TANF_UTILS_ROOT/personal/scripts:$PATH"
```

The scripts use those repository paths as defaults. Export the root variables if either repository is elsewhere, and add the scripts directory to `PATH` to make each executable script available from any directory.

## Initial setup

Link the shared agent instructions into the main checkout:

```bash
ln -s "$TANF_UTILS_ROOT/.agents" \
  "$TANF_WORKTREE_ROOT/00-main/.agents"
```

Optionally link the shared OpenCode configuration into the main checkout too:

```bash
ln -s "$TANF_UTILS_ROOT/opencode.json" \
  "$TANF_WORKTREE_ROOT/00-main/opencode.json"
```

The helper creates both links automatically in new worktrees. It also copies the untracked frontend and backend environment files from `00-main`, so these files must exist:

```text
TANF-app/00-main/tdrs-frontend/.env
TANF-app/00-main/tdrs-backend/.env
```

The worktree workflow requires `git`, `tmux`, `nvim`, and `opencode`. Pull request review worktrees also require `task` and the local services required by the selected Taskfile target.

## Worktree workflow

Run `tanf-worktree.sh` with no arguments for an interactive menu, or use one of the commands below. Run it from an existing tmux session, or pass `--session NAME`. If exactly one tmux session exists, it is selected automatically.

Branch and worktree names must start with a four-digit issue number followed by a hyphen, such as `6000-add-audit-log`.

### Start issue work

```bash
tanf-worktree.sh issue 6000-add-audit-log
tanf-worktree.sh issue 6000-add-audit-log --base release/v4.24.0
```

This command:

1. Creates a local branch and worktree from `develop`, or from `--base REF`.
2. Links `.agents` and `opencode.json` into the worktree.
3. Copies both `.env` files from `00-main`.
4. Opens a tmux window named with the issue number, with Neovim and OpenCode in side-by-side panes.

### Review a pull request branch

```bash
tanf-worktree.sh review 6000-add-audit-log
tanf-worktree.sh review origin/6000-add-audit-log --task up
```

This fetches the remote branch, creates a detached review worktree, prepares its local files, and opens a tmux window named `R-6000`. The right pane runs `task up` by default. Use `--remote NAME` or `--task TARGET` to override those defaults.

### List and remove worktrees

```bash
tanf-worktree.sh list
tanf-worktree.sh finish 6000-add-audit-log
tanf-worktree.sh finish 6000 --delete-branch
```

`finish` removes the worktree and any tmux window rooted in it. It preserves the local branch unless `--delete-branch` is supplied. Dirty worktrees are rejected unless `--force` is supplied.

Run `tanf-worktree.sh --help` for all options.

## Personal scripts

The remaining scripts can also be run from any directory. For local operations, they use `$TANF_WORKTREE_ROOT/00-main/tdrs-backend`.

### Add local test users

`personal/scripts/add_test_user.sh` creates or updates users in the local Docker-backed Django environment. User definitions live beside it in `personal/scripts/test_users.json`.

```bash
add_test_user.sh --list
add_test_user.sh john
add_test_user.sh --all
```

This script requires `jq` and a running backend container.

### Change a test user's role

`personal/scripts/toggle_user_role.sh` changes the role and location assignments for the email configured at the top of the script. Review that email before use.

```bash
toggle_user_role.sh analyst
toggle_user_role.sh analyst --stt California
toggle_user_role.sh regional --region Atlanta
toggle_user_role.sh admin --env tanf-dev
```

Local use requires a running backend container. Remote use requires the Cloud Foundry CLI to be authenticated and targeted correctly. The `.bk` file is the older local-only version retained for reference.

## Other utilities

`personal/tmp/datapipeline_scripts/` contains the retained TANF SQL/reporting notebooks. They are reference utilities and are not used by the worktree workflow.
