// Runs the old engine's Shardrun unit tests with the recorder in place of the engine they import.
// Run from the old repo so its dependencies resolve:
//   cd ../ProgramMe/packages/core && npx vitest run --config ../../../Rootward/tools/fixtures/record/vitest.config.mts
import path from "node:path";


const here = import.meta.dirname;
const core = path.resolve(here, "../../../../ProgramMe/packages/core");

export default {
  root: core,
  resolve: {
    alias: [
      { find: /^\.\.\/src\/index\.ts$/, replacement: path.join(here, "recorder.ts") },
      { find: /^\.\.\/src\/shardrun\/relic-conditions\.ts$/, replacement: path.join(here, "recorder.ts") },
    ],
  },
  test: { include: ["test/shardrun.test.ts"], globals: true, setupFiles: [path.join(here, "setup.ts")] },
};
