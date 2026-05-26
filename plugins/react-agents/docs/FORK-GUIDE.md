# Fork guide — manual profile creation

If you prefer hand-forking the templates over the interactive `profile-generator` skill, follow this guide.

## When to hand-fork

- You want full control over which sections of each agent survive.
- Your project's conventions don't map cleanly to the default placeholder set (e.g. you have 12 MC sections instead of 7, or your agents need to invoke a domain skill the template doesn't reference).
- You're adapting to a stack that isn't React 19 / Vite — the templates assume a React SPA stack, and some sections (Swagger drift gate, Polished page check) may not apply.

## Step 1 — Pick an output folder

```bash
mkdir -p ~/Workspace/myapp-profile/{agents,skills,.claude-plugin}
```

## Step 2 — Copy templates

```bash
cp ../react-agents/templates/agents/implement.template.md   ~/Workspace/myapp-profile/agents/myapp-implement.md
cp ../react-agents/templates/agents/polish.template.md      ~/Workspace/myapp-profile/agents/myapp-polish.md
cp ../react-agents/templates/agents/pre-commit.template.md  ~/Workspace/myapp-profile/agents/myapp-pre-commit.md
cp ../react-agents/templates/agents/test.template.md        ~/Workspace/myapp-profile/agents/myapp-test.md
```

## Step 3 — Substitute placeholders

Open each file and replace every `{{PLACEHOLDER}}` per the [Placeholder reference](./PLACEHOLDER-REFERENCE.md). Recommended: do it in your editor with project-wide find-replace.

The most error-prone placeholders to get right:

- `{{AGENT_PREFIX}}` appears inside the `name:` frontmatter, the `description:` text, the body, and the report templates. Use replace-all.
- `{{CONVENTIONS_DOC}}` is referenced 8-10 times in each agent — replace-all carefully so you don't change unrelated `CLAUDE.md` strings (e.g. in this docs folder).
- `{{MC_MAX}}` appears in counts (`MC-1 through MC-7`) and report status-line counts (`Report MUST contain 7 status lines`). Both must be the same number.

## Step 4 — Strip conditional sections

If your project doesn't have a piece of infrastructure, delete the corresponding section instead of leaving placeholders behind:

| If your project has no... | Delete... |
|---|---|
| Backend Swagger | Step 0.0 BE-scope gate (in implement); Swagger drift gate (in pre-commit) |
| Shared API service layer | Drop the `{{API_SERVICES_PATHS}}` bullet from the Swagger drift gate (in pre-commit) — the gate then triggers only on per-feature `api/*` |
| Structure linter | Shared `lint:structure` run + Structure regression check (in pre-commit) |
| Polish audit script | Polish-status check section (in pre-commit) |
| Per-category docs folders | Drop the `{{ARCHITECTURE_DOCS_GLOB}}` / `{{COMPONENT_DOCS_GLOB}}` / `{{FEATURE_DOCS_GLOB}}` rows from the Docs update table (in pre-commit) |
| Canonical test baseline | Leave `{{TEST_CANONICAL_BASELINE}}` + `{{TEST_CANONICAL_FILES}}` empty in `test.template.md` — the agent falls back to in-repo conventions |
| UI inventory skill | Skill-invocation row that references it; replace inline mentions with the relevant default primitive guidance |

Aim for: every section that survives must reference real infrastructure your project ships.

## Step 5 — Create `plugin.json`

```json
{
  "name": "myapp-profile",
  "version": "0.1.0",
  "description": "MyApp profile: implement/polish/pre-commit/test subagents.",
  "author": { "name": "Your Name" },
  "license": "MIT",
  "keywords": ["claude-code", "claude-agent", "myapp"]
}
```

## Step 6 — Install

### Symlink (active dev):

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p .claude/agents
for a in myapp-implement myapp-polish myapp-pre-commit myapp-test; do
  ln -s "$HOME/Workspace/myapp-profile/agents/$a.md" ".claude/agents/$a.md"
done
```

### Plugin marketplace (publish your own):

```bash
cd ~/Workspace/myapp-profile
git init && git add . && git commit -m "Initial profile"
git remote add origin https://github.com/<you>/myapp-profile.git
git push -u origin main
```

Then in Claude Code:
```
/plugin marketplace add <you>/myapp-profile
/plugin install myapp-profile@myapp-profile
```

## Sanity-check the fork

After install, run:

```
/agents
```

You should see `myapp-implement`, `myapp-polish`, `myapp-pre-commit`, `myapp-test` in the list. Then test-drive:

```
User: "review my changes"
```

Should spawn `myapp-pre-commit` and report against your project's actual paths.

If something feels wrong (agent says `pps-web` somewhere, or references a file path that doesn't exist), grep the agent files for the offending string and finish the substitution.

## When to come back to the generator

If your project later adopts more infrastructure (adds a Swagger URL, a structure linter, etc.), you can:

1. Re-run `/profile-generator` with the new answers → it writes a fresh profile.
2. Diff against your hand-edited version to pick up new sections.

The generator is intentionally not destructive — it backs up `agents/` to `agents.bak.<timestamp>/` before overwriting.
