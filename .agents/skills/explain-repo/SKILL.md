---
name: explain-repo
description: Explain repository branch changes, pull requests, features, files, directories, or call paths using five levels of difficulty plus exhaustive line-by-line walkthroughs. Use when the user wants to deeply understand what changed or how existing code works.
user_invocable: true
---

# Explain Repository Code

Research repository code and teach it at five increasing levels of expertise. Explain both the role of every file in scope and its detailed implementation. Do not modify code while using this skill unless the user separately asks for code changes.

## Usage

This skill supports two modes.

### Branch Changes Mode

Use this mode to explain a branch, commit range, pull request, or working-tree diff:

```text
/explain-repo changes
/explain-repo changes develop
/explain-repo changes main...feature-branch
/explain-repo changes https://github.com/owner/repo/pull/123
/explain-repo changes including uncommitted work
```

The default scope is the current branch compared with its merge base against the repository's default branch. Prefer an explicit base supplied by the user or PR metadata. If neither is available, inspect the remote default branch before considering conventional branch names. Ask one concise question rather than guessing when the base remains ambiguous.

By default, explain committed branch changes only. Report staged, unstaged, and untracked files separately and include them only when the user requests working-tree changes or clearly asks about everything currently changed.

### General Understanding Mode

Use this mode to explain existing code regardless of branch history:

```text
/explain-repo file path/to/file
/explain-repo files path/one path/two
/explain-repo directory path/to/subsystem
/explain-repo feature "authentication flow"
/explain-repo feature "report generation" starting at path/to/entrypoint
/explain-repo repository architecture
```

The target may be a file, group of files, directory, symbol, endpoint, workflow, runtime process, or feature described in natural language. If no target can be inferred from the invocation or conversation, ask one concise scope question.

## Mode Selection

Choose **Branch Changes Mode** when the request mentions changes, a branch, diff, commit, PR, comparison, regression, or review range.

Choose **General Understanding Mode** when the request asks how a feature, subsystem, file, directory, symbol, endpoint, workflow, or repository works without making a comparison central to the request.

If both are requested, first explain the stable architecture in General Understanding Mode, then explain the branch delta in Branch Changes Mode. Do not blend current behavior and proposed behavior without clearly labeling them.

## Research Workflow

1. Read repository instructions and context before analyzing code:
   - Root and nearest `AGENTS.md` files.
   - Architecture maps, context files, READMEs, and subsystem documentation.
   - Generated-file warnings and repository-specific conventions.
2. Inspect repository state:
   - Repository root, current branch, status, upstream, and remote default branch.
   - Relevant commit history when it explains why code exists.
3. Establish an exact scope:
   - Branch mode: base, head, merge base, changed-file inventory, additions, deletions, renames, mode changes, and relevant uncommitted state.
   - General mode: entry points, selected files, symbols, callers, callees, configuration, data stores, external systems, tests, and documentation.
4. Read every scoped file in full. A diff alone is not enough to explain what the file does.
5. Trace interactions beyond each file:
   - Imports, references, command invocations, event triggers, routing, configuration flow, data flow, credential flow, and lifecycle boundaries.
   - Nearby tests and documentation that establish intended behavior.
   - Both sides of API, message, database, or deployment contracts.
6. Use `git diff --find-renames <base>...<head>` for branch changes unless the user specifies a different comparison.
7. For a PR URL, inspect PR metadata, changed files, commits, linked issues, and the PR diff. Do not rely only on the local checkout.
8. Parallelize independent file groups or subsystems with exploration agents. Give each agent non-overlapping scope and require exact file/line references.
9. Reconcile delegated results against the architecture map before answering. Do not paste inconsistent agent summaries together.

## Required Explanation Structure

Start with a concise architecture or execution-flow map showing how the scoped files connect. In Branch Changes Mode, also include a complete changed-file inventory. In General Understanding Mode, include an entry-point and dependency map.

Then explain every file in scope using this structure.

### `<path>`

#### What The Entire File Does

Explain the file's complete responsibility, where it sits in the repository, who invokes or imports it, what it invokes, what state or external systems it affects, and why it exists. Do not limit this section to changed lines.

#### Five Levels Of Difficulty

**Child (5-8 years):** Use a concrete analogy and plain language without becoming inaccurate. Explain the purpose and most important cause-and-effect relationship.

**Teenager:** Replace most analogy with concrete software behavior. Explain inputs, outputs, and the main sequence.

**Undergraduate:** Introduce the relevant programming, framework, protocol, data-structure, build, or deployment concepts. Explain control flow and data flow.

**Graduate student:** Explain architectural boundaries, design tradeoffs, security properties, failure modes, concurrency, lifecycle behavior, and why this approach may have been chosen.

**Peer / expert colleague:** Explain invariants, implicit contracts, framework semantics, operational consequences, race conditions, trust boundaries, maintainability concerns, and non-obvious alternatives. Assume equal technical fluency.

Each level must be one to three paragraphs. Increase depth rather than repeating the same summary with more jargon.

#### Detailed Walkthrough

Use exact `path:line` references from the current version. For deleted or replaced code, include old-side references or quote the deleted construct when line references no longer exist.

In **Branch Changes Mode**:

- Account for every changed hunk in every touched file.
- Explain every meaningful added, removed, replaced, renamed, or permission-changing line.
- For a new file, walk through every meaningful line from top to bottom.
- For a deleted file, explain what the complete file used to do and the consequence of removing it.
- Explain syntax, runtime behavior, reason for the change, interactions with other files, and edge cases.
- Distinguish behavior changes from formatting, comments, documentation, generated output, and mechanical refactors.

In **General Understanding Mode**:

- For explicitly selected files, walk through every meaningful line from top to bottom.
- For a feature spanning many large files, walk through every feature-relevant section line by line and clearly identify unrelated sections rather than pretending they were analyzed in detail.
- Trace the feature from each entry point through intermediate layers to side effects and outputs.
- Explain tests as executable examples of the contract, not merely as coverage.

Adjacent structural lines may be grouped when they form one declaration, parameter list, schema, table, or repeated mapping, but every meaningful line must be accounted for. Do not spend prose on blank lines unless whitespace itself is semantically significant.

#### Interactions, Risks, And Misconceptions

Explain how the file depends on the others, what assumptions must remain true, relevant edge cases, and likely reader misconceptions. Separate observed facts from informed interpretation.

## Special File Types

- **Generated files:** Identify the generator and source of truth. Group repetitive generated lines by semantic family, but account for every changed generated artifact or schema effect. Never imply generated code should be edited directly.
- **Lockfiles:** Explain each changed dependency/version group, integrity or resolution changes, and why transitive entries moved. Do not recite hashes character by character.
- **Migrations:** Explain forward and reverse behavior, locking/data-loss implications, deployment ordering, and compatibility assumptions.
- **Configuration and workflows:** Explain evaluation time versus runtime, inheritance, defaults, filters, permissions, secret boundaries, and the exact event-to-job path.
- **Tests:** Explain setup, doubles/fixtures, action, assertions, behavior protected, and important behavior not covered.
- **Documentation:** Explain the document's audience and full purpose, then connect each changed claim to actual implementation behavior.
- **Binary assets:** Explain identity, consumers, and diff metadata; state when meaningful line-level analysis is impossible.

## Scale And Completeness

- Never omit touched files because the scope is large.
- Never silently replace line-by-line analysis with a high-level summary.
- For a large branch, divide files into coherent subsystem sections and use parallel research.
- If the complete answer would be impractical in one response, provide an architecture map and inventory first, then deliver numbered parts until every file is covered. State exactly what each part covers and what remains.
- Avoid duplicated boilerplate across related files, but do not reduce the five required audience levels or detailed walkthrough for any file.

## Accuracy Rules

- Do not rely on conversation memory alone; inspect current repository contents and history.
- Do not infer behavior solely from filenames, comments, or docs.
- Distinguish a file's general responsibility from what changed in it.
- Distinguish build-time, configuration-evaluation-time, deploy-time, startup-time, request-time, and background-task behavior.
- Name credential and trust boundaries explicitly without exposing secret values.
- Explain branch, environment, feature-flag, permission, and error-path behavior precisely.
- Call out stale comments, contradictory docs, dead code, uncovered paths, and generated/manual boundaries when discovered.
- Do not claim a relation between an artifact and source revision unless the code actually verifies it.
- Prefer concrete execution sequences, tables, and compact diagrams where they improve understanding.

## What Not To Do

- Do not merely paraphrase the diff.
- Do not explain only production code while skipping config, tests, scripts, documentation, or deleted files.
- Do not produce five shallow restatements distinguished only by jargon.
- Do not call a mutable tag immutable, a skipped job successful deployment, or a stored package credential a runtime application variable.
- Do not modify code, run destructive commands, deploy, rotate credentials, or change remote state as part of explanation.
- Do not run tests unless the user separately requests verification; reading tests is part of research.
- Do not guess inaccessible PR, issue, file, or history content. Ask for access or missing context.

## Completion Checklist

Before answering, confirm:

1. The mode and comparison/target are explicit.
2. Every scoped or touched file appears in the inventory and final explanation.
3. Every file has a whole-file role explanation and all five audience levels.
4. Every meaningful changed line or selected feature line is accounted for.
5. Cross-file event, call, data, artifact, and credential flows are explained.
6. Deleted, renamed, generated, test, configuration, and documentation files received appropriate treatment.
7. Facts and interpretations are clearly distinguished.
8. Remaining scope is explicitly listed if the explanation is being delivered in multiple parts.
