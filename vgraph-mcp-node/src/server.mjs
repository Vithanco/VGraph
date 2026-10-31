#!/usr/bin/env node
// The VGraph MCP server, hosted locally around the WebAssembly engine.
//
// Same tools as the deployed `vgraph-mcp-http`, same engine — this one runs it
// on the caller's machine instead of over the network. It is a host, not a
// port: no graph logic lives here. That is the same relationship the Obsidian
// and VS Code plugins have with the wasm, with a protocol on stdin where they
// have a pane.
//
// Tool definitions are not duplicated either. tools.json is dumped from the
// native `vgraph-mcp` binary by scripts/dump-mcp-tools.sh, so the ~20KB of VGL
// documentation the model reads has exactly one source, in Swift.
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { loadVGraph } from './wasm-host.mjs';
import { svgToPng, initPng } from './png.mjs';
import { makeRenderDiagram } from './render.mjs';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
// VGRAPH_WASM_DIR points at website/Package for a working copy that has not
// been vendored yet; the published package always has vendor/Package.
const PKG_DIR = process.env.VGRAPH_WASM_DIR ?? path.join(ROOT, 'vendor', 'Package');

const tools = JSON.parse(await readFile(path.join(ROOT, 'tools.json'), 'utf8'));

// Eager: a cold first tool call is the latency a user actually feels, and both
// of these are tens of milliseconds.
const started = performance.now();
const [api] = await Promise.all([loadVGraph(PKG_DIR), initPng()]);
console.error(`[vgraph-mcp] ready in ${(performance.now() - started).toFixed(0)}ms`);

const server = new Server(
  { name: 'vgraph', version: '1.0.0-local' },
  { capabilities: { tools: { listChanged: false } } },
);

const err = (text) => ({ isError: true, content: [{ type: 'text', text }] });
const renderDiagram = makeRenderDiagram(api, svgToPng);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: tools.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })),
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const tool = tools.find((t) => t.name === req.params.name);
  if (!tool) return err(`Unknown tool: ${req.params.name}`);

  const args = req.params.arguments ?? {};
  const began = performance.now();
  const result = tool.name === 'describe_notation'
    ? describeNotation(args)
    : await renderDiagram(args);
  console.error(`[vgraph-mcp] ${tool.name} in ${(performance.now() - began).toFixed(0)}ms`);
  return result;
});

// Text, not an image: the self-description of a notation.
function describeNotation({ notation }) {
  if (typeof notation !== 'string') return err("Error: 'notation' parameter is required.");
  const markdown = api.describeNotation(notation);
  // The engine reports its own failures in-band, the same way renderGraph does.
  if (markdown.startsWith('Error')) return err(markdown);
  return { isError: false, content: [{ type: 'text', text: markdown }] };
}

await server.connect(new StdioServerTransport());
