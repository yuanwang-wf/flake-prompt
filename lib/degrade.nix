# Degradation of prompt types to skills, for tools that lack the type
# natively (agents on codex/crush, commands on crush and by-default droid).
{ lib }:

{
  degradeToSkill =
    p:
    if p.type == "agent" then
      p
      // {
        type = "skill";
        files = { };
        body = ''
          # Subagent persona: ${p.name}

          This tool has no native subagent support. When this skill is invoked,
          adopt the following persona and constraints for the remainder of the task.

        ''
        + p.body;
      }
    else if p.type == "command" then
      p
      // {
        type = "skill";
        files = { };
        # Commands are user-invoked; keep the degraded skill out of the
        # model's autonomous selection where the tool supports that.
        disableModelInvocation = true;
        body = lib.optionalString (p.argumentHint != null) "Arguments: `${p.argumentHint}`\n\n" + p.body;
      }
    else
      throw "agent-pm: cannot degrade prompt '${p.name}' of type '${p.type}' to a skill";
}
