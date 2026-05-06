---
name: lint
description: Run linters (flake8 for backend, eslint for frontend) and automatically fix any errors found
user_invocable: true
---

# Lint Fixer Skill

Run linters for the TDP project and automatically fix any errors found in the code.

## Usage

Invoke with `/lint` followed by optional arguments:

- `/lint` - Run both backend and frontend linters, fix all errors
- `/lint backend` - Run only backend linter (flake8), fix errors
- `/lint frontend` - Run only frontend linter (eslint), fix errors

## Lint Execution Method

**Use tmux to run linters in a separate pane** - this prevents blocking and captures full output.

**CRITICAL: Always use absolute pane IDs, never relative references like `{right}`.**

```bash
# Step 1: Create pane and capture its absolute ID
AGENT_TMUX_PANE_ID=$(tmux split-window -d -h -P -F '#{pane_id}' "<lint-command> 2>&1; tmux wait-for -S lint-done; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"

# Step 2: Wait for completion and capture ENTIRE output using the pane ID from step 1
tmux wait-for lint-done && tmux capture-pane -t "$AGENT_TMUX_PANE_ID" -p -S -

# Step 3: Kill pane when done analyzing (using the same pane ID)
tmux kill-pane -t "$AGENT_TMUX_PANE_ID"
```

**Key points:**
- **Use `-P -F '#{pane_id}'`** with `split-window` to print the new pane's absolute ID (e.g. `%15`). Read this from the command output and use it in all subsequent tmux commands.
- **Never use `{right}`, `{left}`, or other relative pane references** — they depend on which pane the user has focused.
- Set `history-limit 500000` on the pane immediately after creation to prevent tmux from evicting output (default is ~2000 lines)
- Use `-S -` to capture the ENTIRE pane scrollback (not `-S -500` which truncates)
- Use unique signal names (`lint-done`, `lint-done-be`, `lint-done-fe`) when running both linters

## Backend Lint (flake8)

**Command:**
```bash
task backend-lint
```

This runs `flake8 .` inside the backend Docker container. Flake8 checks Python style and common errors.

**Example:**
```bash
AGENT_TMUX_PANE_ID=$(tmux split-window -d -h -P -F '#{pane_id}' "task backend-lint 2>&1; tmux wait-for -S lint-done-be; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"
```

**Flake8 output format:**
```
./path/to/file.py:42:80: E501 line too long (95 > 79 characters)
./path/to/file.py:10:1: F401 'os' imported but unused
./path/to/file.py:25:5: E303 too many blank lines (3)
```

Each line is: `file:line:column: CODE message`

**Common flake8 error codes:**
| Code | Category | Description |
|------|----------|-------------|
| E1xx | Indentation | Incorrect indentation |
| E2xx | Whitespace | Extraneous whitespace |
| E3xx | Blank lines | Too many/few blank lines |
| E4xx | Imports | Import formatting |
| E5xx | Line length | Line too long (E501) |
| E7xx | Statements | Multiple statements, comparisons |
| W291 | Whitespace | Trailing whitespace |
| W292 | No newline | No newline at end of file |
| W293 | Whitespace | Whitespace before comment |
| F401 | pyflakes | Module imported but unused |
| F811 | pyflakes | Redefinition of unused name |
| F841 | pyflakes | Local variable assigned but never used |

## Frontend Lint (eslint)

**Command:**
```bash
task frontend-lint
```

This runs `yarn lint` inside the frontend Docker container. ESLint checks JavaScript/JSX style and common errors.

**Example:**
```bash
AGENT_TMUX_PANE_ID=$(tmux split-window -d -h -P -F '#{pane_id}' "task frontend-lint 2>&1; tmux wait-for -S lint-done-fe; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"
```

**ESLint output format:**
```
/app/src/components/Header/Header.jsx
  10:5  error  'unused' is defined but never used  no-unused-vars
  25:1  warning  Unexpected console statement       no-console
```

## Execution Steps

1. **Determine scope** from user request:
   - `/lint` or `/lint both` → run both backend and frontend
   - `/lint backend` → backend only
   - `/lint frontend` → frontend only

2. **Run the linter(s) in tmux pane(s)**:
   - If running both, run them sequentially using unique signal names (`lint-done-be`, `lint-done-fe`)
   - If running one, use signal name `lint-done`

3. **Wait and capture complete output**

4. **Analyze the output**:
   - If no errors found → report success, done
   - If errors found → parse each error, fix the code

5. **Fix errors in the source code**:
   - Read each file with errors
   - Edit each file with the normal file editing mechanism
   - Group fixes by file for efficiency
   - Apply fixes that are safe and correct

6. **Re-run the linter** to verify fixes:
   - Run the same linter again in a new tmux pane
   - If new errors appear, fix them
   - Repeat until the linter passes clean

7. **Report results**

### Running Both Linters

When running both backend and frontend, run them sequentially:

```bash
# Backend first
AGENT_TMUX_PANE_ID=$(tmux split-window -d -h -P -F '#{pane_id}' "task backend-lint 2>&1; tmux wait-for -S lint-done-be; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"

# Wait and capture
tmux wait-for lint-done-be && tmux capture-pane -t "$AGENT_TMUX_PANE_ID" -p -S -

# Kill pane
tmux kill-pane -t "$AGENT_TMUX_PANE_ID"

# Fix backend errors...

# Then frontend
AGENT_TMUX_PANE_ID=$(tmux split-window -d -h -P -F '#{pane_id}' "task frontend-lint 2>&1; tmux wait-for -S lint-done-fe; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"

# Wait and capture
tmux wait-for lint-done-fe && tmux capture-pane -t "$AGENT_TMUX_PANE_ID" -p -S -

# Kill pane
tmux kill-pane -t "$AGENT_TMUX_PANE_ID"

# Fix frontend errors...
```

## Lint Report Format

### Summary
- **Backend**: PASSED / X errors found and fixed
- **Frontend**: PASSED / X errors found and fixed
- Status: **ALL CLEAN** or **FIXED**

### Errors Fixed (if any)
For each file:
- **File**: `path/to/file.py`
- **Fixes applied**: List of error codes and what was changed

### Remaining Issues (if any)
Errors that could not be auto-fixed (e.g., complex logic changes needed):
- **File**: `path/to/file.py:42`
- **Error**: Description
- **Reason**: Why it couldn't be auto-fixed
- **Suggestion**: How the user can fix it manually

## Fix Strategies

### Backend (flake8)

| Code | Fix Strategy |
|------|-------------|
| E501 | Break long lines at logical points (after commas, operators) |
| E302/E303 | Add or remove blank lines |
| E231 | Add missing whitespace after comma/colon |
| E251 | Remove whitespace around `=` in keyword args |
| E261/E262 | Fix inline comment spacing |
| E271 | Fix multiple spaces after keyword |
| W291/W293 | Remove trailing whitespace |
| W292 | Add newline at end of file |
| F401 | Remove unused import |
| F811 | Remove duplicate definition or rename |
| F841 | Remove unused variable or prefix with `_` |

### Frontend (eslint)

| Rule | Fix Strategy |
|------|-------------|
| no-unused-vars | Remove unused variable/import |
| no-console | Remove console statement or add eslint-disable comment if intentional |
| semi | Add or remove semicolons |
| quotes | Fix quote style |
| indent | Fix indentation |
| eqeqeq | Replace `==` with `===` |
| no-trailing-spaces | Remove trailing whitespace |
| comma-dangle | Add or remove trailing commas |
| react/prop-types | Add PropTypes or add eslint-disable if not needed |

## Constraints

- **ALWAYS** fix errors in the actual source code, not test files (unless the lint error is in a test file)
- **ALWAYS** re-run the linter after fixes to verify they're clean
- **ALWAYS** use `-S -` to capture full output (not `-S -500`)
- **ALWAYS** report what was fixed and what couldn't be fixed
- **NEVER** suppress lint errors with disable comments unless the fix would change behavior
- **NEVER** make functional changes to code — only fix style/lint issues
- **Preserve the intent** of the original code when reformatting
- **File paths in flake8 output** start with `./` and are relative to `tdrs-backend/` — prepend `tdrs-backend/` when reading/editing files
