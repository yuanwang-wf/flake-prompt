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
  ];
}
