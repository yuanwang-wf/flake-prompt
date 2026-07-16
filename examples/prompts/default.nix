# Example prompt set used by the flake checks and golden tests.
# This is what a consumer prompt library looks like.
let
  code-review =
    {
      lang ? "nix",
      strictness ? "standard",
      conventions ? [ ],
    }:
    {
      type = "skill";
      name = "code-review-${lang}";
      description = "Review ${lang} code at ${strictness} strictness for correctness and style.";
      body = ''
        # Code review: ${lang}

        Review the changed ${lang} code. Strictness level: **${strictness}**.

        Work through references/checklist.md and report findings ranked by severity.
      ''
      + (
        if conventions == [ ] then
          ""
        else
          ''

            ## Team conventions

            ${builtins.concatStringsSep "\n" (map (c: "- ${c}") conventions)}
          ''
      );
      files."references/checklist.md".text = ''
        # ${lang} review checklist

        - Correctness: edge cases, error handling
        - Style: naming, idiom, comment density of surrounding code
      '';
      targets.claude.extraFrontmatter."allowed-tools" = "Read, Grep, Bash(git diff:*)";
    };
in
[
  (code-review {
    lang = "go";
    strictness = "strict";
    conventions = [
      "errors are wrapped with %w"
      "table-driven tests"
    ];
  })

  {
    type = "agent";
    name = "security-auditor";
    description = "Read-only security audit subagent focusing on injection, authz, and secrets.";
    tools = [
      "read"
      "grep"
    ];
    model = "claude-fable-5";
    body = ''
      You are a security auditor. Review code for injection, authorization
      gaps, and leaked secrets. You never modify files; report findings with
      file:line references, ranked by severity.
    '';
  }

  {
    type = "command";
    name = "changelog";
    description = "Draft a changelog entry from the current diff.";
    argumentHint = "[version]";
    body = ''
      Draft a changelog entry for version $ARGUMENTS based on the current
      git diff. Group changes under Added/Changed/Fixed.
    '';
  }

  {
    type = "instructions";
    name = "style";
    order = 500;
    body = ''
      ## Style

      Prefer small, focused commits. Match the comment density of the
      surrounding code.
    '';
  }

  {
    type = "instructions";
    name = "workflow";
    body = ''
      ## Workflow

      Run the test suite before declaring any task complete.
    '';
  }
]
