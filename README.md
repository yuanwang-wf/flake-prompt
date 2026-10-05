<div align="center"><h1>F&nbsp;&nbsp;&nbsp;l&nbsp;&nbsp;&nbsp;a&nbsp;&nbsp;&nbsp;k&nbsp;&nbsp;&nbsp;e&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;P&nbsp;&nbsp;&nbsp;r&nbsp;&nbsp;&nbsp;o&nbsp;&nbsp;&nbsp;m&nbsp;&nbsp;&nbsp;p&nbsp;&nbsp;&nbsp;t</h1></div>

---

A Nix flake that acts as a package manager for AI-agent prompts. Declare
skills, subagents, slash commands, and instructions **once** in Nix —
including prompts that are *functions* templated with arguments at eval
time — and render them into the native on-disk formats of:

| Tool | skills | agents | commands | instructions |
|---|---|---|---|---|
| **Claude Code** | `~/.claude/skills/<n>/SKILL.md` | `~/.claude/agents/<n>.md` | `~/.claude/commands/<n>.md` | `~/.claude/CLAUDE.md` |
| **Codex** | `~/.codex/skills/<n>/SKILL.md` | — *(degrades)* | `~/.codex/prompts/<n>.md` | `~/.codex/AGENTS.md` |
| **opencode** | `~/.config/opencode/skills/…` ¹ | `~/.config/opencode/agent/<n>.md` | `~/.config/opencode/command/<n>.md` | `~/.config/opencode/AGENTS.md` |
| **Crush** | `~/.config/crush/skills/…` | — *(degrades)* | — *(degrades)* ² | `~/.config/crush/CRUSH.md` |
| **Droid** | `~/.factory/skills/…` | `~/.factory/droids/<n>.md` | merged into skills ³ | `~/.factory/AGENTS.md` |
| **pi** | `~/.pi/agent/skills/…` | — *(degrades)* ⁴ | `~/.pi/agent/prompts/<n>.md` | `~/.pi/agent/AGENTS.md` |
| **Cursor** | `~/.cursor/skills/…` | — *(degrades)* ⁵ | — *(degrades)* ⁵ | — *(skipped)* ⁵ |

¹ opencode also reads `~/.claude/skills`; when both targets are enabled,
agent-pm skips the opencode copy (`deduplicateSharedPaths`, per-prompt
override `targets.opencode.force = true`).
² degraded commands become palette-only skills (`disable-model-invocation: true`).
³ `tools.droid.commandStrategy = "legacy-commands"` uses `~/.factory/commands` instead.
⁴ pi ships no subagent format on purpose; command bodies keep working
(`$ARGUMENTS`/`$1..$9` are pi prompt-template syntax too).
⁵ Cursor Agent Skills live under `~/.cursor/skills`; agents/commands degrade
to skills (commands get `disable-model-invocation: true`). There is no
stable global instructions file yet, so instructions are skipped.

This is a **pure framework** — it ships no prompts. Your prompts live in
your own flake (start one with `nix flake init -t github:OWNER/agent-pm`).

## Declaring prompts

A prompt is a plain attrset, or a function from arguments to an attrset —
this is where Nix templating comes in:

```nix
# prompts/code-review.nix
{ lang ? "nix", strictness ? "standard", conventions ? [ ] }:
{
  type = "skill";                     # skill | agent | command | instructions
  name = "code-review-${lang}";
  description = "Review ${lang} code at ${strictness} strictness.";
  body = ''
    # Code review: ${lang}
    Strictness: **${strictness}**.
    ${builtins.concatStringsSep "\n" (map (c: "- ${c}") conventions)}
  '';
  files."references/checklist.md".text = "…";              # extra skill files
  targets.claude.extraFrontmatter."allowed-tools" = "Read, Grep";
}
```

Other fields: `tools`/`model`/`mode` (agents), `argumentHint` (commands,
body may use `$ARGUMENTS`/`$1..$9`), `order` (instructions merge order,
default 1000), `degradation = "skip" | "skill"`, `extraFrontmatter`, and
per-tool `targets.<tool>.{enable, extraFrontmatter, body, force}`.

When a tool lacks a type natively (agents on codex/crush/pi/cursor,
commands on crush/cursor), the prompt **degrades to a skill** carrying the
same content by default; set `degradation = "skip"` (per prompt or globally
via `defaults.degradation`) to drop it instead. Instructions on tools with
no instructions path (cursor today) are skipped.

## Installing

### home-manager (recommended)

```nix
imports = [ inputs.agent-pm.homeManagerModules.default ];
programs.agent-pm = {
  enable = true;
  tools = { claude.enable = true; opencode.enable = true; };
  prompts = [
    (inputs.my-prompts.lib.prompts.code-review { lang = "go"; strictness = "strict"; })
    { type = "instructions"; name = "style"; body = "Prefer small commits."; }
  ];
};
```

The prompt roots of the enabled tools (`~/.claude/skills`,
`~/.codex/skills`, the cross-CLI `~/.agents/skills`, …) are treated as
owned exclusively by agent-pm: at switch time an activation step deletes
foreign regular files under them — leftovers from hand installs or
retired deployers that the CLIs would otherwise keep listing as stale
commands. Hidden entries (e.g. codex's bundled `skills/.system`) are
spared, and home-manager's own symlinks are never touched. Opt out with
`programs.agent-pm.clobberForeignFiles = false`.

### NixOS without home-manager

```nix
imports = [ inputs.agent-pm.nixosModules.default ];
services.agent-pm = {
  enable = true;
  users.alice = { enable = true; tools.claude.enable = true; prompts = [ … ]; };
};
```

Files are symlinked into user homes with `systemd-tmpfiles` (per rendered
file — tool directories stay writable for the tools' own mutable state).
Caveats vs home-manager: `L+` rules replace whatever already exists at a
managed path (e.g. a hand-written `~/.claude/CLAUDE.md`), and links from
removed prompts are cleaned up at next login by the `pruneStaleLinks`
activation script rather than at switch time.

### Standalone

```nix
packages.default = agent-pm.lib.mkPromptsPackage pkgs {
  prompts = [ … ];
  tools.claude.enable = true;
};
```

`nix build` then gives you `result/.claude/…`, `result/.config/…` to
symlink or rsync however you like.

## Library

```nix
agentPm = import agent-pm { inherit (nixpkgs) lib; };  # or agent-pm.lib
agentPm.renderFiles { prompts, tools, deduplicateSharedPaths ? true, defaultDegradation ? "skill" }
  # -> { ".claude/skills/x/SKILL.md" = { text = "…"; }; … }
agentPm.evalPrompt promptOrFn args   # normalize + validate one prompt
agentPm.mkPromptSet { prompts }      # validate a prompt library
agentPm.toYamlFrontmatter attrs      # JSON-scalar YAML (colons/newlines safe)
```

Option docs: `nix build .#docs`. Tests: `nix flake check` (pure-eval unit
tests, golden-tree diff for all seven tools, home-manager and NixOS module
evals). After intentional rendering changes, regenerate the golden tree:
`nix build .#example && rm -rf tests/golden && cp -rT --no-preserve=mode,timestamps "$(readlink -f result)" tests/golden/`.
