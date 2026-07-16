# opencode: skills, agents (mode: primary|subagent, tools map), commands,
# AGENTS.md. opencode also reads ~/.claude/skills, so skill rendering is
# suppressed when the claude target is enabled (see deduplicateSharedPaths).
{ lib }:

let
  toolMap =
    tools:
    if tools == null then
      null
    else if builtins.isList tools then
      lib.genAttrs tools (_: true)
    else
      tools;
in
_cfg: {
  name = "opencode";
  supports = {
    skill = true;
    agent = true;
    command = true;
    instructions = true;
  };
  paths = {
    skillDir = n: ".config/opencode/skills/${n}";
    agentFile = n: ".config/opencode/agent/${n}.md";
    commandFile = n: ".config/opencode/command/${n}.md";
    instructions = ".config/opencode/AGENTS.md";
  };
  frontmatter = {
    skill = p: { inherit (p) name description; };
    agent = p: {
      description = p.description;
      mode = p.mode;
      model = p.model;
      tools = toolMap p.tools;
    };
    command = p: {
      description = p.description;
    };
  };
  # opencode reads claude's skill dir itself.
  skillsSharedWith = "claude";
  pruneRoots = [
    ".config/opencode/skills"
    ".config/opencode/agent"
    ".config/opencode/command"
    ".config/opencode/AGENTS.md"
  ];
}
