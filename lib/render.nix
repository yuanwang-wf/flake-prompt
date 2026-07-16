# The fileset engine: canonical prompts + tool config -> flat fileset.
#
# FileSet = attrsOf ({ text } | { source, executable }) keyed by
# home-relative path (".claude/skills/foo/SKILL.md", ...).
{
  lib,
  frontmatter,
  normalize,
  degrade,
  toolRegistry,
}:

let
  inherit (frontmatter) mkDoc;
  toolNames = lib.attrNames toolRegistry;

  targetCfg = tool: p: p.targets.${tool.name} or { };

  bodyFor =
    tool: p:
    let
      override = (targetCfg tool p).body or null;
    in
    if override != null then override else p.body;

  frontmatterFor =
    tool: type: p:
    (tool.frontmatter.${type} p) // p.extraFrontmatter // ((targetCfg tool p).extraFrontmatter or { });

  normalizeFileEntry =
    f: if f.text != null then { inherit (f) text; } else { inherit (f) source executable; };

  renderSkill =
    tool: p:
    {
      "${tool.paths.skillDir p.name}/SKILL.md".text = mkDoc (frontmatterFor tool "skill" p) (
        bodyFor tool p
      );
    }
    // lib.mapAttrs' (
      rel: f: lib.nameValuePair "${tool.paths.skillDir p.name}/${rel}" (normalizeFileEntry f)
    ) p.files;

  renderAgent = tool: p: {
    "${tool.paths.agentFile p.name}".text = mkDoc (frontmatterFor tool "agent" p) (bodyFor tool p);
  };

  renderCommand = tool: p: {
    "${tool.paths.commandFile p.name}".text = mkDoc (frontmatterFor tool "command" p) (bodyFor tool p);
  };

  renderInstructions =
    tool: ps:
    lib.optionalAttrs (ps != [ ]) {
      "${tool.paths.instructions}".text =
        lib.concatMapStringsSep "\n\n" (p: lib.removeSuffix "\n" (bodyFor tool p)) (
          lib.sort (a: b: a.order < b.order || (a.order == b.order && a.name < b.name)) ps
        )
        + "\n";
    };

  renderersByType = {
    skill = renderSkill;
    agent = renderAgent;
    command = renderCommand;
  };
in
rec {
  # renderFiles :
  #   { prompts               : [ attrset | function ]
  #   , tools                 : { <tool> = bool | { enable, ... }; }
  #   , deduplicateSharedPaths ? true
  #   , defaultDegradation     ? "skill"
  #   } -> FileSet
  renderFiles =
    {
      prompts,
      tools ? { },
      deduplicateSharedPaths ? true,
      defaultDegradation ? "skill",
    }:
    let
      toolCfgs = lib.mapAttrs (_: v: if builtins.isBool v then { enable = v; } else v) tools;
      unknown = lib.filter (n: !(lib.elem n toolNames)) (lib.attrNames toolCfgs);
      enabled = lib.filterAttrs (_: c: c.enable or false) toolCfgs;

      normalized = map normalize.normalizePrompt prompts;
      keys = map (p: "${p.type}/${p.name}") normalized;
      duplicates = lib.filter (k: lib.count (x: x == k) keys > 1) (lib.unique keys);

      perTool = lib.mapAttrsToList (
        name: cfg: renderTool (toolRegistry.${name} (removeAttrs cfg [ "enable" ]))
      ) enabled;

      renderTool =
        tool:
        let
          visible = lib.filter (p: (targetCfg tool p).enable or true) normalized;

          resolve =
            p:
            if p.type == "instructions" || tool.supports.${p.type} then
              [ p ]
            else if (if p.degradation != null then p.degradation else defaultDegradation) == "skip" then
              [ ]
            else
              [ (degrade.degradeToSkill p) ];

          effective = lib.concatMap resolve visible;
          byType = lib.groupBy (p: p.type) effective;

          # Skip skills the shared-path tool already picks up (opencode
          # reads ~/.claude/skills) unless forced per prompt.
          sharedWith = tool.skillsSharedWith or null;
          dedupeActive = deduplicateSharedPaths && sharedWith != null && enabled ? ${sharedWith};
          skills =
            if dedupeActive then
              lib.filter (p: (targetCfg tool p).force or false) (byType.skill or [ ])
            else
              byType.skill or [ ];
          byType' = byType // {
            skill = skills;
          };

          skillNames = map (p: p.name) (byType.skill or [ ]);
          skillDups = lib.filter (n: lib.count (x: x == n) skillNames > 1) (lib.unique skillNames);
        in
        assert lib.assertMsg (skillDups == [ ])
          "agent-pm: name collision after degradation on tool '${tool.name}': ${lib.concatStringsSep ", " (lib.unique skillDups)}";
        lib.foldl' (acc: type: acc // renderTypeFor tool type (byType'.${type} or [ ])) (renderInstructions
          tool
          (byType'.instructions or [ ])
        ) (lib.attrNames renderersByType);

      renderTypeFor =
        tool: type: ps:
        lib.foldl' (acc: p: acc // renderersByType.${type} tool p) { } ps;
    in
    assert lib.assertMsg (unknown == [ ])
      "agent-pm: unknown tool(s) in `tools`: ${lib.concatStringsSep ", " unknown} (known: ${lib.concatStringsSep ", " toolNames})";
    assert lib.assertMsg (
      duplicates == [ ]
    ) "agent-pm: duplicate prompts: ${lib.concatStringsSep ", " (lib.unique duplicates)}";
    lib.foldl' (acc: fs: acc // fs) { } perTool;

  # Prune roots (dirs/files a tool's rendered output may live under) for
  # the enabled tools — used by the NixOS module's stale-link cleanup.
  pruneRootsFor =
    tools:
    let
      toolCfgs = lib.mapAttrs (_: v: if builtins.isBool v then { enable = v; } else v) tools;
      enabled = lib.filterAttrs (_: c: c.enable or false) toolCfgs;
    in
    lib.unique (lib.concatMap (name: (toolRegistry.${name} { }).pruneRoots) (lib.attrNames enabled));
}
