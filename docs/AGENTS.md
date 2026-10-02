# The agent roster

Thirty-one specialist subagents live in `.claude/agents/`, copied on 2026-10-02 from
[msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT, commit `d3f71c4`; the licence is
kept beside them as `.claude/agents/LICENSE-agency-agents`). They are generic prompts: they know their craft, not
Rootward. Whoever spawns one passes the project's rules (`AGENT.md`, `CLAUDE.md`, the ADR in question) in the task.

The rest of the upstream roster (about 250 agents: marketing, sales, finance, healthcare, web frameworks, a Godot
multiplayer engineer) was left out on purpose. Rootward has no server, no multiplayer and no monetization
(`AGENT.md` section 4). Anything missing can be copied in from the upstream repo by hand.

Each file is a plain agent: front matter (`name`, `description`) plus a prompt, no tool restrictions, so it inherits
the session's tools and permissions.

## Which agent for which job

| Area | Agent | Use it for in Rootward |
|---|---|---|
| Game design | Game Designer | Paradigms, classes (Kurogane next, `docs/SHARDRUN_DESIGN.md`), core-loop and session pacing |
| | Economy Designer | Mana, tempo, relic and loot tables, the speed race; read alongside `docs/research/balance-probe/` |
| | Level Designer | The layer map, room mix, ring pacing (ADR-0025) |
| | Narrative Designer, Narratologist | Guardians' voices, flavour text, Pip's Trial, the world of the Rings |
| Godot | Godot Gameplay Scripter | Typed GDScript, signals, scene composition in `game/scenes/` and `game/ui/` |
| | Godot Shader Developer | The toon and anime shaders, dungeon lights, MToon (ADR-0029) |
| | Technical Artist | Art-to-engine budgets, import settings, sprite and VRM fitting |
| Assets | Blender Add-on Engineer | The Blender scripts in `pipeline/blender` and `pipeline/moves` (with the `rootward-characters` skill) |
| | Image Prompt Engineer | ComfyUI prompts in `pipeline/art` and the concept briefs |
| | Game Audio Engineer | `pipeline/audio`, `docs/SOUND_DESIGN.md`, music scores |
| Interface | UI Designer, UX Architect | Kernel Foundry front end, the card table, the work surface |
| | UX Researcher | Judging the first-run flow, how the daughters meet the game |
| | Whimsy Injector | Small delight: hover lines, idle motion, end-screen jokes |
| | Visual Storyteller | Concept boards and consistent mood across rooms |
| | Accessibility Auditor | Contrast, font size, keyboard and controller reach, colour-only signals |
| Code quality | Code Reviewer | Review of a diff before commit |
| | Software Architect | Layering of `core/` vs `app/` vs `scenes/`, the next ADR |
| | Minimal Change Engineer | Bug fixes from `bugfixes.md` that must not turn into refactors |
| | Codebase Archaeologist | Drift between ADRs, PLAN and code; dead code after several sessions |
| | Git Workflow Master | Commit hygiene while `WIP.md` and large asset diffs sit in the tree |
| | Technical Writer | ADRs, the learning log, README |
| Sandbox | WebAssembly Engineer | The wasmtime sidecar, CPython and QuickJS WASI modules (ADR-0002) |
| | Application Security Engineer | Limits and escapes in the player-code sandbox |
| Testing | Test Automation Engineer | gdUnit4 suites, fixtures, the headless runs |
| | Performance Benchmarker | Sandbox timings, frame time in fights, `bench_sandbox.gd` |
| | Reality Checker | The "is it really done" pass; refuses claims without evidence |
| | Evidence Collector | Screenshot-backed checks with `scripts/screenshot.sh` |
| Language | Internationalization Engineer, Language Translator | Japanese for the daughters (`scripts/locale.sh ja`), fonts, text fit |

## Using them

- Ask for one by name ("have the Economy Designer look at the layer-3 foe HP"), or let Claude pick from the
  `description` line. Run `/agents` to see the list.
- They advise and review; the rules of `AGENT.md` still decide. In particular: no outcomes in scenes, no randomness
  outside `Rng`, the player's solutions are never written for them.
- A reviewer's finding that a report could have more than one cause gets measured before it is fixed.
