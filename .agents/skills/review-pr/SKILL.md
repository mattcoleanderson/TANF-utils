---
name: review-pr
description: Review another person's GitHub pull request from the currently checked-out branch against develop. Use when the user asks for a PR review or walkthrough and supplies GitHub issue and PR IDs or URLs.
user_invocable: true
---

# Review Pull Request

Explain and review another person's pull request. Treat the checked-out `HEAD` as the code being reviewed and compare it with `develop`. Use the GitHub issue and PR only to establish intent, acceptance criteria, discussion, and metadata.

This is a read-only workflow. Do not edit application code, post review comments, approve the PR, request changes on GitHub, commit, push, switch branches, or modify Git refs.

## Usage

Accept an issue reference followed by a PR reference. Each reference may be a numeric ID or a full GitHub URL. Labeled references and URLs may appear in either order because their types are explicit.

```text
/review-pr 5946 6031
/review-pr issue 5946 pr 6031
/review-pr https://github.com/raft-tech/TANF-app/issues/5946 https://github.com/raft-tech/TANF-app/pull/6031
```

For two unlabeled numeric arguments, treat the first as the issue ID and the second as the PR ID. Otherwise, use labels such as `issue` and `pr`, URL paths, and surrounding conversation to distinguish the references. If either reference is missing or remains ambiguous, ask one concise clarifying question.

For a full URL, use the repository identified by that URL. For a numeric ID, infer the repository from the current checkout. If the issue and PR belong to different repositories, fetch each from its own repository.

## Establish Context

1. Read repository and affected-subsystem instructions, including `AGENTS.md`, `CONTEXT-MAP.md`, and relevant `CONTEXT.md` files.
2. Inspect without changing the checkout:
   - `git status --short --branch`
   - `git branch --show-current`
   - `git rev-parse --verify develop`
   - `git log --oneline --decorate develop..HEAD`
3. Fetch the issue with `gh issue view <issue-ref> --comments --json number,title,body,state,labels,comments,url`.
4. Fetch the PR with `gh pr view <pr-ref> --json number,title,body,state,baseRefName,headRefName,files,commits,reviews,comments,closingIssuesReferences,url`.
5. Read relevant inline PR discussion with `gh api repos/<owner>/<repo>/pulls/<pr-number>/comments --paginate`.
6. Confirm the PR targets `develop`, the supplied issue matches the PR's stated work, and the local `HEAD` appears to represent the PR head. Report mismatches clearly, but continue using the local checkout when a meaningful review is still possible.
7. If `develop` is unavailable, the GitHub content cannot be accessed, or the local checkout clearly does not contain the supplied PR, stop and ask the user to correct the checkout or provide the missing access. Do not guess.

Do not fetch, pull, checkout, or update `develop` automatically. State that the comparison uses the local `develop` ref. Mention if the working tree has uncommitted changes; do not include those changes in the primary review unless the user explicitly asks. A detached `HEAD` is acceptable if it matches the PR commit.

## Inspect The Changes

Use the merge-base comparison so the review contains changes introduced by the checked-out branch, not unrelated changes made on `develop` after the branch diverged.

```bash
git diff --find-renames --stat develop...HEAD
git diff --find-renames --name-status develop...HEAD
git diff --find-renames --check develop...HEAD
git diff --find-renames develop...HEAD
```

Then read the complete current versions of affected source and test files, plus directly related call sites and contracts. Do not review from isolated diff fragments alone.

Trace behavior in a logical execution order rather than alphabetical file order. Prefer this sequence when applicable:

1. Data model, schema, migrations, and configuration.
2. Backend domain logic, persistence, tasks, and external integrations.
3. API serializers, permissions, endpoints, and contracts.
4. Frontend state, data fetching, components, and user interaction.
5. Tests, fixtures, documentation, and operational changes.

Adjust the sequence to match the actual feature. Group tightly related files into one change rather than explaining every import or formatting edit separately. Explain why a change exists, what calls it, what behavior differs from `develop`, and how it supports the issue. Use plain language and define project-specific terms when first used.

## Review Standards

Review for behavior and risk, not just style. Check the implementation against the issue's acceptance criteria and PR claims, including:

- Incorrect behavior, regressions, unhandled errors, and edge cases.
- Authorization, data exposure, input validation, and unsafe trust boundaries.
- Data integrity, migration safety, transaction boundaries, concurrency, retries, and duplicate processing.
- API compatibility and agreement between backend and frontend contracts.
- User-visible loading, empty, success, and failure states.
- Accessibility when UI behavior changes.
- Tests that are missing, misleading, non-deterministic, or fail to cover important behavior.
- Operational concerns such as logging sensitive data, configuration, deployment order, and rollback safety.

Use issue and PR discussion as context, not proof that the implementation is correct. Ignore purely subjective preferences unless they violate repository conventions or create a concrete maintenance risk. Do not report pre-existing problems outside the branch diff unless the PR directly exposes or worsens them.

Do not run automated tests as part of this workflow. Do not inspect or focus on CircleCI failures, and do not report a failing test or CI check as a review finding; CircleCI already blocks merging until the author fixes those failures. Review changed test code only to identify meaningful coverage gaps, incorrect assertions, or misleading tests that may still pass CI.

Before reporting a finding:

1. Verify it against the complete current code and relevant callers.
2. Confirm it was introduced or made materially worse by `develop...HEAD`.
3. Describe a concrete failure mode or acceptance-criterion gap.
4. Identify the smallest useful current-branch line range for a PR comment.
5. Avoid duplicates by combining findings with the same root cause.
6. Check existing PR discussion and do not repeat a point that the author has already resolved or that another reviewer has already raised, unless it remains unresolved and materially blocks the PR.

Order findings by severity: `Blocking`, `High`, `Medium`, then `Low`. Do not inflate severity. Omit speculative findings that cannot be supported from the code.

## Required Response

Start with enough context for the user to orient themselves:

```markdown
## Review Context

- Issue: #<number> <title> (<url>)
- PR: #<number> <title> (<url>)
- Comparison: local `develop...HEAD`
- Scope: <short statement of what the PR is intended to accomplish>
- Caveats: <branch mismatch, stale local ref, uncommitted files, or `None`>
```

### Change Walkthrough

Walk through the implementation in logical runtime or dependency order. For each meaningful group of changes, include:

```markdown
### <Number>. <Plain-language change name>

Files: `<path>`, `<path>`

<Simple explanation of the old behavior, what changed, how the pieces connect, and why the issue needs it.>
```

Call out tests alongside the behavior they protect instead of listing test files with no explanation. Keep this section descriptive; reserve criticism and requested changes for the findings section.

### Review Findings

Findings are the primary review result. For every finding, include severity, a precise current-branch file and line range, the existing code, the user impact or failure mode, the reasoning in simple terms, and a ready-to-post PR comment.

When the fix is small and unambiguous, provide a focused replacement:

````markdown
### [Medium] <Finding title>

Location: `<path>:<start>-<end>`

Existing code:

```<language>
<exact relevant code from HEAD>
```

Suggested change:

```<language>
<small replacement only>
```

Why: <Full, plain-language explanation of the problem, when it occurs, and why the replacement addresses it.>

Suggested PR comment:

> <A concise, respectful, actionable comment that explains the concrete concern and requested change.>
````

Only provide replacement code when it is clearly correct, local, and short. Do not invent a full implementation for a complex problem. For complex or design-level findings, use:

````markdown
### [High] <Finding title>

Comment on: `<path>:<start>-<end>`

Existing code:

```<language>
<exact relevant code from HEAD>
```

Why this needs review: <Full, plain-language explanation, including the failure scenario and affected users or systems. Explain important technical terms.>

Suggested PR comment:

> <The exact respectful comment the user can leave. Describe the observed problem and desired behavior without prescribing an uncertain implementation.>
````

Comments should discuss the code, not the author. Phrase uncertain conclusions as questions, but do not weaken a verified defect into a vague suggestion. Include enough context that the author can act without reading this separate review report.

If there are no findings, write:

```markdown
## Review Findings

No actionable findings found.
```

Then state residual risks or testing gaps. Do not create findings merely to fill the section.

Finish with:

```markdown
## Review Basis

- Static review: local `develop...HEAD`, affected code paths, and GitHub issue/PR context
- Automated tests: Not run by design; CircleCI is the merge gate

## Review Summary

<Finding count by severity, the most important review focus, and any remaining uncertainty.>
```

## Line Reference Rules

- Refer to line numbers in the checked-out `HEAD`, not `develop` and not an outdated GitHub patch.
- Verify every line immediately before returning the review because line numbers may shift while the workspace is active.
- Quote only the smallest code block needed to understand the finding.
- Choose a line changed by the PR whenever GitHub permits it. If the problem is caused by a changed line but manifests in unchanged nearby code, anchor the comment on the causal changed line and explain the connection.

## Safety

- Do not modify source, tests, documentation, Git state, GitHub issues, or the PR.
- Do not submit comments or reviews. Provide suggested text for the user to post.
- Do not run tests, investigate CircleCI failures, or call out failing CI checks; those are already enforced before merge.
- Do not expose secrets, tokens, private user data, or sensitive log values in quoted code or review output.
- Do not claim to have tested behavior that was only inspected statically.
- Do not approve a PR merely because no actionable findings were found.
