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
  options.programs.agent-pm = import ./options.nix { inherit lib; };

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
  };
}
