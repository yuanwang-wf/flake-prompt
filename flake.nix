{
  description = "agent-pm: declare AI-agent prompts once in Nix, render them for Claude Code, Codex, opencode, Crush, Droid, pi, and Cursor";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Used only by the flake checks; core outputs do not depend on it.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      lib = nixpkgs.lib;
      agentPmLib = import ./lib { inherit lib; };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      eachSystem = f: lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});

      examplePrompts = import ./examples/prompts;
      allTools = {
        claude.enable = true;
        codex.enable = true;
        opencode.enable = true;
        crush.enable = true;
        droid.enable = true;
        pi.enable = true;
        cursor.enable = true;
      };
    in
    {
      lib = agentPmLib // {
        # lib.mkPromptsPackage pkgs { prompts, tools, ... } -> derivation
        # whose $out mirrors the home-relative tree.
        mkPromptsPackage = pkgs: import ./pkgs/mk-prompts-package.nix { inherit pkgs agentPmLib; };
      };

      homeManagerModules = {
        agent-pm = import ./modules/home-manager.nix;
        default = import ./modules/home-manager.nix;
      };

      nixosModules = {
        agent-pm = import ./modules/nixos.nix;
        default = import ./modules/nixos.nix;
      };

      templates.default = {
        path = ./templates/default;
        description = "Consumer flake: declare prompts once, render for every agent CLI";
      };

      packages = eachSystem (
        system: pkgs: {
          example = self.lib.mkPromptsPackage pkgs {
            name = "agent-pm-example";
            prompts = examplePrompts;
            tools = allTools;
          };

          docs =
            let
              eval = lib.evalModules {
                modules = [
                  { options.programs.agent-pm = import ./modules/options.nix { inherit lib; }; }
                ];
              };
            in
            (pkgs.nixosOptionsDoc { options = eval.options; }).optionsCommonMark;
        }
      );

      checks = eachSystem (
        system: pkgs:
        {
          unit =
            let
              failures = import ./tests/unit.nix { inherit lib agentPmLib; };
            in
            if failures == [ ] then
              pkgs.runCommandLocal "agent-pm-unit-tests" { } "touch $out"
            else
              throw "agent-pm unit tests failed:\n${
                lib.concatMapStringsSep "\n" (
                  t: "- ${t.name}: expected ${builtins.toJSON t.expected}, got ${builtins.toJSON t.result}"
                ) failures
              }";

          golden = pkgs.runCommandLocal "agent-pm-golden" { } ''
            diff -r ${self.packages.${system}.example} ${./tests/golden}
            touch $out
          '';

          hm-eval =
            let
              hmConfig = home-manager.lib.homeManagerConfiguration {
                inherit pkgs;
                modules = [
                  self.homeManagerModules.default
                  {
                    home = {
                      username = "test";
                      homeDirectory = "/home/test";
                      stateVersion = "25.05";
                    };
                    programs.agent-pm = {
                      enable = true;
                      prompts = examplePrompts;
                      tools = allTools;
                    };
                  }
                ];
              };
              files = hmConfig.config.home.file;
            in
            assert files ? ".claude/skills/code-review-go/SKILL.md";
            assert lib.hasInfix "strict" files.".claude/skills/code-review-go/SKILL.md".text;
            assert files ? ".factory/droids/security-auditor.md";
            assert lib.hasInfix ".agents/skills" hmConfig.config.home.activation.agentPmClobber.data;
            pkgs.runCommandLocal "agent-pm-hm-eval" { } "touch $out";
        }
        // lib.optionalAttrs (lib.hasSuffix "-linux" system) {
          nixos-eval =
            let
              nixosConfig = lib.nixosSystem {
                inherit system;
                modules = [
                  self.nixosModules.default
                  {
                    services.agent-pm = {
                      enable = true;
                      users.test = {
                        enable = true;
                        prompts = examplePrompts;
                        tools = allTools;
                      };
                    };
                  }
                ];
              };
              rules = nixosConfig.config.systemd.user.tmpfiles.users.test.rules;
            in
            assert rules != [ ];
            assert lib.any (r: lib.hasInfix ".claude/skills/code-review-go/SKILL.md" r) rules;
            pkgs.runCommandLocal "agent-pm-nixos-eval" { } "touch $out";
        }
      );

      formatter = eachSystem (_: pkgs: pkgs.nixfmt-rfc-style);
    };
}
