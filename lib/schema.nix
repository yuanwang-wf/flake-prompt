# The canonical prompt schema, expressed as a NixOS-style module so
# consumers get real type errors and we can generate option docs.
#
# A prompt is one of four types:
#   skill        -> <tool>/skills/<name>/SKILL.md (+ extra files)
#   agent        -> subagent definition (claude/opencode/droid)
#   command      -> slash-command template (claude/opencode; codex prompts dir)
#   instructions -> always-on context, concatenated into AGENTS.md/CLAUDE.md
{ lib }:

let
  inherit (lib) mkOption types;

  fileEntryType = types.submodule {
    options = {
      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Literal file contents. Exactly one of `text` or `source` must be set.";
      };
      source = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to copy the file from. Exactly one of `text` or `source` must be set.";
      };
      executable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the installed file should be executable.";
      };
    };
  };

  targetOverrideType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to render this prompt for this tool at all.";
      };
      extraFrontmatter = mkOption {
        type = types.attrsOf types.raw;
        default = { };
        description = "Frontmatter keys added only for this tool (e.g. claude-only `allowed-tools`).";
      };
      body = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Body override used only for this tool.";
      };
      force = mkOption {
        type = types.bool;
        default = false;
        description = "Render even when shared-path deduplication would normally suppress it (opencode skills when the claude target is enabled).";
      };
    };
  };
in
{
  inherit fileEntryType targetOverrideType;

  promptModule = {
    options = {
      type = mkOption {
        type = types.enum [
          "skill"
          "agent"
          "command"
          "instructions"
        ];
        description = "Kind of prompt; determines where and how it is rendered per tool.";
      };
      name = mkOption {
        type = types.strMatching "[a-z0-9][a-z0-9-]*";
        description = "Prompt name; becomes the directory or file name in each tool's layout.";
      };
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "One-line description; required for skill/agent/command (goes into frontmatter and drives model-side skill selection).";
      };
      body = mkOption {
        type = types.lines;
        description = "Markdown body of the prompt.";
      };

      # skill only
      files = mkOption {
        type = types.attrsOf fileEntryType;
        default = { };
        description = "Extra files installed inside the skill directory, keyed by relative path (e.g. \"references/checklist.md\"). Skills only.";
      };
      disableModelInvocation = mkOption {
        type = types.bool;
        default = false;
        description = "Hide the skill from the model so it is only user-invocable (currently surfaces as crush's `disable-model-invocation`). Skills only.";
      };

      # agent only
      tools = mkOption {
        type = with types; nullOr (either (listOf str) (attrsOf bool));
        default = null;
        description = "Tool access for an agent: a list of tool names, or an attrset map (opencode style). Agents only.";
      };
      model = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Model override for an agent. Agents only.";
      };
      mode = mkOption {
        type = types.enum [
          "subagent"
          "primary"
        ];
        default = "subagent";
        description = "opencode agent mode. Agents only.";
      };

      # command only
      argumentHint = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Argument hint shown in the command palette (e.g. \"<file> [--strict]\"). The body may use $ARGUMENTS / $1..$9. Commands only.";
      };

      # instructions only
      order = mkOption {
        type = types.int;
        default = 1000;
        description = "Merge order of instructions fragments within the concatenated AGENTS.md/CLAUDE.md (500 = early, 1500 = late). Instructions only.";
      };

      # universal knobs
      degradation = mkOption {
        type = types.nullOr (
          types.enum [
            "skip"
            "skill"
          ]
        );
        default = null;
        description = "What to do on tools lacking this prompt type: \"skill\" degrades it to a skill, \"skip\" drops it. Null inherits the global default.";
      };
      extraFrontmatter = mkOption {
        type = types.attrsOf types.raw;
        default = { };
        description = "Frontmatter keys added for every tool.";
      };
      targets = mkOption {
        type = types.attrsOf targetOverrideType;
        default = { };
        description = "Per-tool overrides, keyed by tool name (claude, codex, opencode, crush, droid).";
      };
    };
  };
}
