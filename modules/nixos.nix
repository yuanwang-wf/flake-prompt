# NixOS module for HM-less systems: services.agent-pm.users.<name>.* ->
# per-file symlinks into user homes via systemd-tmpfiles.
#
# Caveats vs home-manager (the recommended path):
#  - `L+` rules replace whatever exists at the target path, including a
#    hand-written ~/.claude/CLAUDE.md. Links are per rendered file, never a
#    whole tool directory, so mutable state (settings.json, auth) is safe.
#  - tmpfiles never removes rules dropped from the config; pruneStaleLinks
#    cleans up at the next user login by deleting symlinks that point into
#    stale agent-pm store paths (and then empty directories under the
#    managed roots).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkOption mkEnableOption types;

  cfg = config.services.agent-pm;
  agentPmLib = import ../lib { inherit lib; };
  mkPromptsPackage = import ../pkgs/mk-prompts-package.nix { inherit pkgs agentPmLib; };

  userSubmodule = types.submodule (
    { config, ... }:
    {
      options = import ./options.nix { inherit lib; };
      config.finalFiles =
        if config.enable then
          agentPmLib.renderFiles {
            inherit (config) prompts tools deduplicateSharedPaths;
            defaultDegradation = config.defaults.degradation;
          }
        else
          { };
    }
  );

  enabledUsers = lib.filterAttrs (_: u: u.enable) cfg.users;

  packageFor = lib.mapAttrs (
    user: ucfg:
    mkPromptsPackage {
      name = "agent-pm-prompts-${user}";
      inherit (ucfg) prompts tools deduplicateSharedPaths;
      defaultDegradation = ucfg.defaults.degradation;
    }
  ) enabledUsers;
in
{
  options.services.agent-pm = {
    enable = mkEnableOption "agent-pm prompt management (for systems without home-manager)";

    pruneStaleLinks = mkOption {
      type = types.bool;
      default = true;
      description = ''
        On user login, delete symlinks under the managed roots that point
        into agent-pm store paths other than the current one (i.e. prompts
        removed from the configuration), then remove directories left empty.
        Only agent-pm's own links are ever touched.
      '';
    };

    users = mkOption {
      type = types.attrsOf userSubmodule;
      default = { };
      description = "Per-user prompt configuration (same options as the home-manager module).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.tmpfiles.users = lib.mapAttrs (user: ucfg: {
      rules = lib.mapAttrsToList (
        path: _: "L+ %h/${path} - - - - ${packageFor.${user}}/${path}"
      ) ucfg.finalFiles;
    }) enabledUsers;

    system.userActivationScripts.agent-pm-prune = lib.mkIf cfg.pruneStaleLinks {
      text = ''
        agent_pm_prune_root() {
          local t="$HOME/$1" cur="$2" link
          if [ -L "$t" ]; then
            link=$(readlink "$t")
            case "$link" in
              ${builtins.storeDir}/*-agent-pm-prompts*)
                case "$link" in
                  "$cur"/*) ;;
                  *) rm -f "$t" ;;
                esac ;;
            esac
          elif [ -d "$t" ]; then
            find "$t" -type l -lname '${builtins.storeDir}/*-agent-pm-prompts*' ! -lname "$cur/*" -delete || true
            find "$t" -depth -mindepth 1 -type d -empty -delete || true
          fi
        }
        case "$USER" in
        ${lib.concatStrings (
          lib.mapAttrsToList (user: ucfg: ''
            ${user})
            ${lib.concatMapStringsSep "\n" (
              root: "agent_pm_prune_root ${lib.escapeShellArg root} ${packageFor.${user}}"
            ) (agentPmLib.pruneRootsFor ucfg.tools)}
              ;;
          '') enabledUsers
        )}
        esac
      '';
    };
  };
}
