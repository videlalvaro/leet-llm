import { readdir, readFile } from "node:fs/promises";
import { JSDOM } from "jsdom";

const dom = new JSDOM("<!doctype html><html><body></body></html>");
globalThis.window = dom.window;
globalThis.document = dom.window.document;
Object.defineProperty(globalThis, "navigator", {
  configurable: true,
  value: dom.window.navigator
});

const { default: mermaid } = await import("mermaid");

const problemsDirectory = new URL("../../Problems/", import.meta.url);
const markdownFiles = await collectMarkdownFiles(problemsDirectory);
let diagramCount = 0;

for (const fileURL of markdownFiles) {
  const markdown = await readFile(fileURL, "utf8");
  const diagrams = markdown.matchAll(/```mermaid[^\n]*\n([\s\S]*?)\n```/g);
  for (const match of diagrams) {
    diagramCount += 1;
    try {
      await mermaid.parse(match[1]);
    } catch (error) {
      throw new Error(
        `${fileURL.pathname}: invalid Mermaid diagram\n${error instanceof Error ? error.message : String(error)}`
      );
    }
  }
}

if (diagramCount === 0) {
  throw new Error("No Mermaid diagrams were found in the curriculum.");
}
console.log(`Validated ${diagramCount} Mermaid diagrams in ${markdownFiles.length} lessons.`);

async function collectMarkdownFiles(directoryURL) {
  const files = [];
  for (const entry of await readdir(directoryURL, { withFileTypes: true })) {
    const entryURL = new URL(entry.name + (entry.isDirectory() ? "/" : ""), directoryURL);
    if (entry.isDirectory()) {
      files.push(...await collectMarkdownFiles(entryURL));
    } else if (entry.name.endsWith(".md")) {
      files.push(entryURL);
    }
  }
  return files;
}