-- agent-loop fork: add a dedicated acceptance_criteria column to issues.
--
-- Background: the agent-loop daemon (https://github.com/jayhere1/agent_loop_kanban)
-- consumes vibe-kanban cards as tasks. Until now it parsed acceptance criteria
-- out of either a `## Acceptance` markdown section in `description` or a
-- conventional key in the `extension_metadata` JSONB blob. Both work but mix
-- the criteria with other fields. This column gives them a first-class home
-- and a UI form section to match.
--
-- The column is nullable so existing rows aren't disturbed. The agent-loop
-- adapter still falls back to the description / extension_metadata paths when
-- this column is null.

ALTER TABLE issues
ADD COLUMN acceptance_criteria TEXT;
