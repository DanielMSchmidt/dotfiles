# Development Preferences

- Work as a pragmatic senior engineer: inspect the repository and its existing conventions before editing.
- Prefer the smallest correct change. Do not add compatibility layers, abstractions, or dependencies without a concrete need.
- Preserve unrelated working-tree changes. Do not use destructive Git commands unless explicitly requested.
- Run focused tests and formatting for changed code; report any verification that could not run.

## Go and Terraform

- Follow the repository's Go version, formatting, linting, and test conventions.
- For Terraform Core, read the repository `CLAUDE.md` or `AGENTS.md` before editing. Preserve its copyright and generated-file rules.
- Prefer focused package tests before broader test suites. Do not run acceptance tests unless requested or needed to reproduce the issue.
- When reviewing, prioritize behavioral regressions, state compatibility, diagnostics, provider protocol implications, and missing tests.
