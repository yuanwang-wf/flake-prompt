# Cursor (cursor.com / cursor-agent): Agent Skills under ~/.cursor/skills.
# No native subagent, slash-command, or global instructions file yet, so
# agents/commands degrade per the degradation policy and instructions are
# skipped. Degraded commands get `disable-model-invocation: true` when the
# skill frontmatter supports it (same Agent Skills key as crush/pi).
{ lib }:

_cfg: {
  name = "cursor";
  supports = {
    skill = true;
    agent = false;
    command = false;
    instructions = false;
  };
  paths = {
    skillDir = n: ".cursor/skills/${n}";
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
    ".cursor/skills"
  ];
}
