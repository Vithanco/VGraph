// Text and pictures for a document: the report once, then the default view and
// each declared view in document order. A document without views is the report
// and one uncaptioned picture, as it always was. The host takes the views from
// the engine and calls it once per view; no graph logic lives here.
export function makeRenderDiagram(api, svgToPng) {
  const err = (text) => ({ isError: true, content: [{ type: 'text', text }] });

  return async function renderDiagram({ vgl }) {
    if (typeof vgl !== 'string') return err("Error: 'vgl' parameter is required.");

    let views;
    let renderings;
    try {
      views = JSON.parse(api.listViews(vgl));
      if (views.error) return err(`Error rendering: ${views.error}`);
      const shown = views.length
        ? [{ caption: 'default', view: '' }, ...views.map((v) => ({
            caption: v.label ? `${v.name}: ${v.label}` : v.name,
            view: v.name,
          }))]
        : [{ caption: null, view: '' }];
      renderings = shown.map(({ caption, view }) => ({
        caption,
        parsed: JSON.parse(api.renderGraphWithQuality(vgl, view)),
      }));
    } catch (e) {
      return err(`Error rendering: ${e}`);
    }
    const failed = renderings.find((r) => r.parsed.error);
    if (failed) return err(`Error rendering: ${failed.parsed.error}`);

    const content = [];
    // Findings are the model's, so every view carries the same report.
    const quality = formatQuality(renderings[0].parsed.quality);
    if (quality) content.push({ type: 'text', text: quality });

    try {
      for (const { caption, parsed } of renderings) {
        const png = await svgToPng(parsed.svg);
        if (caption) content.push({ type: 'text', text: caption });
        content.push({ type: 'image', data: png.toString('base64'), mimeType: 'image/png' });
      }
    } catch (e) {
      return err(`Error rasterising to PNG: ${e}`);
    }
    return { isError: false, content };
  };
}

// Mirrors QualityReport.formatted() in Swift — same sections, same order, so a
// user switching between this and the hosted server reads the same report.
function formatQuality(messages = []) {
  const lines = [];
  const section = (title, severity) => {
    const items = messages.filter((m) => m.severity === severity);
    if (!items.length) return;
    if (lines.length) lines.push('');
    lines.push(title);
    for (const m of items) lines.push(`- ${m.message}`);
  };
  section('Quality metrics:', 'info');
  section('Warnings:', 'warning');
  section('Errors:', 'error');
  return lines.length ? lines.join('\n') : null;
}

