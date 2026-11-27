// The drop-in embed: one module script turns the VGL blocks on any page into
// diagrams. build-wasm.sh bundles it with the engine glue and the WASI shim
// into website/Package/embed.js, so a host page needs no import map, and the
// glue finds VGraphWasm.wasm beside the bundle through `import.meta.url`, which
// is what lets a CDN copy run on someone else's origin.
//
// Each diagram renders into its own shadow root. The engine's SVG carries
// unscoped class and id selectors (`.vgraph-node`, `svg:has(#node-x:hover)`),
// which in the page itself would restyle the host and let two diagrams with
// the same node ids reach into each other.

const ELEMENT = 'vgl-diagram';
const BLOCKS = 'pre.vgl, code.language-vgl';

// Chromium ignores @font-face inside a shadow root, so the SVG's font import
// moves to the document: a page-wide choice, hence on the URL.
const loadFonts = new URL(import.meta.url).searchParams.get('fonts') !== 'none';
const IMPORT = /@import\s+url\(\s*['"]?([^'")]+)['"]?\s*\)\s*;?/g;

// The error SVG `renderGraph` returns in place of a diagram (VGraphWasm/Sources/Main.swift).
const RENDER_ERROR = /^<svg><text[^>]*>Error:\s*([\s\S]*)<\/text><\/svg>$/;

const STYLE = `
:host { display: block; max-width: 100%; }
svg { display: block; max-width: 100%; height: auto; }
.error { color: #b42318; background: rgba(180, 35, 24, 0.08); border: 1px solid currentColor;
  border-radius: 4px; padding: 0.5em 0.75em; font: 13px/1.4 system-ui, sans-serif; white-space: pre-wrap; }
`;

let engine;
const loadEngine = () =>
  (engine ??= import('../../website/Package/index.js')
    .then(({ init }) => init({}))
    .then((loaded) => loaded.exports));

const fontLinks = new Set();
function hoistFontImports(fragment) {
  for (const style of fragment.querySelectorAll('style')) {
    const text = style.textContent;
    for (const [, href] of text.matchAll(IMPORT)) {
      if (!loadFonts || fontLinks.has(href)) continue;
      fontLinks.add(href);
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = href;
      document.head.append(link);
    }
    style.textContent = text.replace(IMPORT, '');
  }
}

const darkScheme = matchMedia('(prefers-color-scheme: dark)');

class VGLDiagram extends HTMLElement {
  static observedAttributes = ['data-theme'];
  static #connected = new Set();

  static {
    darkScheme.addEventListener('change', () => {
      for (const diagram of VGLDiagram.#connected) diagram.#schedule();
    });
  }

  #root = this.attachShadow({ mode: 'open' });
  #scheduled = false;

  connectedCallback() {
    VGLDiagram.#connected.add(this);
    this.#schedule();
  }

  disconnectedCallback() {
    VGLDiagram.#connected.delete(this);
  }

  attributeChangedCallback() {
    this.#schedule();
  }

  get #dark() {
    const pinned = this.dataset.theme;
    return pinned === 'dark' || (pinned !== 'light' && darkScheme.matches);
  }

  // An upgrade calls attributeChangedCallback and then connectedCallback; one render serves both.
  #schedule() {
    if (this.#scheduled) return;
    this.#scheduled = true;
    queueMicrotask(() => {
      this.#scheduled = false;
      if (this.isConnected) this.#render();
    });
  }

  async #render() {
    let exports;
    try {
      exports = await loadEngine();
    } catch (error) {
      return this.#showError(`The VGraph engine did not load: ${error.message}`);
    }
    let svg;
    try {
      svg = this.#dark ? exports.renderGraphDark(this.textContent) : exports.renderGraph(this.textContent);
    } catch (error) {
      return this.#showError(`VGraph failed: ${error.message}`);
    }
    const failed = RENDER_ERROR.exec(svg);
    if (failed) return this.#showError(failed[1]);

    const template = document.createElement('template');
    template.innerHTML = svg;
    hoistFontImports(template.content);
    this.#show(template.content);
  }

  #showError(message) {
    const box = document.createElement('div');
    box.className = 'error';
    box.setAttribute('role', 'alert');
    box.textContent = message;
    this.#show(box);
  }

  #show(content) {
    const style = document.createElement('style');
    style.textContent = STYLE;
    this.#root.replaceChildren(style, content);
  }
}

// A <pre> cannot host a shadow root, so a block is swapped for the element,
// keeping its attributes (id, data-theme, …) for the page's own CSS and scripts.
function adopt(found) {
  const block = found.matches('code') && found.parentElement?.matches('pre') ? found.parentElement : found;
  if (!block.isConnected) return;
  const diagram = document.createElement(ELEMENT);
  for (const { name, value } of block.attributes) diagram.setAttribute(name, value);
  diagram.textContent = block.textContent;
  block.replaceWith(diagram);
}

function scan(root) {
  if (root.matches?.(BLOCKS)) adopt(root);
  for (const found of root.querySelectorAll?.(BLOCKS) ?? []) adopt(found);
}

// A second copy (another version, another CDN) leaves the page to the first.
if (!customElements.get(ELEMENT)) {
  customElements.define(ELEMENT, VGLDiagram);
  scan(document);
  new MutationObserver((records) => {
    for (const record of records) for (const node of record.addedNodes) scan(node);
  }).observe(document.documentElement, { childList: true, subtree: true });
}
