# Pure-eval unit tests, run with lib.runTests (empty list = all passed).
{ lib, agentPmLib }:

let
  inherit (agentPmLib)
    toYamlFrontmatter
    mkDoc
    evalPrompt
    renderFiles
    ;

  tryFails = expr: !(builtins.tryEval (builtins.deepSeq expr expr)).success;

  skill = name: {
    type = "skill";
    inherit name;
    description = "a ${name} skill";
    body = "do the ${name} thing";
  };

  exampleSet = import ../examples/prompts;

  allTools = {
    claude.enable = true;
    codex.enable = true;
    opencode.enable = true;
    crush.enable = true;
    droid.enable = true;
    pi.enable = true;
    cursor.enable = true;
  };

  rendered = renderFiles {
    prompts = exampleSet;
    tools = allTools;
  };
in
lib.runTests {
  # --- frontmatter -------------------------------------------------------
  testFrontmatterEscaping = {
    expr = toYamlFrontmatter {
      description = "a: b \"quoted\"\nnext line — ünïcode";
    };
    expected = "description: \"a: b \\\"quoted\\\"\\nnext line — ünïcode\"\n";
  };

  testFrontmatterNestedMap = {
    expr = toYamlFrontmatter {
      tools = {
        read = true;
        write = false;
      };
    };
    expected = "tools:\n  read: true\n  write: false\n";
  };

  testFrontmatterBadKeyRejected = {
    expr = tryFails (toYamlFrontmatter {
      "bad key" = 1;
    });
    expected = true;
  };

  testFrontmatterTooDeepRejected = {
    expr = tryFails (toYamlFrontmatter {
      a.b.c = 1;
    });
    expected = true;
  };

  testMkDocDropsNulls = {
    expr = mkDoc {
      name = "x";
      model = null;
    } "body\n";
    expected = "---\nname: \"x\"\n---\n\nbody\n";
  };

  # --- schema / normalization -------------------------------------------
  testFunctionPromptDefaults = {
    expr =
      (evalPrompt (
        {
          greeting ? "hello",
        }:
        {
          type = "skill";
          name = "greet";
          description = "greets";
          body = greeting;
        }
      ) { }).body;
    expected = "hello";
  };

  testFunctionPromptArgs = {
    expr =
      (evalPrompt (
        {
          greeting ? "hello",
        }:
        {
          type = "skill";
          name = "greet";
          description = "greets";
          body = greeting;
        }
      ) { greeting = "hi"; }).name;
    expected = "greet";
  };

  testBadNameRejected = {
    expr = tryFails (evalPrompt (skill "Bad_Name") { });
    expected = true;
  };

  testMissingDescriptionRejected = {
    expr = tryFails (
      evalPrompt {
        type = "skill";
        name = "x";
        body = "y";
      } { }
    );
    expected = true;
  };

  testUnknownFieldRejected = {
    expr = tryFails (evalPrompt (skill "ok" // { bogusField = 1; }) { });
    expected = true;
  };

  testUnknownTargetRejected = {
    expr = tryFails (evalPrompt (skill "ok" // { targets.bogus.enable = false; }) { });
    expected = true;
  };

  # --- markdown capture ---------------------------------------------------
  testParseMarkdownFrontmatter = {
    expr = agentPmLib.parseMarkdownDoc "---\ndescription: Fess up\nargument-hint: \"[scope]\"\n---\n\nBody line one.\nBody line two.";
    expected = {
      frontmatter = {
        description = "Fess up";
        argument-hint = "[scope]";
      };
      body = "Body line one.\nBody line two.";
    };
  };

  testParseMarkdownNoFrontmatter = {
    expr = agentPmLib.parseMarkdownDoc "Just a body.\nNo frontmatter here.";
    expected = {
      frontmatter = { };
      body = "Just a body.\nNo frontmatter here.";
    };
  };

  testPromptFromMarkdownCaptures = {
    expr =
      let
        p = evalPrompt (agentPmLib.promptFromMarkdown {
          name = "fess";
          text = "---\ndescription: Fess up\nauthor: Isaac\n---\nAssume dishonesty.";
        }) { };
      in
      {
        inherit (p)
          type
          name
          description
          body
          ;
        author = p.extraFrontmatter.author;
      };
    expected = {
      type = "skill";
      name = "fess";
      description = "Fess up";
      body = "Assume dishonesty.";
      author = "Isaac";
    };
  };

  testPromptFromMarkdownOverrides = {
    expr =
      (evalPrompt (agentPmLib.promptFromMarkdown {
        name = "wiggum";
        text = "Continue autonomously.";
        description = "Keep going until parity.";
      }) { }).description;
    expected = "Keep going until parity.";
  };

  # --- rendering ---------------------------------------------------------
  testSkillRenderedForClaude = {
    expr = rendered ? ".claude/skills/code-review-go/SKILL.md";
    expected = true;
  };

  testSkillExtraFileRendered = {
    expr = rendered ? ".claude/skills/code-review-go/references/checklist.md";
    expected = true;
  };

  testClaudeOnlyFrontmatterNotOnCodex = {
    expr =
      lib.hasInfix "allowed-tools" rendered.".claude/skills/code-review-go/SKILL.md".text
      && !lib.hasInfix "allowed-tools" rendered.".codex/skills/code-review-go/SKILL.md".text;
    expected = true;
  };

  testOpencodeSkillDeduplicated = {
    # claude target enabled -> opencode reads ~/.claude/skills itself
    expr = rendered ? ".config/opencode/skills/code-review-go/SKILL.md";
    expected = false;
  };

  testOpencodeSkillWithoutClaude = {
    expr =
      (renderFiles {
        prompts = [ (skill "solo") ];
        tools.opencode.enable = true;
      }) ? ".config/opencode/skills/solo/SKILL.md";
    expected = true;
  };

  testOpencodeSkillForced = {
    expr =
      (renderFiles {
        prompts = [ (skill "pinned" // { targets.opencode.force = true; }) ];
        tools = {
          claude.enable = true;
          opencode.enable = true;
        };
      }) ? ".config/opencode/skills/pinned/SKILL.md";
    expected = true;
  };

  testAgentNativeOnThree = {
    expr = map (p: rendered ? ${p}) [
      ".claude/agents/security-auditor.md"
      ".config/opencode/agent/security-auditor.md"
      ".factory/droids/security-auditor.md"
    ];
    expected = [
      true
      true
      true
    ];
  };

  testAgentDegradedOnCodexAndCrush = {
    expr =
      lib.hasInfix "Subagent persona" rendered.".codex/skills/security-auditor/SKILL.md".text
      && lib.hasInfix "Subagent persona" rendered.".config/crush/skills/security-auditor/SKILL.md".text;
    expected = true;
  };

  testAgentSkippedWhenPolicySkip = {
    expr =
      (renderFiles {
        prompts = [
          {
            type = "agent";
            name = "aud";
            description = "d";
            body = "b";
          }
        ];
        tools.crush.enable = true;
        defaultDegradation = "skip";
      }) == { };
    expected = true;
  };

  testCommandDegradedOnCrushIsPaletteOnly = {
    expr =
      lib.hasInfix "disable-model-invocation: true"
        rendered.".config/crush/skills/changelog/SKILL.md".text;
    expected = true;
  };

  testCommandOnCodexPromptsDir = {
    expr = rendered ? ".codex/prompts/changelog.md";
    expected = true;
  };

  testCodexCommandStrategySkill = {
    expr =
      (renderFiles {
        prompts = import ../examples/prompts;
        tools.codex = {
          enable = true;
          commandStrategy = "skill";
        };
      }) ? ".codex/skills/changelog/SKILL.md";
    expected = true;
  };

  testDroidCommandMergedIntoSkills = {
    expr =
      rendered ? ".factory/skills/changelog/SKILL.md" && !(rendered ? ".factory/commands/changelog.md");
    expected = true;
  };

  testInstructionsOrdered = {
    # order 500 ("style") must precede default 1000 ("workflow")
    expr =
      let
        text = rendered.".claude/CLAUDE.md".text;
      in
      lib.hasPrefix "## Style" text && lib.hasInfix "## Workflow" text;
    expected = true;
  };

  testInstructionsOnAllTools = {
    expr = lib.all (p: rendered ? ${p}) [
      ".claude/CLAUDE.md"
      ".codex/AGENTS.md"
      ".config/opencode/AGENTS.md"
      ".config/crush/CRUSH.md"
      ".factory/AGENTS.md"
      ".pi/agent/AGENTS.md"
    ];
    expected = true;
  };

  testPiNativeLayout = {
    # skills under ~/.pi/agent/skills, prompt templates (slash commands)
    # under ~/.pi/agent/prompts
    expr =
      rendered ? ".pi/agent/skills/code-review-go/SKILL.md"
      && rendered ? ".pi/agent/prompts/changelog.md";
    expected = true;
  };

  testPiAgentDegraded = {
    # pi deliberately ships no subagents
    expr = lib.hasInfix "Subagent persona" rendered.".pi/agent/skills/security-auditor/SKILL.md".text;
    expected = true;
  };

  testPiSkillNotDeduplicatedAgainstClaude = {
    # unlike opencode, pi does not read ~/.claude/skills by default, so its
    # skill copy must survive the claude target being enabled
    expr = rendered ? ".pi/agent/skills/code-review-go/SKILL.md";
    expected = true;
  };

  testPiPruneRootsClaimSharedSkillDir = {
    # pi reads the cross-CLI ~/.agents/skills dir; stale files there must be
    # inside the clobber/prune perimeter even when codex/crush are disabled
    expr = lib.all (r: lib.elem r (agentPmLib.pruneRootsFor { pi.enable = true; })) [
      ".agents/skills"
      ".pi/agent/skills"
      ".pi/agent/prompts"
      ".pi/agent/AGENTS.md"
    ];
    expected = true;
  };

  testCursorNativeLayout = {
    # Agent Skills under ~/.cursor/skills; no commands/instructions paths yet
    expr = rendered ? ".cursor/skills/code-review-go/SKILL.md";
    expected = true;
  };

  testCursorAgentDegraded = {
    expr = lib.hasInfix "Subagent persona" rendered.".cursor/skills/security-auditor/SKILL.md".text;
    expected = true;
  };

  testCursorCommandDegraded = {
    # commands become palette-only skills
    expr =
      rendered ? ".cursor/skills/changelog/SKILL.md"
      && lib.hasInfix "disable-model-invocation" rendered.".cursor/skills/changelog/SKILL.md".text;
    expected = true;
  };

  testCursorSkipsInstructions = {
    expr = rendered ? ".cursor/AGENTS.md" || rendered ? ".cursor/CLAUDE.md";
    expected = false;
  };

  testCursorPruneRoots = {
    expr = agentPmLib.pruneRootsFor { cursor.enable = true; };
    expected = [ ".cursor/skills" ];
  };

  testCursorSkillNotDeduplicatedAgainstClaude = {
    # cursor does not read ~/.claude/skills, so its copy must survive
    expr = rendered ? ".cursor/skills/code-review-go/SKILL.md";
    expected = true;
  };

  testTargetDisablePerTool = {
    expr =
      (renderFiles {
        prompts = [ (skill "hidden" // { targets.claude.enable = false; }) ];
        tools = {
          claude.enable = true;
          droid.enable = true;
        };
      }) == {
        ".factory/skills/hidden/SKILL.md".text =
          "---\nname: \"hidden\"\ndescription: \"a hidden skill\"\n---\n\ndo the hidden thing\n";
      };
    expected = true;
  };

  testCodexPruneRootsClaimLegacyDirs = {
    # codex also reads ~/.agents/skills and ~/.codex/agents; stale files
    # there must be inside the clobber/prune perimeter
    expr = lib.all (r: lib.elem r (agentPmLib.pruneRootsFor { codex.enable = true; })) [
      ".agents/skills"
      ".codex/agents"
      ".codex/skills"
    ];
    expected = true;
  };

  testCrushPruneRootsClaimSharedSkillDirs = {
    # crush surfaces commands from skills and reads the cross-CLI
    # ~/.agents/skills and ~/.config/agents/skills dirs; stale files there
    # must be inside the clobber/prune perimeter even without codex enabled
    expr = lib.all (r: lib.elem r (agentPmLib.pruneRootsFor { crush.enable = true; })) [
      ".agents/skills"
      ".config/agents/skills"
      ".config/crush/skills"
    ];
    expected = true;
  };

  testCrushDoesNotClaimClaudeSkills = {
    # crush also reads ~/.claude/skills, but enabling crush alone must NOT
    # claim it — clobbering there would delete real Claude Code skills
    expr = lib.elem ".claude/skills" (agentPmLib.pruneRootsFor { crush.enable = true; });
    expected = false;
  };

  testDuplicatePromptsRejected = {
    expr = tryFails (renderFiles {
      prompts = [
        (skill "dup")
        (skill "dup")
      ];
      tools.claude.enable = true;
    });
    expected = true;
  };

  testUnknownToolRejected = {
    expr = tryFails (renderFiles {
      prompts = [ (skill "x") ];
      tools.bogus.enable = true;
    });
    expected = true;
  };
}
