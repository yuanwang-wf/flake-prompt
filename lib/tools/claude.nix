# Claude Code: skills, agents, commands, CLAUDE.md — all native.
{ lib }:

let
  toolList =
    tools:
    if tools == null then
      null
    else if builtins.isList tools then
      lib.concatStringsSep ", " tools
    else
      lib.concatStringsSep ", " (lib.attrNames (lib.filterAttrs (_: v: v) tools));
in
_cfg: {
  name = "claude";
  supports = {
    skill = true;
    agent = true;
    command = true;
    instructions = true;
  };
  paths = {
    skillDir = n: ".claude/skills/${n}";
    agentFile = n: ".claude/agents/${n}.md";
    commandFile = n: ".claude/commands/${n}.md";
    instructions = ".claude/CLAUDE.md";
  };
  frontmatter = {
    skill = p: { inherit (p) name description; };
    agent = p: {
      inherit (p) name description;
      tools = toolList p.tools;
      model = p.model;
    };
    command = p: {
      description = p.description;
      argument-hint = p.argumentHint;
    };
  };
  pruneRoots = [
    ".claude/skills"
    ".claude/agents"
    ".claude/commands"
    ".claude/CLAUDE.md"
  ];
}
