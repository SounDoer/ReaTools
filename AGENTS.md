# AGENTS.md — ReaTools

ReaTools is the canonical monorepo for a family of REAPER workflow tools and
their shared UI system.

## Language

- Code, identifiers, comments, tests, schemas, branches, commits, and repository
  documentation are English.
- User manuals under `docs/manual/` and `tools/*/docs/manual/` are written in
  Chinese; UI labels and technical names stay in their original form.
- Conversation and status updates default to Chinese.
- Keep technical names, API names, commands, and error messages in their
  original form.

## Repository boundaries

- `tools/` contains independently installable user-facing REAPER tools.
- `packages/` contains shared source packages and no product workflow logic.
- `tooling/` contains repository-wide build, validation, packaging, and release
  automation.
- `docs/decisions.md` is authoritative for monorepo and cross-tool decisions.
- A tool remains responsible for its own workflow, persistence, external APIs,
  and product-specific behavior.

## Development workflow

- Read `docs/decisions.md` before changing repository structure, package
  boundaries, installation, release behavior, or persisted product data.
- Do not turn an open question into a decision without user confirmation.
- Keep affected documentation consistent with confirmed changes.
- Add runtime dependencies only after asking the user.
- Run the smallest relevant checks and the repository-level validation required
  by the affected boundary before reporting work complete.
- Keep the original standalone repositories unchanged until the copied tools
  have passed their migration gates.

## Git workflow

- Stay on the current branch unless the user asks otherwise.
- Do not create branches, commit, or push silently.
- Commits use Conventional Commits with a concise scope, for example:
  `feat(ui): extract shared field components`.

## Safety

- Preserve unrelated user changes in a dirty worktree.
- Avoid destructive filesystem and Git operations.
- Confirm exact targets before deleting generated files or history.
- Prefer recoverable and atomic updates.
