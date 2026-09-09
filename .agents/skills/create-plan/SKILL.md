---
name: create-plan
description: Create a researched, phased implementation plan for TANF-app GitHub issues. Use when the user asks to plan an issue or provides issue/PR URLs and wants a branch-named markdown plan under .agents/plans with test gates, manual review pauses, and commit messages.
user_invocable: true
---

# Create Implementation Plan

Research a TANF-app issue and write an implementation-ready plan. Do not implement the issue while using this skill.

## Usage

Invoke with the primary issue and any related context:

```text
/create-plan https://github.com/raft-tech/TANF-app/issues/1234
/create-plan <frontend-issue-url> related backend issue <issue-url> and PR <pr-url>
```

Use issue and PR URLs already present in the conversation when the invocation does not repeat them. Ask one concise question only when the primary issue cannot be identified.

## Defaults

- Read the current branch with `git branch --show-current`.
- Write the plan to `.agents/plans/<current-branch>.md`.
- Treat each phase as a safe, independently committable change.
- Put behavior tests in the same phase as the behavior they protect.
- Run automated tests after each phase, then stop for the user's manual testing and manual commit.
- Give the user one concise suggested commit message for every phase.
- Never commit, push, create a PR, or implement application code as part of plan creation.

## Research Workflow

1. Read repository instructions and context before forming a solution:
   - Root and nearest `AGENTS.md` files.
   - `CONTEXT-MAP.md`, root `CONTEXT.md`, and each affected subsystem's `CONTEXT.md`.
   - Run `task --list` before naming Taskfile commands.
2. Inspect repository state:
   - Current branch.
   - `git status --short --branch`.
   - Recent commits when branch ancestry or an existing dependency branch matters.
   - Existing plans under `.agents/plans` for formatting and related decisions.
3. Fetch every linked GitHub issue and PR with `gh`:
   - Issue title, body, acceptance criteria, comments, labels, state, and URL.
   - PR title, body, base/head branches, files, commits, reviews, comments, state, and URL.
   - Fetch inline review comments with the GitHub API when they can change the contract or planned approach.
4. Trace the code instead of relying only on ticket wording:
   - Find every production use of affected fields, models, endpoints, components, selectors, and constants.
   - Find nearby unit, integration, e2e, fixture, factory, mock, and documentation coverage.
   - Inspect both sides of an API contract when the issue crosses frontend/backend boundaries.
   - Distinguish similarly named fields with different meanings; do not propose mechanical replacements.
   - Identify direct and indirect dependencies, URL/deep-link paths, role/permission behavior, malformed-data behavior, and migration/seed behavior.
5. Compare the issue requirements with the actual implementation:
   - Record confirmed behavior and API shapes.
   - Surface missing backend support, unstable contracts, unsafe authorization assumptions, data migration gaps, and unresolved product decisions.
   - Do not hide blockers behind frontend fallbacks that would violate acceptance criteria.
6. Use parallel exploration for independent areas such as frontend flow, backend contract, and tests. Review the final plan for factual accuracy and unsafe phase boundaries before finishing.

## Phase Design Rules

- A phase must leave the branch in a correct, testable state suitable for a commit.
- Never create an intermediate phase that exposes a capability before its permission or safety guard is implemented.
- Prefer the smallest complete vertical behavior slice over separate source-only and test-only phases.
- State dependencies as entry gates. If a phase cannot work with the current API or data, mark it blocked and describe the exact prerequisite.
- Name the likely files and symbols, but allow implementation to choose a smaller equivalent change when appropriate.
- Include behavior, edge cases, regression coverage, and cleanup in the relevant phase.
- Preserve compatibility only when the codebase has a concrete need for it.
- Keep final documentation, e2e, accessibility, lint, coverage, and release-readiness work in a final commit-sized phase when applicable.

Every phase must contain:

1. A short title and logical commit scope.
2. An implementation checklist.
3. Exact focused automated test commands using known repository tasks or skills.
4. A numbered manual test gate with expected outcomes.
5. A suggested imperative commit message.
6. A `Notes` section for implementation results and discovered follow-ups.

## Required Plan Structure

Use this structure unless the issue clearly needs fewer sections:

```markdown
# Issue <number> <Short Title> Phase Plan

Branch: `<current-branch>`
Issue: <primary-issue-url>
Related issue/PR: <urls when present>
Created: YYYY-MM-DD

## Goal

<User-visible and technical outcome.>

## Confirmed Behavior And Contract

- <Facts established from code and linked work.>

## Dependencies And Decisions Required Before Implementation

1. **<Gate>.** <Exact prerequisite or decision.>

## Plan Maintenance Instructions

After each implementation phase:

- Check off completed tasks and add `(completed YYYY-MM-DD)`.
- Record exact automated test commands and results under `Notes`.
- Give the user the suggested commit message.
- Stop and wait for manual testing and the user's manual commit.
- Do not start the next phase until the user explicitly continues.

## Phase 1: <Safe Commit Scope>

Logical commit scope: <one independently correct behavior slice>.

### Implementation

- [ ] <Specific task with file/symbol references.>

### Automated Tests

```bash
<focused repository command>
```

### Manual Test Gate

1. <Action and expected result.>

Suggested commit message: `<imperative message>`

Notes:

## Final Phase: Integration Coverage And Verification

<E2E, full regression, lint, accessibility, docs, and release requirements.>

## Expected File Changes

- `<path>` - <expected responsibility>
```

## Verification Before Returning

1. Confirm the filename exactly matches the current branch plus `.md`.
2. Re-read the plan and confirm every acceptance criterion is addressed or explicitly blocked.
3. Confirm each phase includes automated tests, a manual test gate, a pause, and a commit message.
4. Confirm no phase creates an unsafe or incomplete intermediate behavior.
5. Run a whitespace/error check appropriate for the plan's real filesystem location. `.agents` may be a symlink, so preserve it and validate the target without replacing the link.
6. Report the plan path and summarize important blockers. State that application tests were not run because this workflow only created documentation.

## Safety

- Modify only the new or existing plan file unless the user explicitly asks for another change.
- Preserve the `.agents` symlink and edit through it or edit its resolved target; never replace it.
- Do not silently expand a frontend issue into backend implementation. Record required backend changes as gates or linked follow-ups unless the user explicitly includes them in scope.
- Do not claim an acceptance criterion is satisfied merely because the UI hides an action when the backend still permits it.
- Do not guess inaccessible issue content or API behavior. Stop and request the missing context.
