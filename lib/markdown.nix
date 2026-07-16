# Capture existing prompt markdown (Claude/Codex-style commands, SKILL.md
# files) into canonical prompts, so prompt content maintained outside Nix
# can be imported without duplicating it.
#
# Frontmatter parsing is deliberately minimal: single-line `key: value`
# scalars only (quoted or bare). That covers real-world command/skill
# frontmatter; anything fancier should be declared in Nix directly.
{ lib }:

let
  scalarLine = "([A-Za-z0-9_-]+): *(.*)";

  unquote =
    v:
    let
      m = builtins.match "\"(.*)\"|'(.*)'" v;
    in
    if m == null then v else lib.findFirst (x: x != null) v m;

  parseSimpleYaml = lines: lib.foldl' (
    acc: line:
    let
      m = builtins.match scalarLine line;
    in
    if m == null then acc else acc // { ${lib.head m} = unquote (lib.last m); }
  ) { } lines;

  dropWhile =
    pred: xs:
    if xs == [ ] || !pred (lib.head xs) then xs else dropWhile pred (lib.tail xs);
in
rec {
  # parseMarkdownDoc : str -> { frontmatter : attrsOf str; body : str; }
  parseMarkdownDoc =
    text:
    let
      lines = lib.splitString "\n" text;
      rest = lib.tail lines;
      endIdx = lib.lists.findFirstIndex (l: l == "---") null rest;
      noFrontmatter = {
        frontmatter = { };
        body = text;
      };
    in
    if lines == [ ] || lib.head lines != "---" || endIdx == null then
      noFrontmatter
    else
      {
        frontmatter = parseSimpleYaml (lib.take endIdx rest);
        body = lib.concatStringsSep "\n" (
          dropWhile (l: l == "") (lib.drop (endIdx + 1) rest)
        );
      };

  # Capture a single markdown prompt file (or literal text).
  #
  #   promptFromMarkdown {
  #     type ? "skill";           # skill | command | agent | instructions
  #     name;
  #     source ? null;            # path to the .md file
  #     text ? null;              # ... or its contents directly
  #     keepExtraFrontmatter ? true;  # carry unknown scalars (author, ...) through
  #     ...                       # any other canonical prompt fields, merged last
  #   }
  #
  # Frontmatter mapping: description -> description, argument-hint ->
  # argumentHint (commands only); remaining scalars land in extraFrontmatter
  # unless keepExtraFrontmatter = false. Explicit fields win over captured ones.
  promptFromMarkdown =
    {
      type ? "skill",
      name,
      source ? null,
      text ? null,
      keepExtraFrontmatter ? true,
      ...
    }@args:
    let
      raw =
        if text != null then
          text
        else if source != null then
          builtins.readFile source
        else
          throw "agent-pm: promptFromMarkdown '${name}': one of `source` or `text` is required";
      doc = parseMarkdownDoc raw;
      fm = doc.frontmatter;
      extra = removeAttrs fm [
        "name"
        "description"
        "argument-hint"
      ];
      captured = {
        inherit type name;
        body = doc.body;
      }
      // lib.optionalAttrs (fm ? description) { inherit (fm) description; }
      // lib.optionalAttrs (type == "command" && fm ? "argument-hint") {
        argumentHint = fm."argument-hint";
      }
      // lib.optionalAttrs (keepExtraFrontmatter && extra != { }) { extraFrontmatter = extra; };
    in
    captured
    // removeAttrs args [
      "type"
      "name"
      "source"
      "text"
      "keepExtraFrontmatter"
    ];

  # Capture a whole skill directory: SKILL.md plus every other file in the
  # directory (references/, scripts/, ...) as skill `files`.
  skillFromDir =
    {
      dir,
      name ? builtins.unsafeDiscardStringContext (baseNameOf dir),
      exclude ? [ "README.md" ],
      ...
    }@args:
    let
      allFiles = lib.filesystem.listFilesRecursive dir;
      # Keys (skill name, relative file names) must be context-free strings:
      # `dir` may be "${flakeInput}/..." and attribute names cannot refer to
      # store paths. The file *sources* keep their context, so the
      # dependency on the input is preserved.
      rel =
        path: builtins.unsafeDiscardStringContext (lib.removePrefix "${toString dir}/" (toString path));
      extraFiles = lib.filter (
        p: rel p != "SKILL.md" && !lib.elem (rel p) exclude
      ) allFiles;
    in
    promptFromMarkdown (
      {
        type = "skill";
        inherit name;
        source = dir + "/SKILL.md";
        files = lib.listToAttrs (
          map (p: lib.nameValuePair (rel p) { source = p; }) extraFiles
        );
      }
      // removeAttrs args [
        "dir"
        "name"
        "exclude"
      ]
    );
}
