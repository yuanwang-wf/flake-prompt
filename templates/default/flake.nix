{
  description = "My agent prompts, managed with agent-pm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    agent-pm.url = "github:OWNER/agent-pm"; # TODO: point at your agent-pm
  };

  outputs =
    {
      self,
      nixpkgs,
      agent-pm,
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    {
      # Your prompt library: attrsets and functions other configs can import.
      lib.prompts = import ./prompts;

      # Standalone rendered tree, for inspection or manual installation:
      #   nix build .# && ls result/
      packages = eachSystem (system: rec {
        default = agent-pm.lib.mkPromptsPackage nixpkgs.legacyPackages.${system} {
          prompts = [
            (self.lib.prompts.code-review {
              lang = "go";
              strictness = "strict";
            })
            self.lib.prompts.style-instructions
          ];
          tools = {
            claude.enable = true;
            codex.enable = true;
            opencode.enable = true;
            crush.enable = true;
            droid.enable = true;
            pi.enable = true;
          };
        };
      });

      # In a home-manager configuration:
      #
      #   imports = [ inputs.agent-pm.homeManagerModules.default ];
      #   programs.agent-pm = {
      #     enable = true;
      #     tools.claude.enable = true;
      #     tools.opencode.enable = true;
      #     prompts = [
      #       (inputs.my-prompts.lib.prompts.code-review { lang = "go"; })
      #       inputs.my-prompts.lib.prompts.style-instructions
      #     ];
      #   };
      #
      # On NixOS without home-manager:
      #
      #   imports = [ inputs.agent-pm.nixosModules.default ];
      #   services.agent-pm = {
      #     enable = true;
      #     users.alice = {
      #       enable = true;
      #       tools.claude.enable = true;
      #       prompts = [ ... ];
      #     };
      #   };
    };
}
