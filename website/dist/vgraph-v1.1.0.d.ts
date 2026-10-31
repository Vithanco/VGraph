/**
 * VGraph JavaScript Library Type Definitions
 * Version: 1.0.0
 */

/**
 * Initialization options for VGraph library
 */
export interface VGraphInitOptions {
  /**
   * Path to the WASM package directory
   * @default './Package'
   */
  wasmPath?: string;

  /**
   * Whether to load Graphviz WASM module
   * @default true
   */
  loadGraphviz?: boolean;
}

/**
 * Version information
 */
export interface VGraphVersion {
  /** Semantic version string */
  version: string;

  /** Whether WASM is enabled */
  wasm: boolean;

  /** Available features */
  features: string[];
}

/**
 * VGraph library class for rendering and converting Vithanco Graph Language (VGL)
 */
export default class VGraphLib {
  /**
   * Whether the library has been initialized
   */
  readonly initialized: boolean;

  /**
   * Initialize the VGraph library
   * @param options - Initialization options
   * @returns Initialized library instance
   * @throws {Error} If initialization fails
   */
  init(options?: VGraphInitOptions): Promise<VGraphLib>;

  /**
   * Render VGL to SVG with styles
   * @param vglText - Vithanco Graph Language text
   * @returns SVG string
   * @throws {Error} If rendering fails or library not initialized
   */
  render(vglText: string): string;

  /**
   * Convert VGL to DOT format
   * @param vglText - Vithanco Graph Language text
   * @returns DOT format string
   * @throws {Error} If conversion fails or library not initialized
   */
  toDot(vglText: string): string;

  /**
   * Export VGL (normalize/roundtrip)
   * @param vglText - Vithanco Graph Language text
   * @returns Normalized VGL string
   * @throws {Error} If export fails or library not initialized
   */
  exportVGL(vglText: string): string;

  /**
   * Get debug information about a graph
   * @param vglText - Vithanco Graph Language text
   * @returns Debug information string
   * @throws {Error} If library not initialized
   */
  debug(vglText: string): string;

  /**
   * Test layout functionality
   * @param vglText - Vithanco Graph Language text
   * @returns Layout test results
   * @throws {Error} If library not initialized
   */
  testLayout(vglText: string): string;

  /**
   * Get version information
   * @returns Version info object
   */
  static getVersion(): VGraphVersion;
}

/**
 * Global VGraphLib instance (when loaded via script tag)
 */
declare global {
  interface Window {
    VGraphLib: typeof VGraphLib;
  }
}
