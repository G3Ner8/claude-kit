# Install

Three ways to consume claude-kit, in order of recommendation.

## A — Plugin marketplace (recommended)

```
/plugin marketplace add G3Ner8/claude-kit
/plugin install react-core@claude-kit
/plugin install react-agents@claude-kit
```

For your own project, after `react-agents` is installed, run `/profile-generator` and answer ~22 questions to scaffold a filled-in agent trio.

Updates: `/plugin marketplace update` then re-install if a plugin's `version` field bumped.

Uninstall: `/plugin uninstall react-core@claude-kit`.

Private repo? Set `GITHUB_TOKEN` in your environment so Claude Code can read the catalog.

## B — Local symlinks (active development)

If you're editing this kit and want changes to land in your project immediately:

```bash
# From your project root
cd "$(git rev-parse --show-toplevel)"
mkdir -p .claude/skills .claude/agents

# react-core skills
for skill in react-perf react-composition react-audit react-revamp react-ux-review react-dry react-test-patterns; do
  ln -s "$HOME/Workspace/claude-kit/plugins/react-core/skills/$skill" \
        ".claude/skills/$skill"
done

# Your own generated profile (run /profile-generator first), e.g.:
# for agent in web-implement web-polish web-pre-commit web-test; do
#   ln -s "$HOME/path/to/your-profile/agents/$agent.md" ".claude/agents/$agent.md"
# done
```

Edits to `~/Workspace/claude-kit/` propagate to the project on the next Claude Code session.

## C — Copy (frozen snapshot)

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p .claude/skills .claude/agents
cp -R "$HOME/Workspace/claude-kit/plugins/react-core/skills/"* .claude/skills/
# Plus your own generated profile's agents, if any.
```

No live updates — re-copy when you want a refresh.

## Verifying

Quick functional test: ask "audit Button usages" — response should reference `react-dry`'s table-first findings format.
