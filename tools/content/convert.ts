// Converts the old game's Shardrun content from YAML to JSONC (JSON with // comments), keeping every comment, into
// game/content/ (ADR-0004). A one-off: after it runs, the JSONC files are the source.
//   node tools/content/convert.ts
//
// What it writes:
//   game/content/balance.jsonc                          config/balance.yaml, whole
//   game/content/packs/core/pack.jsonc                  the pack's manifest
//   game/content/packs/core/shardrun/run.jsonc          shardrun/run.yaml
//   game/content/packs/core/shardrun/shards/<id>.jsonc  a shard without its code, plus <id>.py and <id>.js beside it
//   game/content/packs/core/shardrun/{relics,foes}/<id>.jsonc
//   game/content/packs/core/locales/ja/<name>.jsonc     the Shardrun overlays
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import {
  type Document,
  isMap,
  isPair,
  isScalar,
  isSeq,
  type Node,
  parseDocument,
} from "../../../ProgramMe/packages/content-tools/node_modules/yaml/dist/index.js";

const oldRoot = path.resolve(import.meta.dirname, "../../../ProgramMe");
const newRoot = path.resolve(import.meta.dirname, "../../game/content");
const INDENT = "  ";
const WIDTH = 120;

/** Comment text from the yaml library (lines without their leading '#') as // lines at `pad`. */
function commentLines(text: string | null | undefined, pad: string): string[] {
  if (!text) return [];
  return text.split("\n").map((line) => (line.trim() === "" ? `${pad}//` : `${pad}//${line}`));
}

function scalar(value: unknown): string {
  return JSON.stringify(value);
}

/** A node on one line, when that is how it was written in YAML (flow style) and it fits. */
function inline(node: Node | null): string | undefined {
  if (node === null) return "null";
  if (isScalar(node)) return scalar(node.value);
  if (isSeq(node)) {
    const parts = node.items.map((item) => inline(item as Node));
    return parts.some((part) => part === undefined) ? undefined : `[${parts.join(", ")}]`;
  }
  if (isMap(node)) {
    const parts = node.items.map((pair) => {
      const value = inline(pair.value as Node);
      return value === undefined ? undefined : `${scalar(String((pair.key as { value: unknown }).value))}: ${value}`;
    });
    return parts.some((part) => part === undefined) ? undefined : `{ ${parts.join(", ")} }`;
  }
  return undefined;
}

function hasComments(node: Node | null): boolean {
  if (node === null || isScalar(node)) return Boolean(node?.commentBefore || node?.comment);
  const items = isSeq(node) ? node.items : isMap(node) ? node.items : [];
  return Boolean(node.commentBefore || node.comment) || items.some((item) =>
    isPair(item) ? hasComments(item.key as Node) || hasComments(item.value as Node) : hasComments(item as Node),
  );
}

/** Emits `node` starting at the current column; returns lines, the first without its indentation. */
function emit(node: Node | null, depth: number, skip: (key: string) => boolean = () => false): string[] {
  const pad = INDENT.repeat(depth + 1);
  const close = INDENT.repeat(depth);
  const flat = inline(node);
  if (flat !== undefined && (isScalar(node) || node === null || ((node as { flow?: boolean }).flow && !hasComments(node)))) {
    if (flat.length + depth * 2 < WIDTH) return [flat];
  }
  if (isSeq(node)) {
    const lines = ["["];
    node.items.forEach((item, i) => {
      const itemNode = item as Node;
      lines.push(...commentLines(itemNode?.commentBefore, pad));
      const body = emit(itemNode, depth + 1);
      const comma = i < node.items.length - 1 ? "," : "";
      body[0] = pad + body[0];
      body[body.length - 1] += comma + (isScalar(itemNode) && itemNode.comment ? ` //${itemNode.comment}` : "");
      lines.push(...body);
    });
    lines.push(`${close}]`);
    return lines;
  }
  if (isMap(node)) {
    const pairs = node.items.filter((pair) => !skip(String((pair.key as { value: unknown }).value)));
    const lines = ["{"];
    pairs.forEach((pair, i) => {
      const key = pair.key as Node & { value: unknown };
      const value = pair.value as Node | null;
      lines.push(...commentLines(key.commentBefore, pad));
      if (value && !isScalar(value)) lines.push(...commentLines(value.commentBefore, pad));
      const body = emit(value, depth + 1);
      body[0] = `${pad}${scalar(String(key.value))}: ${body[0]}`;
      const comma = i < pairs.length - 1 ? "," : "";
      const trailing = value && isScalar(value) && value.comment ? ` //${value.comment}` : key.comment ? ` //${key.comment}` : "";
      body[body.length - 1] += comma + trailing;
      lines.push(...body);
    });
    lines.push(`${close}}`);
    return lines;
  }
  return [flat ?? "null"];
}

function jsonc(document: Document, skip?: (key: string) => boolean): string {
  const lines = [...commentLines(document.commentBefore, ""), ...emit(document.contents as Node, 0, skip)];
  if (document.comment) lines.push(...commentLines(document.comment, ""));
  return `${lines.join("\n")}\n`;
}

function read(file: string): Document {
  const document = parseDocument(readFileSync(file, "utf8"));
  if (document.errors.length > 0) throw new Error(`${file}: ${document.errors[0]!.message}`);
  return document;
}

function write(file: string, text: string): void {
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, text);
}

let written = 0;
const convert = (from: string, to: string, skip?: (key: string) => boolean) => {
  write(to, jsonc(read(from), skip));
  written += 1;
};

convert(path.join(oldRoot, "config/balance.yaml"), path.join(newRoot, "balance.jsonc"));
const pack = path.join(oldRoot, "content/packs/core");
convert(path.join(pack, "pack.yaml"), path.join(newRoot, "packs/core/pack.jsonc"));
convert(path.join(pack, "shardrun/run.yaml"), path.join(newRoot, "packs/core/shardrun/run.jsonc"));
for (const kind of ["relics", "foes"]) {
  for (const name of readdirSync(path.join(pack, "shardrun", kind)).filter((f) => f.endsWith(".yaml"))) {
    convert(path.join(pack, "shardrun", kind, name), path.join(newRoot, "packs/core/shardrun", kind, name.replace(/\.yaml$/, ".jsonc")));
  }
}
// A shard's code leaves its data file: real source files are what a player opens, edits, and reads line numbers from.
for (const name of readdirSync(path.join(pack, "shardrun/shards")).filter((f) => f.endsWith(".yaml"))) {
  const id = name.replace(/\.yaml$/, "");
  const document = read(path.join(pack, "shardrun/shards", name));
  const code = document.get("code") as { toJSON(): Record<string, string> } | undefined;
  const dir = path.join(newRoot, "packs/core/shardrun/shards");
  write(path.join(dir, `${id}.jsonc`), jsonc(document, (key) => key === "code"));
  const sources = code?.toJSON() ?? {};
  if (sources.python !== undefined) write(path.join(dir, `${id}.py`), sources.python);
  if (sources.javascript !== undefined) write(path.join(dir, `${id}.js`), sources.javascript);
  written += 1;
}
for (const name of readdirSync(path.join(pack, "locales/ja")).filter((f) => f.startsWith("shardrun") && f.endsWith(".yaml"))) {
  convert(path.join(pack, "locales/ja", name), path.join(newRoot, "packs/core/locales/ja", name.replace(/\.yaml$/, ".jsonc")));
}
console.log(`converted ${written} files into ${newRoot}`);
