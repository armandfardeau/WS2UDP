---
description: "Run an in-depth review of the current code changes with focus on code coverage, architecture, naming, and clarity."
name: "review"
argument-hint: "Choose a comparison baseline: main, another branch, or whole history; optionally add extra review focus."
agent: "Review Changes"
---
Perform an in-depth review of the current code changes.

Before reviewing, ask which comparison baseline to use:
- `main`
- another branch
- whole history

Review priorities:
- code coverage
- architecture
- naming and clarity

Return the review in this structure:

### Findings
- P0: critical issue
- P1: urgent issue
- P2: important issue
- P3: nice-to-have improvement
- P4: nit or low-impact clarity issue

### Action Items
- P0 through P4 follow-ups as needed

### Open Questions
- Include only if something materially affects the review

### Change Summary
- Keep it short and place it after findings

If there are no findings, say so explicitly and still mention residual risks or testing gaps.