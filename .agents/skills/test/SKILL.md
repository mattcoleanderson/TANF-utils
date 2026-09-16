---
name: test
description: Run TANF-app tests in tmux. Use whenever executing, rerunning, or diagnosing backend pytest, frontend Jest, or e2e Cypress tests, including verification after code changes; load this skill before issuing any such test command.
user_invocable: true
---

# Test Runner Skill

Execute tests for the TDP (TANF Data Portal) project and provide comprehensive, actionable test reports.

## Usage

Invoke with `/test` followed by optional arguments:

- `/test` - Prompts for what to test
- `/test backend` - Run all backend tests
- `/test frontend` - Run all frontend tests
- `/test e2e` - Run all Cypress e2e tests
- `/test backend tdpservice/reports/` - Run backend tests for specific module
- `/test frontend Header` - Run frontend tests matching "Header"
- `/test e2e feedback-reports` - Run e2e tests matching a spec pattern
- `/test backend-cov` - Run backend tests with coverage
- `/test frontend-cov` - Run frontend tests with coverage

## Test Execution Method

**Use tmux to run tests in a separate pane** - this prevents blocking and allows faster feedback.

**CRITICAL: Create the pane relative to `$TMUX_PANE`, then use absolute pane IDs for every subsequent operation.**
Without `-t "$TMUX_PANE"`, `split-window` resolves against the currently active tmux client and can open in another LLM's window if the user changes focus. `$TMUX_PANE` is inherited from the pane running the calling LLM, so always pass it as the split target. Relative references (e.g. `{right}`, `{left}`) also resolve based on the currently focused pane. Capture the new pane's absolute ID (`%NN`) at creation time using `-P -F '#{pane_id}'` and use that ID for all subsequent operations.

```bash
# Step 1: Create pane and capture its absolute ID
AGENT_TMUX_PANE_ID=$(tmux split-window -t "$TMUX_PANE" -d -h -P -F '#{pane_id}' "<test-command> 2>&1; tmux wait-for -S test-done; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"

# Step 2: Wait for completion and capture ENTIRE output using the pane ID from step 1
tmux wait-for test-done && tmux capture-pane -t "$AGENT_TMUX_PANE_ID" -p -S -

# Step 3: Kill pane when done analyzing (using the same pane ID)
tmux kill-pane -t "$AGENT_TMUX_PANE_ID"
```

**Key points:**
- **Always pass `-t "$TMUX_PANE"` to `split-window`** so the test pane opens in the calling LLM's window, regardless of which window the user is viewing.
- **Use `-P -F '#{pane_id}'`** with `split-window` to print the new pane's absolute ID (e.g. `%15`). Read this from the command output and use it in all subsequent tmux commands.
- **Never use `{right}`, `{left}`, or other relative pane references** — they depend on which pane the user has focused.
- Set `history-limit 500000` on the pane immediately after creation to prevent tmux from evicting output (default is ~2000 lines)
- Use `-S -` to capture the ENTIRE pane scrollback (not `-S -500` which truncates)
- Do NOT pipe through `tail` - you need the complete output
- Use unique signal names (test-done, test-done-2, etc.) if running multiple test sessions

## Backend Tests (pytest)

**Example:**
```bash
# Start backend tests and capture pane ID
AGENT_TMUX_PANE_ID=$(tmux split-window -t "$TMUX_PANE" -d -h -P -F '#{pane_id}' "task backend-pytest PYTEST_ARGS='tdpservice/reports/test/ -v' 2>&1; tmux wait-for -S test-done; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"

# Wait and capture ALL output (use pane ID from step above, e.g. %15)
tmux wait-for test-done && tmux capture-pane -t "$AGENT_TMUX_PANE_ID" -p -S -

# Clean up
tmux kill-pane -t "$AGENT_TMUX_PANE_ID"
```

**Command patterns:**
- All tests: `task backend-pytest`
- Specific folder: `task backend-pytest PYTEST_ARGS="tdpservice/reports/test/ -v"`
- Specific file: `task backend-pytest PYTEST_ARGS="tdpservice/reports/test/test_models.py -v"`
- Specific test: `task backend-pytest PYTEST_ARGS="tdpservice/reports/test/test_models.py::TestClass::test_method -v"`
- With markers: `task backend-pytest PYTEST_ARGS="-m django_db tdpservice/reports/test/"`
- Verbose output: `task backend-pytest PYTEST_ARGS="tdpservice/reports/test/ -s -vv"`
- With coverage: `task backend-pytest-cov`

**Test location:** `tdrs-backend/tdpservice/*/test/`

**Pytest output markers:**
- `PASSED` - Test succeeded
- `FAILED` - Test failed (look for assertion details)
- `ERROR` - Test errored during setup/teardown
- `SKIPPED` - Test was skipped
- Summary line: `X passed, Y failed, Z errors in N.NNs`

## Frontend Tests (Jest)

**CRITICAL: ALWAYS include `--watchAll=false`** - without this, Jest enters watch mode and waits forever for input.

**Example:**
```bash
# Start frontend tests and capture pane ID
AGENT_TMUX_PANE_ID=$(tmux split-window -t "$TMUX_PANE" -d -h -P -F '#{pane_id}' "task frontend-test JEST_ARGS='--watchAll=false --testPathPattern=ComponentName' 2>&1; tmux wait-for -S test-done; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"

# Wait and capture ALL output (use pane ID from step above, e.g. %15)
tmux wait-for test-done && tmux capture-pane -t "$AGENT_TMUX_PANE_ID" -p -S -

# Clean up
tmux kill-pane -t "$AGENT_TMUX_PANE_ID"
```

**Command patterns:**
- All tests: `task frontend-test JEST_ARGS="--watchAll=false"`
- Specific pattern: `task frontend-test JEST_ARGS="--watchAll=false --testPathPattern=ComponentName"`
- Multiple patterns: `task frontend-test JEST_ARGS="--watchAll=false --testPathPattern='(Component1|Component2)'"`
- Filter by test name: `task frontend-test JEST_ARGS="--watchAll=false --testNamePattern='handles click'"`
- With coverage: `task frontend-test-cov JEST_ARGS="--watchAll=false"`

**Test location:** `tdrs-frontend/src/**/*.test.js` and `*.test.jsx`

**Jest output markers:**
- `PASS` - Test suite passed
- `FAIL` - Test suite failed
- Summary line: `Tests: X passed, Y failed, Z total`
- `Test Suites: X passed, Y failed, Z total`

## E2E Tests (Cypress)

E2e tests use Cypress with cucumber/gherkin `.feature` files. They run headless via `npx cypress run` from the `tdrs-frontend/` directory.

**IMPORTANT: Before running e2e tests, ALWAYS run `task e2e-env-var-setup` first** to set up test users and seed data. This must complete before Cypress starts.

**Example:**
```bash
# Step 1: Set up e2e environment (run inline, must complete before Cypress)
task e2e-env-var-setup

# Step 2: Start Cypress in tmux pane and capture pane ID
AGENT_TMUX_PANE_ID=$(tmux split-window -t "$TMUX_PANE" -d -h -P -F '#{pane_id}' "cd /Users/matt.anderson/repos/work/TANF-app/tdrs-frontend && CYPRESS_TOKEN=local-cypress-token npx cypress run --headless 2>&1; tmux wait-for -S test-done; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"

# Step 3: Wait and capture ALL output (use pane ID from step above, e.g. %15)
tmux wait-for test-done && tmux capture-pane -t "$AGENT_TMUX_PANE_ID" -p -S -

# Step 4: Clean up
tmux kill-pane -t "$AGENT_TMUX_PANE_ID"
```

**Command patterns:**
- All e2e tests: `npx cypress run --headless`
- Specific spec by pattern: `npx cypress run --headless --spec "cypress/e2e/feedback-reports/**"`
- Specific feature file: `npx cypress run --headless --spec "cypress/e2e/feedback-reports/admin-feedback-reports.feature"`

**CRITICAL: Always `cd` into `tdrs-frontend/` and set `CYPRESS_TOKEN=local-cypress-token` in the tmux command.**

**Test location:** `tdrs-frontend/cypress/e2e/**/*.feature`

**Available e2e test suites:**
- `accounts/` - Account management tests
- `data-files/` - File upload and submission history tests
- `feedback/` - User feedback tests
- `feedback-reports/` - Admin feedback reports tests
- `profile/` - Profile editing tests

**Cypress output markers:**
- `✓` or `passing` - Test passed
- `✗` or `failing` - Test failed
- Summary line: `X passing, Y failing`
- `Run Finished` section shows final results table

## Execution Steps

1. **Determine test type** from user request:
   - Python/Django files → backend tests
   - React/JavaScript files → frontend tests
   - Cypress/e2e/feature files → e2e tests
   - If unclear, ask the user

2. **Construct the command**:
   - Backend: `task backend-pytest PYTEST_ARGS="<path> -v"`
   - Frontend: `task frontend-test JEST_ARGS="--watchAll=false --testPathPattern=<pattern>"`
   - E2E: First `task e2e-env-var-setup`, then `cd tdrs-frontend && CYPRESS_TOKEN=local-cypress-token npx cypress run --headless [--spec "<pattern>"]`

3. **For e2e tests, run setup first** (before the tmux pane):
   ```bash
   task e2e-env-var-setup
   ```

4. **Start test in tmux pane and capture pane ID**:
   ```bash
   AGENT_TMUX_PANE_ID=$(tmux split-window -t "$TMUX_PANE" -d -h -P -F '#{pane_id}' "<command> 2>&1; tmux wait-for -S test-done; sleep 999") && tmux set-option -t "$AGENT_TMUX_PANE_ID" -p history-limit 500000 && echo "$AGENT_TMUX_PANE_ID"
   ```

5. **Wait and capture complete output** (use pane ID from step 4):
   ```bash
   tmux wait-for test-done && tmux capture-pane -t "$AGENT_TMUX_PANE_ID" -p -S -
   ```

6. **Clean up and report**:
   ```bash
   tmux kill-pane -t "$AGENT_TMUX_PANE_ID"
   ```
   Then analyze output and provide report.

## Test Report Format

### Executive Summary
- Total tests: X
- Passed: X | Failed: X | Skipped: X
- Execution time: X.XXs
- Status: **PASSED** or **FAILED**

### Failed Tests (if any)
For each failure:
- **Test**: `path/to/test.py::TestClass::test_method`
- **Error**: AssertionError / TypeError / etc.
- **Message**: The actual error message
- **Fix suggestion**: Actionable recommendation

### Recommendations
- Next steps for fixing failures
- Related tests to run
- Potential root causes

## Common Failure Patterns

### Backend (Python/Django)
| Error | Likely Cause | Fix |
|-------|--------------|-----|
| `ModuleNotFoundError` | Missing import or package | Check imports, run `pipenv install` |
| `django.db.utils.*` | Database issue | Run `task backend-exec CMD="migrate"` |
| `AssertionError` | Test expectation wrong | Compare expected vs actual values |
| `FixtureError` | Missing fixture | Check `conftest.py` for fixture |
| `AttributeError` | Object missing attribute | Check model/class definition |

### Frontend (React/Jest)
| Error | Likely Cause | Fix |
|-------|--------------|-----|
| `TestingLibraryElementError` | Element not found | Check selectors, use `screen.debug()` |
| `TypeError: Cannot read property` | Null/undefined access | Check component props/state |
| `Snapshot mismatch` | UI changed | Verify change is intentional, update with `-u` |
| `act() warning` | Async state update | Wrap in `waitFor` or use `findBy*` |
| `Mock function not called` | Mock setup issue | Verify mock is properly configured |

### E2E (Cypress)
| Error | Likely Cause | Fix |
|-------|--------------|-----|
| `CypressError: Timed out` | Element not found or not visible | Check selectors, increase timeout, verify app state |
| `cy.visit() failed` | App not running or wrong URL | Ensure `task up` has been run (both frontend and backend) |
| `Step implementation missing` | Cucumber step not defined | Add step definition in the corresponding `.js` file |
| `ECONNREFUSED` | Backend/frontend not running | Run `task up` to start both services |
| `401 Unauthorized` | Test user not set up | Re-run `task e2e-env-var-setup` |

## Constraints

- **MAY** modify test files or source code when this skill is part of a fix workflow.
- **Prefer fixing tests first** when failures occur. Assume the current application behavior is correct unless the failure output and surrounding code clearly show a source-code defect.
- **Modify source code only as a last resort** after confirming the test expectation is already correct or the implementation is demonstrably broken.
- **NEVER** skip reporting failures
- **ALWAYS** use `-S -` to capture full output (not `-S -500`)
- **ALWAYS** include `--watchAll=false` for frontend tests
- **ALWAYS** provide fix suggestions for failures
- **ALWAYS** report the complete test summary
