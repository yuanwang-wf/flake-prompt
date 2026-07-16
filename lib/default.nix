# agent-pm public library. Pure and pkgs-free:
#   lib = import ./lib { inherit (nixpkgs) lib; };
{ lib }:

let
  frontmatter = import ./frontmatter.nix { inherit lib; };
  schema = import ./schema.nix { inherit lib; };
  toolRegistry = import ./tools { inherit lib; };
  normalize = import ./normalize.nix {
    inherit lib schema;
    toolNames = lib.attrNames toolRegistry;
  };
  degrade = import ./degrade.nix { inherit lib; };
  markdown = import ./markdown.nix { inherit lib; };
  render = import ./render.nix {
    inherit
      lib
      frontmatter
      normalize
      degrade
      toolRegistry
      ;
  };
in
{
  inherit (normalize) evalPrompt normalizePrompt mkPromptSet;
  inherit (render) renderFiles pruneRootsFor;
  inherit (frontmatter) toYamlFrontmatter mkDoc;
  inherit (markdown) parseMarkdownDoc promptFromMarkdown skillFromDir;
  inherit (degrade) degradeToSkill;
  inherit toolRegistry schema;
  toolNames = lib.attrNames toolRegistry;
}
