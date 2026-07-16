# YAML frontmatter generation.
#
# Scalars are encoded with builtins.toJSON: JSON is a strict subset of
# YAML 1.2, so descriptions containing colons, quotes, or newlines are
# handled without a YAML emitter. Exactly one level of attrset nesting is
# allowed (needed for opencode's `tools:` map); anything deeper is an
# authoring error.
{ lib }:

let
  keyPattern = "[A-Za-z0-9_-]+";

  checkKey =
    context: k:
    lib.assertMsg (
      builtins.match keyPattern k != null
    ) "agent-pm: invalid frontmatter key '${k}'${context} (allowed: ${keyPattern})";

  encodeLeaf = v: builtins.toJSON v;

  # Emit well-known keys in the conventional order, then the rest
  # alphabetically (attrset iteration order).
  keyPriority = [
    "name"
    "description"
  ];
  orderedNames =
    attrs:
    lib.filter (k: attrs ? ${k}) keyPriority
    ++ lib.filter (k: !lib.elem k keyPriority) (lib.attrNames attrs);
in
rec {
  toYamlFrontmatter =
    attrs:
    lib.concatMapStrings (
      k:
      let
        v = attrs.${k};
      in
      assert checkKey "" k;
      if builtins.isAttrs v then
        "${k}:\n"
        + lib.concatStrings (
          lib.mapAttrsToList (
            k2: v2:
            assert checkKey " (under '${k}')" k2;
            assert lib.assertMsg (
              !builtins.isAttrs v2
            ) "agent-pm: frontmatter nesting deeper than one level is not supported (key '${k}.${k2}')";
            "  ${k2}: ${encodeLeaf v2}\n"
          ) v
        )
      else
        "${k}: ${encodeLeaf v}\n"
    ) (orderedNames attrs);

  # Render a markdown document with optional frontmatter. Null-valued
  # frontmatter keys are dropped; the body always ends in one newline.
  mkDoc =
    fm: body:
    let
      fm' = lib.filterAttrs (_: v: v != null) fm;
      body' = lib.removeSuffix "\n" body;
    in
    lib.optionalString (fm' != { }) ("---\n" + toYamlFrontmatter fm' + "---\n\n") + body' + "\n";
}
