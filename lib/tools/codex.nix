# OpenAI Codex: skills and AGENTS.md; no subagent format. Commands render
# to the (deprecated but working) ~/.codex/prompts directory by default, or
# degrade to skills with commandStrategy = "skill".
{ lib }:

{
  commandStrategy ? "prompts-dir",
  ...
}:
assert lib.assertMsg (lib.elem commandStrategy [
  "prompts-dir"
  "skill"
]) "agent-pm: codex.commandStrategy must be \"prompts-dir\" or \"skill\"";
{
  name = "codex";
  supports = {
    skill = true;
    agent = false;
    command = commandStrategy == "prompts-dir";
    instructions = true;
  };
  paths = {
    skillDir = n: ".codex/skills/${n}";
    commandFile = n: ".codex/prompts/${n}.md";
    instructions = ".codex/AGENTS.md";
  };
  frontmatter = {
    skill = p: { inherit (p) name description; };
    command = p: {
      description = p.description;
      argument-hint = p.argumentHint;
    };
  };
  pruneRoots = [
    ".codex/skills"
    ".codex/prompts"
    ".codex/AGENTS.md"
    # Codex also discovers skills in the cross-CLI ~/.agents/skills dir and
    # subagents in ~/.codex/agents; agent-pm never renders there, but stale
    # files left by other deployers keep showing up in codex, so the roots
    # are claimed for pruning/clobbering.
    ".agents/skills"
    ".codex/agents"
  ];
}
