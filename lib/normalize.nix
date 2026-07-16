# Prompt normalization and validation.
#
# The authoring surface is a plain attrset, or a function from an argument
# attrset to a prompt attrset (all arguments should carry defaults via `?`
# so the prompt is also instantiable with `{ }`).
{
  lib,
  schema,
  toolNames,
}:

let
  evalAttrs =
    attrs:
    let
      name = attrs.name or "<unnamed>";
      evaluated =
        (lib.evalModules {
          modules = [
            schema.promptModule
            attrs
          ];
        }).config;
    in
    builtins.addErrorContext "while evaluating agent-pm prompt '${name}'" (check evaluated);

  check =
    p:
    assert lib.assertMsg (
      p.type == "instructions" || p.description != null
    ) "agent-pm: prompt '${p.name}' of type '${p.type}' requires a description";
    assert lib.assertMsg (
      p.files == { } || p.type == "skill"
    ) "agent-pm: prompt '${p.name}': `files` is only supported for skills";
    assert lib.assertMsg (lib.all (f: (f.text == null) != (f.source == null)) (
      lib.attrValues p.files
    )) "agent-pm: prompt '${p.name}': each entry in `files` must set exactly one of `text` or `source`";
    assert lib.assertMsg (lib.all (t: lib.elem t toolNames) (lib.attrNames p.targets))
      "agent-pm: prompt '${p.name}': unknown tool in `targets` (known tools: ${lib.concatStringsSep ", " toolNames})";
    p;
in
rec {
  # evalPrompt : (attrset | function) -> args -> canonical prompt
  evalPrompt =
    promptOrFn: args:
    if builtins.isFunction promptOrFn then
      evalAttrs (promptOrFn args)
    else
      assert lib.assertMsg (
        args == { }
      ) "agent-pm: evalPrompt: arguments were given but the prompt is a plain attrset, not a function";
      evalAttrs promptOrFn;

  # Normalize with defaults; idempotent on already-normalized prompts.
  normalizePrompt = p: evalPrompt p { };

  # Convenience for prompt-library flakes: an attrset of prompts (attrsets
  # or functions). Attrset prompts are validated eagerly; functions are
  # validated when instantiated. Returns the set plus an `asList` view.
  mkPromptSet =
    { prompts }:
    let
      validated = lib.mapAttrs (_: p: if builtins.isFunction p then p else normalizePrompt p) prompts;
    in
    {
      prompts = validated;
      asList = lib.attrValues validated;
    };
}
