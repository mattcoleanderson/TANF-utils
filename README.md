# TANF development utilities

This repository stores the local OpenCode configuration, agent skills, and development utilities used while developing TANF-app. Its `.agents` directory is linked into the main TANF-app checkout and into each worktree created by `tanf-worktree.sh`.

The repository can be renamed without changing the worktree script because the script locates `.agents` and `opencode.json` relative to itself.

## Expected layout

By default, the worktree helper expects these paths:

```text
~/repos/work/
|-- TANF-utils/
|   |-- .agents/
|   |-- opencode.json
|   `-- scripts/
`-- TANF-app/
    |-- 00-main/
    `-- <issue worktrees>
```

`00-main` must be the main TANF-app checkout. New issue and review worktrees are created beside it under `TANF-app/`.

Configure the repository locations in your shell startup file. `TANF_WORKTREE_ROOT` must be the directory containing `00-main`:

```bash
export TANF_WORKTREE_ROOT="$HOME/repos/work/TANF-app"
export TANF_UTILS_ROOT="$HOME/repos/work/TANF-utils"
export PATH="$TANF_UTILS_ROOT/scripts:$PATH"
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

The worktree workflow requires `git`, `tmux`, `nvim`, and `opencode`. Pull request review worktrees also require Docker with the Compose plugin. A custom review Taskfile target additionally requires `task` and any local services used by that target.

## Worktree workflow

Run `tanf-worktree.sh` with no arguments for an interactive menu, or use one of the commands below. Run it from an existing tmux session, or pass `--session NAME`. If exactly one tmux session exists, it is selected automatically.

Issue numbers are optional. Both new branches and existing review branches may use names such as `6000-add-audit-log`, `hotfix-login`, or `hotfix/login-timeout`. The final path component is used as the local worktree directory name. It must start with a letter or digit and contain only letters, digits, dots, underscores, or hyphens; Git branch naming rules also apply.

Tmux window labels use the four-digit issue number when the directory name follows `NNNN-description`; otherwise they use the full directory name. Review windows add an `R-` prefix. Existing worktree paths, local branches, and window names are rejected. For example, `hotfix/login-timeout` and `feature/login-timeout` both map to directory `login-timeout`, so they cannot have worktrees at the same time.

### Start work

Choose **Start work** in the interactive menu, or use the `issue` command for either numbered or unnumbered branches:

```bash
tanf-worktree.sh issue 6000-add-audit-log
tanf-worktree.sh issue 6000-add-audit-log --base release/v4.24.0
tanf-worktree.sh issue hotfix-login
tanf-worktree.sh issue hotfix/login-timeout
```

This command:

1. Creates a local branch and worktree from `develop`, or from `--base REF`.
2. Links `.agents` and `opencode.json` into the worktree.
3. Copies both `.env` files from `00-main`.
4. Opens a tmux window with Neovim and OpenCode in side-by-side panes. For example, `6000-add-audit-log` uses window `6000`, and `hotfix/login-timeout` uses window `login-timeout`.

New branches retain their full names: `issue hotfix/login-timeout` creates branch `hotfix/login-timeout` in directory `login-timeout`.

### Review a pull request branch

```bash
tanf-worktree.sh review 6000-add-audit-log
tanf-worktree.sh review origin/6000-add-audit-log --task up
tanf-worktree.sh review feature/6000-add-audit-log
tanf-worktree.sh review hotfix/login-timeout
```

This fetches the remote branch, creates a local branch and worktree that track it, prepares the local files, and opens a review tmux window. For example, reviewing `feature/6000-add-audit-log` creates local branch `6000-add-audit-log` with `origin/feature/6000-add-audit-log` as its upstream and window `R-6000`, so `git pull` retrieves later changes from the author.

For an unnumbered branch such as `hotfix/login-timeout`, the local branch and directory are named `login-timeout`, the upstream is `origin/hotfix/login-timeout`, and the window is named `R-login-timeout`.

The review deployment runs in the new tmux window. It stops the shared `tdrs-frontend` and `tdrs-backend` Compose projects, removes all named volumes belonging to the backend project, rebuilds and starts the review branch's backend, applies its migrations, then rebuilds and starts its nginx frontend. The command stops on the first failure.

**Warning:** Starting any PR review deletes the shared local backend PostgreSQL database and the other backend Compose volumes. Review environments are intentionally disposable, and only one TANF-app worktree can own the shared stack at a time.

`--task TARGET` is an escape hatch for a nonstandard review deployment. Cleanup is unchanged and remains destructive, but the selected Taskfile target replaces the standard backend rebuild, migration, and nginx frontend rebuild sequence. Omitting `--task` uses the standard clean deployment; `--task up` is treated as that default rather than invoking the repository's ordinary `up` task.

### List and remove worktrees

```bash
tanf-worktree.sh list
tanf-worktree.sh finish 6000-add-audit-log
tanf-worktree.sh finish 6000 --delete-branch
tanf-worktree.sh finish login-timeout --delete-branch
```

For review worktrees, `finish` checks the running Compose containers before removing the worktree. It stops each shared backend or frontend project only when Docker's Compose labels show that the project was started from the worktree being removed, preventing containers from retaining bind mounts into a deleted worktree. Finishing an inactive review worktree does not stop a stack owned by another worktree. Issue-worktree cleanup is unchanged and does not require Docker.

The command also removes any tmux window rooted in the worktree. It preserves the local branch unless `--delete-branch` is supplied. Dirty worktrees are rejected unless `--force` is supplied. Backend volumes are retained by `finish`, but the next `review` always deletes them before deployment.

Use the full directory name for unnumbered worktrees. The four-digit shortcut (such as `finish 6000`) remains available for numbered worktrees. Finishing a newly created prefixed branch deletes its full Git branch name when `--delete-branch` is supplied.

The interactive **Finish worktree** menu also has a **Non-worktree directories** section for leftover directories under the worktree root that are not registered with Git and have no `.git` entry. Symlinks are excluded. Selecting one shows its remaining contents and offers to close tmux windows rooted there in the selected session. Local branches with the same final path component are offered individually as cleanup candidates, not assumed to belong to the directory; deletion uses Git's safe `-d` check, never force deletion. Empty-directory removal requires confirmation. Nonempty directories, Compose services, and volumes are preserved for manual inspection and cleanup. The CLI `finish` command still accepts only registered worktrees.

Run `tanf-worktree.sh --help` for all options.

## Utility scripts

The remaining scripts can also be run from any directory. For local operations, they use `$TANF_WORKTREE_ROOT/00-main/tdrs-backend`.

### Add local test users

`scripts/add_test_user.sh` creates or updates users in the local Docker-backed Django environment. User definitions live beside it in `scripts/test_users.json`.

```bash
add_test_user.sh --list
add_test_user.sh john
add_test_user.sh --all
```

This script requires `jq` and a running backend container.

### Change a test user's role

`scripts/toggle_user_role.sh` changes the role and location assignments for the email configured at the top of the script. Review that email before use.

```bash
toggle_user_role.sh analyst
toggle_user_role.sh analyst --stt California
toggle_user_role.sh regional --region Atlanta
toggle_user_role.sh admin --env tanf-dev
```

Local use requires a running backend container. Remote use requires the Cloud Foundry CLI to be authenticated and targeted correctly. The `.bk` file is the older local-only version retained for reference.
