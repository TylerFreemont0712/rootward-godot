// Writes game/test/fixtures/challenges.json.gz: challenges graded by the old runners (QuickJS and Pyodide) with their
// reference solutions, starters, and a wrong answer, over visible and hidden io cases. The Godot grader must agree.
// Run: node tools/fixtures/challenges.ts   (needs ../ProgramMe with its node_modules installed)
import { writeFileSync } from "node:fs";
import { gzipSync } from "node:zlib";
import path from "node:path";
import { resolveStdin } from "../../../ProgramMe/packages/content-schema/src/index.ts";
import { buildIoJob, selectIoCases } from "../../../ProgramMe/packages/content-tools/src/jobs.ts";
import { loadContent } from "../../../ProgramMe/packages/content-tools/src/loader/load-content.ts";
import { WasmJsRunner, WasmPythonRunner } from "../../../ProgramMe/packages/runners/src/index.ts";

const oldRoot = path.resolve(import.meta.dirname, "../../../ProgramMe");
const { index } = await loadContent({ contentDir: path.join(oldRoot, "content"), rootDir: oldRoot });
const ids = ["foundry.py.dict-word-count"];
const wrong = {
  python: "import sys\nfor word in sys.stdin.read().split():\n    print(word, 1)\n",
  javascript: "const words = require('fs').readFileSync(0, 'utf8').split(/\\s+/).filter(Boolean);\nfor (const w of words) console.log(w, 1);\n",
};
const limits = { wallMs: 60000, cpuMs: 20000, memMb: 256, pids: 128, outputKb: 256 };
const runners = { javascript: new WasmJsRunner(), python: new WasmPythonRunner({ warm: false }) };

const challenges = [];
for (const id of ids) {
  const challenge = index.challenges.get(id);
  if (!challenge) throw new Error(`no challenge ${id}`);
  const cases = selectIoCases(challenge, { visible: true, hidden: true, reserve: "all" });
  const normalize = challenge.visibleTests?.normalize ?? { trailing_whitespace: true, newlines: true };
  const attempts = [];
  for (const language of ["python", "javascript"] as const) {
    const entry = challenge.manifest.tests.entry[language]!;
    const submissions = {
      solution: challenge.solution[language]!,
      starter: challenge.starter[language]!,
      wrong: { [entry]: wrong[language] },
    };
    for (const [name, files] of Object.entries(submissions)) {
      const job = buildIoJob(challenge, language, files, cases, limits)!;
      const result = await runners[language].run(job, AbortSignal.timeout(120000));
      attempts.push({
        language,
        submission: name,
        entry,
        files,
        tests: (result.tests ?? []).map((t) => ({ id: t.id, passed: t.passed, status: t.status, expected: t.expected, actual: t.actual })),
      });
      console.log(`${id} ${language} ${name}: ${(result.tests ?? []).filter((t) => t.passed).length}/${cases.length}`);
    }
  }
  challenges.push({
    id,
    normalize,
    cases: cases.map((c) => ({ id: c.id, name: c.name, stdin: resolveStdin(c), expected_stdout: c.expected_stdout })),
    attempts,
  });
}
await runners.python.dispose?.();
const out = new URL("../../game/test/fixtures/challenges.json.gz", import.meta.url);
writeFileSync(out, gzipSync(JSON.stringify({ challenges })));
console.log(`wrote ${out.pathname}`);
