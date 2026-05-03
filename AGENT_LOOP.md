# agent-loop fork notes

This is a fork of [BloopAI/vibe-kanban](https://github.com/BloopAI/vibe-kanban)
maintained for use with the [agent-loop](https://github.com/jayhere1/agent_loop_kanban)
daemon. Upstream is sunsetting (see the upstream README banner); we're keeping
this fork alive for our own internal tooling.

## Divergence from upstream

### `acceptance_criteria` column on `issues`

A new nullable `TEXT` column on the `issues` table, fronted by:

- API: `Issue.acceptance_criteria`, accepted by `CreateIssueRequest` and
  `UpdateIssueRequest` (use the `Option<Option<String>>` "set vs leave"
  pattern on update to distinguish "don't change" from "clear the field").
- UI: a labelled textarea below the description editor in
  `KanbanIssuePanel`. Auto-saves on edit (mirrors the description's
  debounce timing).
- Database: `crates/remote/migrations/20260503000000_add_acceptance_criteria_to_issues.sql`.

Why a dedicated column instead of `extension_metadata.acceptance_criteria`?
Two reasons:

1. The agent-loop daemon treats acceptance criteria as the **task contract**.
   Surfacing it in its own labelled UI section makes it harder to forget,
   and easier to skim across a board.
2. A native column gets typed access in the Postgres queries; JSONB
   extraction always means string coercion + null guards.

The agent-loop adapter still falls back to `description` (parsed `## Acceptance`
section) and `extension_metadata.acceptance_criteria` when the column is null,
so this change is fully backward-compatible with cards created before the
migration ran.

### `vk-billing` feature disabled

Upstream gates a Stripe-driven billing layer behind the `vk-billing`
feature, which depends on a private BloopAI repo we don't have access
to. The dep is commented out in `crates/remote/Cargo.toml`; the
`#[cfg(not(feature = "vk-billing"))]` no-op shims in
`crates/remote/src/billing.rs` remain the only path.

## Running the schema/UI changes locally

```bash
# Postgres in Docker
docker run -d --name vk-pg -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=vibe_kanban -p 5499:5432 postgres:16-alpine
docker exec vk-pg psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" -d vibe_kanban
docker exec vk-pg psql -U postgres -c "CREATE DATABASE remote;"

# Apply migrations + regenerate sqlx offline cache
cd crates/remote
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5499/vibe_kanban \
  sqlx migrate run --source migrations
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5499/vibe_kanban \
  cargo sqlx prepare

# Regenerate TypeScript types from Rust
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5499/vibe_kanban \
  cargo run --bin remote-generate-types

# Build / typecheck the JS workspaces
cd ../..
pnpm install
pnpm run ui:check
pnpm run web-core:check
```

## Rebasing on upstream

When upstream pushes new releases, rebase this branch:

```bash
git fetch upstream
git rebase upstream/main
# resolve conflicts (most likely in crates/remote/src/db/issues.rs and
# crates/api-types/src/issue.rs around the new column), then re-run the
# sqlx prepare + ts-rs generate steps above.
```
