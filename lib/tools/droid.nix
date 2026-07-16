# Factory Droid: skills, custom droids (subagents), AGENTS.md. Commands are
# merged into skills upstream, so they degrade to skills by default; the
# legacy ~/.factory/commands directory still works via
# commandStrategy = "legacy-commands".
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
{
  commandStrategy ? "skill",
  ...
}:
assert lib.assertMsg (lib.elem commandStrategy [
  "skill"
  "legacy-commands"
]) "agent-pm: droid.commandStrategy must be \"skill\" or \"legacy-commands\"";
{
  name = "droid";
  supports = {
    skill = true;
    agent = true;
    command = commandStrategy == "legacy-commands";
    instructions = true;
  };
  paths = {
    skillDir = n: ".factory/skills/${n}";
    agentFile = n: ".factory/droids/${n}.md";
    commandFile = n: ".factory/commands/${n}.md";
    instructions = ".factory/AGENTS.md";
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
    ".factory/skills"
    ".factory/droids"
    ".factory/commands"
    ".factory/AGENTS.md"
  ];
}
