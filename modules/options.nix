# Shared option tree, embedded by the home-manager module (under
# programs.agent-pm) and per-user by the NixOS module (services.agent-pm.users.<name>).
{ lib }:

let
  inherit (lib) mkOption mkEnableOption types;

  mkToolOption =
    name: extraOptions:
    mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "rendering prompts for ${name}";
        }
        // extraOptions;
      };
      default = { };
      description = "Configuration for the ${name} render target.";
    };
in
{
  enable = mkEnableOption "agent-pm prompt management";

  prompts = mkOption {
    type = types.listOf types.raw;
    default = [ ];
    example = lib.literalExpression ''
      [
        (inputs.team-prompts.lib.prompts.codeReview { lang = "go"; strictness = "strict"; })
        { type = "instructions"; name = "style"; body = "Prefer small commits."; }
      ]
    '';
    description = ''
      Canonical prompts: plain attrsets, or functions applied at the use
      site. Validated against the agent-pm schema at render time.
    '';
  };

  tools = mkOption {
    default = { };
    description = "Which agent CLIs to render prompts for (all disabled by default).";
    type = types.submodule {
      options = {
        claude = mkToolOption "Claude Code" { };
        codex = mkToolOption "OpenAI Codex" {
          commandStrategy = mkOption {
            type = types.enum [
              "prompts-dir"
              "skill"
            ];
            default = "prompts-dir";
            description = "Render commands into ~/.codex/prompts (deprecated upstream but works), or degrade them to skills.";
          };
        };
        opencode = mkToolOption "opencode" { };
        crush = mkToolOption "Charm Crush" { };
        pi = mkToolOption "pi" { };
        cursor = mkToolOption "Cursor" { };
        droid = mkToolOption "Factory Droid" {
          commandStrategy = mkOption {
            type = types.enum [
              "skill"
              "legacy-commands"
            ];
            default = "skill";
            description = "Render commands as skills (upstream merged them), or into the legacy ~/.factory/commands directory.";
          };
        };
      };
    };
  };

  deduplicateSharedPaths = mkOption {
    type = types.bool;
    default = true;
    description = ''
      opencode reads ~/.claude/skills itself; when both targets are enabled,
      skip rendering skills into the opencode directory to avoid duplicate
      listings. Override per prompt with `targets.opencode.force = true`.
    '';
  };

  defaults.degradation = mkOption {
    type = types.enum [
      "skip"
      "skill"
    ];
    default = "skill";
    description = "Default policy when a tool lacks a prompt type (e.g. agents on codex/crush): degrade to a skill, or skip.";
  };

  finalFiles = mkOption {
    type = types.attrsOf types.raw;
    internal = true;
    readOnly = true;
    description = "The rendered fileset (home-relative path -> file). For debugging and module internals.";
  };
}
