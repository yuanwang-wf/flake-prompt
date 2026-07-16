---
name: "code-review-go"
description: "Review go code at strict strictness for correctness and style."
allowed-tools: "Read, Grep, Bash(git diff:*)"
---

# Code review: go

Review the changed go code. Strictness level: **strict**.

Work through references/checklist.md and report findings ranked by severity.

## Team conventions

- errors are wrapped with %w
- table-driven tests
