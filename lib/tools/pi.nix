# pi (badlogic/earendil-works): skills, prompt templates as commands
# (~/.pi/agent/prompts, invoked as /<name>, $ARGUMENTS/$1.. compatible),
# AGENTS.md. pi deliberately ships no subagents, so agents degrade per the
# degradation policy.
{ lib }:

_cfg: {
  name = "pi";
  supports = {
    skill = true;
    agent = false;
    command = true;
    instructions = true;
  };
  paths = {
    skillDir = n: ".pi/agent/skills/${n}";
    commandFile = n: ".pi/agent/prompts/${n}.md";
    instructions = ".pi/agent/AGENTS.md";
  };
  frontmatter = {
    skill =
      p:
      {
        inherit (p) name description;
      }
      // lib.optionalAttrs p.disableModelInvocation {
        disable-model-invocation = true;
      };
    command = p: {
      description = p.description;
      argument-hint = p.argumentHint;
    };
  };
  pruneRoots = [
    ".pi/agent/skills"
    ".pi/agent/prompts"
    ".pi/agent/AGENTS.md"
    # pi also discovers skills in the cross-CLI ~/.agents/skills dir (codex
    # and crush claim it for the same reason): agent-pm never renders there,
    # but stale files left by other deployers would keep loading, so the
    # root is claimed for pruning/clobbering.
    ".agents/skills"
  ];
}
