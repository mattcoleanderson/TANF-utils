#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_ROOT="${TANF_UTILS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WORKTREE_ROOT="${TANF_WORKTREE_ROOT:-$HOME/repos/work/TANF-app}"
MAIN_WORKTREE="$WORKTREE_ROOT/00-main"
AGENTS_SOURCE="$UTILS_ROOT/.agents"
OPENCODE_SOURCE="$UTILS_ROOT/opencode.json"
FRONTEND_ENV_SOURCE="$MAIN_WORKTREE/tdrs-frontend/.env"
BACKEND_ENV_SOURCE="$MAIN_WORKTREE/tdrs-backend/.env"
DEFAULT_BASE="develop"
DEFAULT_REMOTE="origin"
DEFAULT_REVIEW_TASK="up"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Manage TANF-app issue and pull request worktrees.

Usage:
  tanf-worktree.sh
  tanf-worktree.sh issue BRANCH [--base REF] [--session NAME]
  tanf-worktree.sh review REMOTE_BRANCH [--remote NAME] [--task TARGET] [--session NAME]
  tanf-worktree.sh finish WORKTREE [--delete-branch] [--force] [--session NAME]
  tanf-worktree.sh list
  tanf-worktree.sh help

Commands:
  issue    Create a branch and worktree, prepare local files, and open nvim/opencode.
  review   Fetch a remote branch into a detached worktree and run `task up` in tmux.
  finish   Remove a worktree and close its tmux window. The branch is kept by default.
  list     List the repository's active worktrees.

Branch naming:
  New issue branches and the final path component of existing review branches
  must start with a four-digit issue code and a hyphen, for example:
  feature/5603-file-submission-error-message-and-form-reset

Options:
  --base REF          Base the new issue branch on REF (default: develop).
  --remote NAME       Fetch the review branch from NAME (default: origin).
  --task TARGET       Taskfile target used for a review (default: up).
  --session NAME      Use this tmux session instead of the current session.
  --delete-branch     Delete the local issue branch after removing its worktree.
  --force             Remove a dirty worktree and force branch deletion when requested.
  -h, --help          Show help.

Examples:
  tanf-worktree.sh issue 6000-add-audit-log
  tanf-worktree.sh issue 6000-add-audit-log --base release/v4.24.0
  tanf-worktree.sh review 6000-add-audit-log --remote origin
  tanf-worktree.sh finish 6000-add-audit-log --delete-branch
EOF
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_environment() {
    [ -d "$MAIN_WORKTREE/.git" ] || die "Main worktree not found at $MAIN_WORKTREE"
    [ -d "$AGENTS_SOURCE" ] || die "Agent directory not found at $AGENTS_SOURCE"
    [ -f "$OPENCODE_SOURCE" ] || die "OpenCode config not found at $OPENCODE_SOURCE"
    [ -f "$FRONTEND_ENV_SOURCE" ] || die "Frontend env file not found at $FRONTEND_ENV_SOURCE"
    [ -f "$BACKEND_ENV_SOURCE" ] || die "Backend env file not found at $BACKEND_ENV_SOURCE"
}

validate_worktree_name() {
    local name="$1"

    [[ "$name" =~ ^[0-9]{4}-[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
        die "Name must begin with a four-digit issue code and hyphen: $name"
    git -C "$MAIN_WORKTREE" check-ref-format --branch "$name" >/dev/null 2>&1 ||
        die "Invalid Git branch name: $name"
}

resolve_tmux_session() {
    local requested_session="${1:-}"
    local sessions=()
    local session

    require_command tmux

    if [ -n "$requested_session" ]; then
        tmux has-session -t "=$requested_session" 2>/dev/null ||
            die "tmux session not found: $requested_session"
        printf '%s\n' "$requested_session"
        return
    fi

    if [ -n "${TMUX_PANE:-}" ]; then
        tmux display-message -p -t "$TMUX_PANE" '#S'
        return
    fi

    while IFS= read -r session; do
        [ -n "$session" ] && sessions+=("$session")
    done < <(tmux list-sessions -F '#S' 2>/dev/null || true)

    if [ "${#sessions[@]}" -eq 1 ]; then
        printf '%s\n' "${sessions[0]}"
        return
    fi

    if [ "${#sessions[@]}" -eq 0 ]; then
        die "No tmux session is running"
    fi

    die "Multiple tmux sessions are running; use --session NAME"
}

ensure_window_name_available() {
    local session="$1"
    local window_name="$2"
    local existing_name

    while IFS= read -r existing_name; do
        if [ "$existing_name" = "$window_name" ]; then
            die "tmux window already exists in session $session: $window_name"
        fi
    done < <(tmux list-windows -t "=$session" -F '#W')
}

create_link() {
    local source="$1"
    local destination="$2"

    if [ -e "$destination" ] || [ -L "$destination" ]; then
        printf 'Error: Refusing to replace existing path: %s\n' "$destination" >&2
        return 1
    fi

    ln -s "$source" "$destination"
}

copy_file() {
    local source="$1"
    local destination="$2"

    if [ -L "$destination" ]; then
        printf 'Error: Refusing to copy through symlink: %s\n' "$destination" >&2
        return 1
    fi

    cp "$source" "$destination"
}

prepare_worktree() {
    local worktree_path="$1"

    create_link "$AGENTS_SOURCE" "$worktree_path/.agents" || return 1
    create_link "$OPENCODE_SOURCE" "$worktree_path/opencode.json" || return 1
    copy_file "$FRONTEND_ENV_SOURCE" "$worktree_path/tdrs-frontend/.env" || return 1
    copy_file "$BACKEND_ENV_SOURCE" "$worktree_path/tdrs-backend/.env" || return 1
}

create_two_pane_window() {
    local session="$1"
    local window_name="$2"
    local worktree_path="$3"
    local left_command="$4"
    local right_command="${5:-}"
    local window_id
    local left_pane
    local right_pane

    window_id=$(tmux new-window -d -P -F '#{window_id}' \
        -t "=$session" -n "$window_name" -c "$worktree_path") || return 1

    left_pane=$(tmux list-panes -t "$window_id" -F '#{pane_id}') || {
        tmux kill-window -t "$window_id" 2>/dev/null || true
        return 1
    }

    right_pane=$(tmux split-window -h -d -P -F '#{pane_id}' \
        -t "$left_pane" -c "$worktree_path") || {
        tmux kill-window -t "$window_id" 2>/dev/null || true
        return 1
    }

    tmux select-layout -t "$window_id" even-horizontal >/dev/null || {
        tmux kill-window -t "$window_id" 2>/dev/null || true
        return 1
    }
    tmux send-keys -t "$left_pane" "$left_command" C-m || {
        tmux kill-window -t "$window_id" 2>/dev/null || true
        return 1
    }
    if [ -n "$right_command" ]; then
        tmux send-keys -t "$right_pane" "$right_command" C-m || {
            tmux kill-window -t "$window_id" 2>/dev/null || true
            return 1
        }
    fi
    tmux select-pane -t "$left_pane" || {
        tmux kill-window -t "$window_id" 2>/dev/null || true
        return 1
    }
    tmux select-window -t "$window_id" || {
        tmux kill-window -t "$window_id" 2>/dev/null || true
        return 1
    }
}

rollback_new_worktree() {
    local worktree_path="$1"
    local branch="${2:-}"

    git -C "$MAIN_WORKTREE" worktree remove --force "$worktree_path" >/dev/null 2>&1 || true
    if [ -n "$branch" ]; then
        git -C "$MAIN_WORKTREE" branch -D "$branch" >/dev/null 2>&1 || true
    fi
}

start_issue() {
    local branch="$1"
    local base="$2"
    local requested_session="$3"
    local worktree_path="$WORKTREE_ROOT/$branch"
    local issue_code="${branch:0:4}"
    local session

    require_command git
    require_command tmux
    require_command nvim
    require_command opencode
    validate_environment
    validate_worktree_name "$branch"
    [ ! -e "$worktree_path" ] || die "Worktree path already exists: $worktree_path"
    git -C "$MAIN_WORKTREE" rev-parse --verify "${base}^{commit}" >/dev/null 2>&1 ||
        die "Base ref does not resolve to a commit: $base"
    if git -C "$MAIN_WORKTREE" show-ref --verify --quiet "refs/heads/$branch"; then
        die "Local branch already exists: $branch"
    fi

    session=$(resolve_tmux_session "$requested_session")
    ensure_window_name_available "$session" "$issue_code"

    printf 'Creating issue worktree %s from %s...\n' "$branch" "$base"
    git -C "$MAIN_WORKTREE" worktree add -b "$branch" "$worktree_path" "$base"

    if ! prepare_worktree "$worktree_path"; then
        rollback_new_worktree "$worktree_path" "$branch"
        die "Worktree preparation failed; rolled back $branch"
    fi

    if ! create_two_pane_window "$session" "$issue_code" "$worktree_path" "nvim" "opencode"; then
        rollback_new_worktree "$worktree_path" "$branch"
        die "tmux setup failed; rolled back $branch"
    fi

    printf 'Issue workspace ready: %s\n' "$worktree_path"
}

normalize_remote_branch() {
    local remote="$1"
    local branch="$2"

    branch="${branch#refs/remotes/$remote/}"
    branch="${branch#$remote/}"
    printf '%s\n' "$branch"
}

start_review() {
    local branch_input="$1"
    local remote="$2"
    local task_target="$3"
    local requested_session="$4"
    local branch
    local branch_name
    local worktree_name
    local worktree_path
    local issue_code
    local session
    local review_commit
    local task_command

    require_command git
    require_command tmux
    require_command task
    validate_environment

    branch=$(normalize_remote_branch "$remote" "$branch_input")
    git -C "$MAIN_WORKTREE" check-ref-format --branch "$branch" >/dev/null 2>&1 ||
        die "Invalid Git branch name: $branch"
    branch_name="${branch##*/}"
    validate_worktree_name "$branch_name"
    worktree_name="$branch_name"
    [[ "$task_target" =~ ^[A-Za-z0-9:_-]+$ ]] || die "Invalid Taskfile target: $task_target"

    worktree_path="$WORKTREE_ROOT/$worktree_name"
    issue_code="${branch_name:0:4}"
    [ ! -e "$worktree_path" ] || die "Worktree path already exists: $worktree_path"

    session=$(resolve_tmux_session "$requested_session")
    ensure_window_name_available "$session" "R-$issue_code"

    printf 'Fetching %s/%s...\n' "$remote" "$branch"
    git -C "$MAIN_WORKTREE" fetch "$remote" "$branch"
    review_commit=$(git -C "$MAIN_WORKTREE" rev-parse --verify 'FETCH_HEAD^{commit}')

    printf 'Creating detached review worktree at %s...\n' "$review_commit"
    git -C "$MAIN_WORKTREE" worktree add --detach "$worktree_path" "$review_commit"

    if ! prepare_worktree "$worktree_path"; then
        rollback_new_worktree "$worktree_path"
        die "Worktree preparation failed; rolled back review workspace"
    fi

    printf -v task_command 'task %q' "$task_target"
    if ! create_two_pane_window "$session" "R-$issue_code" "$worktree_path" "$task_command"; then
        rollback_new_worktree "$worktree_path"
        die "tmux setup failed; rolled back review workspace"
    fi

    printf 'Review workspace ready: %s\n' "$worktree_path"
}

is_registered_worktree() {
    local candidate="$1"
    local line

    while IFS= read -r line; do
        if [ "${line#worktree }" != "$line" ] && [ "${line#worktree }" = "$candidate" ]; then
            return 0
        fi
    done < <(git -C "$MAIN_WORKTREE" worktree list --porcelain)

    return 1
}

resolve_worktree_path() {
    local input="$1"
    local candidate
    local matches=()
    local path

    if [[ "$input" = /* ]]; then
        candidate="${input%/}"
    else
        candidate="$WORKTREE_ROOT/${input%/}"
    fi

    if is_registered_worktree "$candidate"; then
        printf '%s\n' "$candidate"
        return
    fi

    if [[ "$input" =~ ^[0-9]{4}$ ]]; then
        while IFS= read -r path; do
            case "${path##*/}" in
                "$input"-*) matches+=("$path") ;;
            esac
        done < <(registered_worktree_paths)

        if [ "${#matches[@]}" -eq 1 ]; then
            printf '%s\n' "${matches[0]}"
            return
        fi
        if [ "${#matches[@]}" -gt 1 ]; then
            die "Multiple worktrees match issue $input; provide the full worktree name"
        fi
    fi

    die "Registered worktree not found: $input"
}

registered_worktree_paths() {
    local line

    while IFS= read -r line; do
        if [ "${line#worktree }" != "$line" ]; then
            printf '%s\n' "${line#worktree }"
        fi
    done < <(git -C "$MAIN_WORKTREE" worktree list --porcelain)
}

tmux_windows_for_worktree() {
    local session="$1"
    local worktree_path="$2"
    local line
    local window_id
    local pane_path
    local found_ids="|"

    while IFS='|' read -r window_id pane_path; do
        case "$pane_path" in
            "$worktree_path"|"$worktree_path"/*)
                if [[ "$found_ids" != *"|$window_id|"* ]]; then
                    printf '%s\n' "$window_id"
                    found_ids="${found_ids}${window_id}|"
                fi
                ;;
        esac
    done < <(tmux list-panes -s -t "=$session" -F '#{window_id}|#{pane_current_path}')
}

finish_worktree() {
    local input="$1"
    local delete_branch="$2"
    local force="$3"
    local requested_session="$4"
    local worktree_path
    local branch=""
    local session
    local windows=()
    local window_id
    local delete_args=(-d)
    local branch_delete_failed="false"

    require_command git
    require_command tmux
    [ -d "$MAIN_WORKTREE/.git" ] || die "Main worktree not found at $MAIN_WORKTREE"

    worktree_path=$(resolve_worktree_path "$input")
    [ "$worktree_path" != "$MAIN_WORKTREE" ] || die "Refusing to remove the main worktree"

    if branch=$(git -C "$worktree_path" symbolic-ref --quiet --short HEAD 2>/dev/null); then
        :
    else
        branch=""
    fi

    if [ -n "$(git -C "$worktree_path" status --porcelain)" ] && [ "$force" != "true" ]; then
        die "Worktree has uncommitted changes; commit them or rerun with --force"
    fi

    session=$(resolve_tmux_session "$requested_session")
    while IFS= read -r window_id; do
        [ -n "$window_id" ] && windows+=("$window_id")
    done < <(tmux_windows_for_worktree "$session" "$worktree_path")

    if [ "$force" = "true" ]; then
        delete_args=(-D)
    fi

    printf 'Removing worktree: %s\n' "$worktree_path"
    if [ "$force" = "true" ]; then
        git -C "$MAIN_WORKTREE" worktree remove --force "$worktree_path"
    else
        git -C "$MAIN_WORKTREE" worktree remove "$worktree_path"
    fi

    if [ "$delete_branch" = "true" ] && [ -n "$branch" ]; then
        if ! git -C "$MAIN_WORKTREE" branch "${delete_args[@]}" "$branch"; then
            branch_delete_failed="true"
        fi
    fi

    if [ "${#windows[@]}" -gt 0 ]; then
        for window_id in "${windows[@]}"; do
            tmux kill-window -t "$window_id"
        done
    fi

    if [ "${#windows[@]}" -eq 0 ]; then
        printf 'No tmux window in session %s was rooted in that worktree.\n' "$session"
    fi
    if [ "$branch_delete_failed" = "true" ]; then
        die "Worktree was removed, but local branch was preserved because Git refused to delete it: $branch"
    fi
    printf 'Worktree removed.\n'
}

list_worktrees() {
    require_command git
    [ -d "$MAIN_WORKTREE/.git" ] || die "Main worktree not found at $MAIN_WORKTREE"
    git -C "$MAIN_WORKTREE" worktree list
}

prompt_value() {
    local prompt="$1"
    local default_value="${2:-}"
    local value

    if [ -n "$default_value" ]; then
        read -r -p "$prompt [$default_value]: " value
        printf '%s\n' "${value:-$default_value}"
    else
        read -r -p "$prompt: " value
        [ -n "$value" ] || die "$prompt is required"
        printf '%s\n' "$value"
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local answer

    read -r -p "$prompt [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

choose_worktree() {
    local worktrees=()
    local path
    local selection

    while IFS= read -r path; do
        [ "$path" != "$MAIN_WORKTREE" ] && worktrees+=("$path")
    done < <(registered_worktree_paths)

    [ "${#worktrees[@]}" -gt 0 ] || die "No removable worktrees found"

    printf 'Choose a worktree:\n' >&2
    select selection in "${worktrees[@]}"; do
        if [ -n "${selection:-}" ]; then
            printf '%s\n' "$selection"
            return
        fi
        printf 'Invalid selection.\n' >&2
    done
}

interactive_menu() {
    local choice
    local branch
    local base
    local remote
    local task_target
    local worktree
    local delete_branch="false"
    local force="false"

    PS3="Select a workflow: "
    select choice in "Start issue" "Review pull request" "Finish worktree" "List worktrees" "Exit"; do
        case "$choice" in
            "Start issue")
                branch=$(prompt_value "Issue branch/worktree name")
                base=$(prompt_value "Base ref" "$DEFAULT_BASE")
                start_issue "$branch" "$base" ""
                return
                ;;
            "Review pull request")
                branch=$(prompt_value "Remote branch name")
                remote=$(prompt_value "Git remote" "$DEFAULT_REMOTE")
                task_target=$(prompt_value "Local deployment Taskfile target" "$DEFAULT_REVIEW_TASK")
                start_review "$branch" "$remote" "$task_target" ""
                return
                ;;
            "Finish worktree")
                worktree=$(choose_worktree)
                if prompt_yes_no "Delete its local branch too?"; then
                    delete_branch="true"
                fi
                if [ -n "$(git -C "$worktree" status --porcelain)" ]; then
                    if prompt_yes_no "Worktree is dirty. Force removal?"; then
                        force="true"
                    fi
                fi
                finish_worktree "$worktree" "$delete_branch" "$force" ""
                return
                ;;
            "List worktrees")
                list_worktrees
                return
                ;;
            "Exit")
                return
                ;;
            *)
                printf 'Invalid selection.\n' >&2
                ;;
        esac
    done
}

parse_issue() {
    local branch=""
    local base="$DEFAULT_BASE"
    local session=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --base)
                [ "$#" -ge 2 ] || die "--base requires a value"
                base="$2"
                shift 2
                ;;
            --session)
                [ "$#" -ge 2 ] || die "--session requires a value"
                session="$2"
                shift 2
                ;;
            -h|--help)
                usage
                return
                ;;
            --*)
                die "Unknown issue option: $1"
                ;;
            *)
                [ -z "$branch" ] || die "Only one issue branch may be specified"
                branch="$1"
                shift
                ;;
        esac
    done

    [ -n "$branch" ] || die "issue requires BRANCH"
    start_issue "$branch" "$base" "$session"
}

parse_review() {
    local branch=""
    local remote="$DEFAULT_REMOTE"
    local task_target="$DEFAULT_REVIEW_TASK"
    local session=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --remote)
                [ "$#" -ge 2 ] || die "--remote requires a value"
                remote="$2"
                shift 2
                ;;
            --task)
                [ "$#" -ge 2 ] || die "--task requires a value"
                task_target="$2"
                shift 2
                ;;
            --session)
                [ "$#" -ge 2 ] || die "--session requires a value"
                session="$2"
                shift 2
                ;;
            -h|--help)
                usage
                return
                ;;
            --*)
                die "Unknown review option: $1"
                ;;
            *)
                [ -z "$branch" ] || die "Only one review branch may be specified"
                branch="$1"
                shift
                ;;
        esac
    done

    [ -n "$branch" ] || die "review requires REMOTE_BRANCH"
    start_review "$branch" "$remote" "$task_target" "$session"
}

parse_finish() {
    local worktree=""
    local delete_branch="false"
    local force="false"
    local session=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --delete-branch)
                delete_branch="true"
                shift
                ;;
            --force)
                force="true"
                shift
                ;;
            --session)
                [ "$#" -ge 2 ] || die "--session requires a value"
                session="$2"
                shift 2
                ;;
            -h|--help)
                usage
                return
                ;;
            --*)
                die "Unknown finish option: $1"
                ;;
            *)
                [ -z "$worktree" ] || die "Only one worktree may be specified"
                worktree="$1"
                shift
                ;;
        esac
    done

    [ -n "$worktree" ] || die "finish requires WORKTREE"
    finish_worktree "$worktree" "$delete_branch" "$force" "$session"
}

main() {
    local command="${1:-}"

    if [ "$#" -eq 0 ]; then
        interactive_menu
        return
    fi
    shift

    case "$command" in
        issue)
            parse_issue "$@"
            ;;
        review)
            parse_review "$@"
            ;;
        finish)
            parse_finish "$@"
            ;;
        list)
            [ "$#" -eq 0 ] || die "list does not accept arguments"
            list_worktrees
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            die "Unknown command: $command. Run with --help for usage."
            ;;
    esac
}

main "$@"
