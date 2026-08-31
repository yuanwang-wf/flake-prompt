# Charm Crush: skills (doubling as palette commands) and CRUSH.md only.
# Agents and commands degrade per the degradation policy; degraded commands
# get `disable-model-invocation: true` so they stay palette-only.
{ lib }:

_cfg: {
  name = "crush";
  supports = {
    skill = true;
    agent = false;
    command = false;
    instructions = true;
  };
  paths = {
    skillDir = n: ".config/crush/skills/${n}";
    instructions = ".config/crush/CRUSH.md";
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
  };
  pruneRoots = [
    ".config/crush/skills"
    ".config/crush/CRUSH.md"
    # Crush surfaces palette commands from skills, and it discovers skills in
    # several cross-CLI dirs besides its own — notably ~/.agents/skills and
    # ~/.config/agents/skills. agent-pm renders crush skills only under
    # .config/crush/skills, but retired deployers left real files in those
    # shared dirs, so crush keeps listing them as stale commands. Claim them
    # here so the clobber reaches them even when codex (which also claims
    # ~/.agents/skills) is not enabled. ~/.claude/skills is deliberately NOT
    # claimed: when claude is disabled agent-pm renders nothing there and
    # clobbering would delete the user's real Claude Code skills.
    ".agents/skills"
    ".config/agents/skills"
  ];
}
