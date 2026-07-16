# A parameterized prompt: a function from arguments to a canonical prompt.
# Give every argument a default so the prompt also works uninstantiated.
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

  # Tool-specific extras: only Claude Code understands `allowed-tools`.
  targets.claude.extraFrontmatter."allowed-tools" = "Read, Grep, Bash(git diff:*)";
}
