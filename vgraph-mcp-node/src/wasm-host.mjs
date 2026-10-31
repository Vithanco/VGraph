// Loads VGraphWasm under Node/WASI.
//
// Differs from the generated platforms/node.js in one way that matters for MCP:
// the wasm writes DEBUG/Warning lines to WASI stdout (fd 1), and the generated
// setup pipes those to console.log. Under a stdio MCP server stdout carries
// JSON-RPC, so both fds go to stderr here.
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { WASI, File, OpenFile, ConsoleStdout, PreopenDirectory } from '@bjorn3/browser_wasi_shim';

export async function loadVGraph(pkgDir) {
  const { instantiate, MODULE_PATH } = await import(path.join(pkgDir, 'instantiate.js'));

  const wasi = new WASI([MODULE_PATH], [], [
    new OpenFile(new File([])),
    ConsoleStdout.lineBuffered((l) => console.error('[wasm]', l)),
    ConsoleStdout.lineBuffered((l) => console.error('[wasm]', l)),
    new PreopenDirectory('/', new Map()),
  ], { debug: false });

  const module = await WebAssembly.compile(await readFile(path.join(pkgDir, MODULE_PATH)));

  const { exports } = await instantiate({
    module,
    getImports: () => ({}),
    wasi: Object.assign(wasi, { setInstance(i) { wasi.inst = i; } }),
    addToCoreImports(importObject) {
      importObject['wasi_snapshot_preview1']['proc_exit'] = (code) => process.exit(code);
    },
  });
  return exports;
}
