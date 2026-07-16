# home-manager module: programs.agent-pm.* -> home.file.
# Imports the agent-pm lib relative to itself, so consumers can use
# `imports = [ inputs.agent-pm.homeManagerModules.default ]` with no
# specialArgs plumbing.
{ config, lib, ... }:

let
  cfg = config.programs.agent-pm;
  agentPmLib = import ../lib { inherit lib; };
in
{
  options.programs.agent-pm = import ./options.nix { inherit lib; } // {
    clobberForeignFiles = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Treat the prompt roots of the enabled tools as owned exclusively by
        agent-pm: at activation (before home-manager checks link targets),
        delete regular files under them that agent-pm did not put there —
        leftovers from hand installs or retired deployers that the tools
        would otherwise keep listing alongside the managed prompts.

        Only regular files are removed (home-manager's own links are
        symlinks and untouched); hidden entries (dotfiles/dot-directories,
        e.g. codex's bundled `skills/.system`) are skipped; directories
        left empty are cleaned up.
      '';
    };
  };

  config = {
    programs.agent-pm.finalFiles =
      if cfg.enable then
        agentPmLib.renderFiles {
          inherit (cfg) prompts tools deduplicateSharedPaths;
          defaultDegradation = cfg.defaults.degradation;
        }
      else
        { };

    home.file = lib.mkIf cfg.enable (
      lib.mapAttrs (
        _: f: if f ? text then { inherit (f) text; } else { inherit (f) source executable; }
      ) cfg.finalFiles
    );

    # Runs before checkLinkTargets so a foreign real file sitting at a
    # managed path never aborts the switch — the install clobbers it.
    home.activation.agentPmClobber = lib.mkIf (cfg.enable && cfg.clobberForeignFiles) (
      lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        agentPmClobberRoot() {
          local t="$HOME/$1"
          if [ -L "$t" ]; then
            return 0
          elif [ -f "$t" ]; then
            run rm -f "$t"
          elif [ -d "$t" ]; then
            find "$t" -mindepth 1 -name '.*' -prune -o -type f -print0 \
              | while IFS= read -r -d "" f; do run rm -f "$f"; done
            if [ -z "''${DRY_RUN:-}" ]; then
              find "$t" -depth -mindepth 1 -type d -empty -delete
            fi
          fi
        }
        ${lib.concatMapStringsSep "\n" (root: "agentPmClobberRoot ${lib.escapeShellArg root}") (
          agentPmLib.pruneRootsFor cfg.tools
        )}
      ''
    );
  };
}
