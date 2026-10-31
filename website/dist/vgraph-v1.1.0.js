/**
 * VGraph JavaScript Library
 * Version: 1.1.0
 *
 * A JavaScript wrapper for VGraph WASM module that provides graph rendering
 * and conversion capabilities for Vithanco Graph Language (VGL).
 *
 * Uses BridgeJS-generated bindings for automatic Swift <-> JavaScript type marshalling.
 *
 * @license MIT
 * @author Vithanco
 */

class VGraphLib {
  constructor() {
    this.initialized = false;
    this.exports = null;
  }

  /**
   * Initialize the VGraph library
   * @param {Object} options - Initialization options
   * @param {string} options.wasmPath - Path to the WASM package directory (default: './Package')
   * @param {boolean} options.loadGraphviz - Whether to load Graphviz (default: true)
   * @returns {Promise<VGraphLib>} Initialized library instance
   */
  async init(options = {}) {
    if (this.initialized) {
      return this;
    }

    const { wasmPath = './Package' } = options;

    try {
      // Graphviz is compiled into the VGraph WASM module now (in-process
      // layout) — there is no separate JS Graphviz instance to load.
      await this._loadWasm(wasmPath);

      this.initialized = true;
      return this;
    } catch (error) {
      throw new Error(`Failed to initialize VGraph: ${error.message}`);
    }
  }

  /**
   * Load WASM module with BridgeJS exports
   * @private
   */
  async _loadWasm(wasmPath) {
    try {
      const { init } = await import(`${wasmPath}/index.js`);
      const result = await init({});

      // BridgeJS generates exports with proper function bindings
      this.exports = result.exports;

      // Log what we got for debugging
      console.log('[VGraphLib] WASM loaded, exports:', Object.keys(this.exports || {}));

      // Verify exports are available
      if (!this.exports || typeof this.exports.convertToDot !== 'function') {
        console.warn('[VGraphLib] BridgeJS exports not found or incomplete');
        console.warn('[VGraphLib] Available exports:', this.exports);
        throw new Error('BridgeJS exports not available - ensure Package.swift includes BridgeJS plugin and rebuild');
      }
    } catch (error) {
      throw new Error(`Failed to load WASM module: ${error.message}`);
    }
  }

  /**
   * Ensure library is initialized
   * @private
   */
  _ensureInitialized() {
    if (!this.initialized) {
      throw new Error('VGraph library not initialized. Call init() first.');
    }
  }

  /**
   * Render VGL to SVG with styles
   * @param {string} vglText - Vithanco Graph Language text
   * @param {Object} [options] - Render options
   * @param {boolean} [options.darkMode=false] - Render with dark palette (Diagram Style Guide §11)
   * @returns {string} SVG string
   * @throws {Error} If rendering fails
   */
  async render(vglText, options) {
    this._ensureInitialized();

    const darkMode = options && options.darkMode === true;

    // In-process layout: Graphviz is compiled into the VGraph WASM module, so
    // this is a single call — no DOT round-trip through a separate JS Graphviz.
    const result = darkMode
      ? this.exports.renderGraphDark(vglText)
      : this.exports.renderGraph(vglText);

    // Check for error in result
    if (result.includes('Error:') && result.includes('<text')) {
      const match = result.match(/Error:([^<]+)/);
      throw new Error(match ? match[1].trim() : 'Rendering failed');
    }

    return result;
  }

  /**
   * Render VGL to SVG. Alias of render() (kept for API compatibility); the
   * separate unstyled WASM entrypoint was removed with the decoupled rewrite.
   * @param {string} vglText - Vithanco Graph Language text
   * @returns {Promise<string>} SVG string
   * @throws {Error} If rendering fails
   */
  async renderBasic(vglText) {
    return this.render(vglText);
  }

  /**
   * Convert VGL to DOT format
   * @param {string} vglText - Vithanco Graph Language text
   * @returns {string} DOT format string
   * @throws {Error} If conversion fails
   */
  toDot(vglText) {
    this._ensureInitialized();

    const result = this.exports.convertToDot(vglText);

    if (result.startsWith('Error:')) {
      throw new Error(result.substring(7));
    }

    return result;
  }

  /**
   * Export VGL (normalize/roundtrip)
   * @param {string} vglText - Vithanco Graph Language text
   * @returns {string} Normalized VGL string
   * @throws {Error} If export fails
   */
  exportVGL(vglText) {
    this._ensureInitialized();

    const result = this.exports.exportToVGL(vglText);

    if (result.startsWith('Error:')) {
      throw new Error(result.substring(7));
    }

    return result;
  }

  /**
   * Get debug information about a graph
   * @param {string} vglText - Vithanco Graph Language text
   * @returns {string} Debug information
   */
  debug(vglText) {
    this._ensureInitialized();
    return this.exports.debugGraph(vglText);
  }

  /**
   * Layout a graph and get position information. Graphviz runs in-process
   * inside the VGraph WASM module.
   * @param {string} vglText - Vithanco Graph Language text
   * @returns {Promise<string>} Layout results with positions
   */
  async layout(vglText) {
    this._ensureInitialized();

    const result = this.exports.layoutGraph(vglText);

    if (result.startsWith('Error:')) {
      throw new Error(result.substring(7));
    }

    return result;
  }

  /**
   * Run diagnostics to verify all functions work
   * @returns {Object} Results of all tests
   */
  async runDiagnostics() {
    this._ensureInitialized();

    const results = {};
    const testGraph = `vgraph test: IBIS "Test" {
      node q1: Question "Test?";
      node a1: Answer "Yes";
      edge q1 -> a1;
    }`;

    // Test convertToDot
    try {
      const dot = this.toDot(testGraph);
      results.convertToDot = dot.includes('digraph') ? 'PASS' : 'FAIL: Invalid DOT output';
      console.log('✓ convertToDot:', results.convertToDot);
    } catch (e) {
      results.convertToDot = `FAIL: ${e.message}`;
      console.error('✗ convertToDot:', e);
    }

    // Test renderGraph
    try {
      const svg = await this.renderBasic(testGraph);
      results.renderGraph = svg.includes('<svg') ? 'PASS' : 'FAIL: Invalid SVG output';
      console.log('✓ renderGraph:', results.renderGraph);
    } catch (e) {
      results.renderGraph = `FAIL: ${e.message}`;
      console.error('✗ renderGraph:', e);
    }

    // Test renderGraphWithStyles
    try {
      const svg = await this.render(testGraph);
      results.renderGraphWithStyles = svg.includes('<svg') ? 'PASS' : 'FAIL: Invalid SVG output';
      console.log('✓ renderGraphWithStyles:', results.renderGraphWithStyles);
    } catch (e) {
      results.renderGraphWithStyles = `FAIL: ${e.message}`;
      console.error('✗ renderGraphWithStyles:', e);
    }

    // Test debugGraph
    try {
      const debug = this.debug(testGraph);
      results.debugGraph = debug.length > 0 ? 'PASS' : 'FAIL: Empty output';
      console.log('✓ debugGraph:', results.debugGraph);
    } catch (e) {
      results.debugGraph = `FAIL: ${e.message}`;
      console.error('✗ debugGraph:', e);
    }

    // Test layoutGraph
    try {
      const layout = await this.layout(testGraph);
      results.layoutGraph = layout.includes('NODE POSITIONS') ? 'PASS' : 'FAIL: Invalid layout output';
      console.log('✓ layoutGraph:', results.layoutGraph);
    } catch (e) {
      results.layoutGraph = `FAIL: ${e.message}`;
      console.error('✗ layoutGraph:', e);
    }

    // Test exportToVGL
    try {
      const vgl = this.exportVGL(testGraph);
      results.exportToVGL = vgl.includes('vgraph') ? 'PASS' : 'FAIL: Invalid VGL output';
      console.log('✓ exportToVGL:', results.exportToVGL);
    } catch (e) {
      results.exportToVGL = `FAIL: ${e.message}`;
      console.error('✗ exportToVGL:', e);
    }

    return results;
  }

  /**
   * Get version information
   * @returns {Object} Version info
   */
  static getVersion() {
    return {
      version: '1.1.0',
      wasm: true,
      bridgejs: true,
      features: ['render', 'renderBasic', 'toDot', 'exportVGL', 'debug', 'layout']
    };
  }
}

// Export for different module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = VGraphLib;
}

if (typeof window !== 'undefined') {
  window.VGraphLib = VGraphLib;
}

export default VGraphLib;
