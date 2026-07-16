# FileSet -> derivation: $out mirrors the home-relative tree
# ($out/.claude/skills/..., $out/.config/opencode/..., ...).
# Useful standalone (`nix build`, then symlink/rsync yourself) and as the
# store payload the NixOS module links into user homes.
{ pkgs, agentPmLib }:

{
  name ? "agent-pm-prompts",
  ...
}@args:
let
  inherit (pkgs) lib;
  files = agentPmLib.renderFiles (builtins.removeAttrs args [ "name" ]);

  install =
    path: f:
    let
      src = if f ? text then pkgs.writeText (builtins.baseNameOf path) f.text else f.source;
    in
    ''
      mkdir -p "$out/${builtins.dirOf path}"
      cp ${src} "$out/${path}"
    ''
    + lib.optionalString (f.executable or false) ''
      chmod +x "$out/${path}"
    '';
in
pkgs.runCommandLocal name { } (lib.concatStrings (lib.mapAttrsToList install files))
