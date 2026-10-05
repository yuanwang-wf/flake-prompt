# Tool registry: each backend is a function from its per-tool options
# (e.g. commandStrategy) to a ToolDef:
#   { name, supports.<type>, paths.{skillDir,agentFile,commandFile,instructions},
#     frontmatter.<type>, pruneRoots, skillsSharedWith? }
{ lib }:

{
  claude = import ./claude.nix { inherit lib; };
  codex = import ./codex.nix { inherit lib; };
  opencode = import ./opencode.nix { inherit lib; };
  crush = import ./crush.nix { inherit lib; };
  droid = import ./droid.nix { inherit lib; };
  pi = import ./pi.nix { inherit lib; };
  cursor = import ./cursor.nix { inherit lib; };
}
