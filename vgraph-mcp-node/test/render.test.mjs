import { describe, test, expect } from 'vitest';
import { makeRenderDiagram } from '../src/render.mjs';

// The engine is faked: what is under test is how the host assembles what the
// engine returns, not the engine (the wasm smoke tests cover that).
const fakeApi = (views) => ({
  listViews: () => JSON.stringify(views),
  renderGraphWithQuality: (_vgl, view) =>
    JSON.stringify({
      svg: `svg:${view}`,
      quality: [{ severity: 'warning', message: 'Too long' }],
    }),
});
const fakePng = async (svg) => Buffer.from(svg);

const kinds = (result) =>
  result.content.map((c) => (c.type === 'image' ? `image:${Buffer.from(c.data, 'base64')}` : c.text));

describe('renderDiagram', () => {
  test('two views: one report, then default and each view as a captioned picture', async () => {
    const render = makeRenderDiagram(
      fakeApi([{ name: 'a', label: 'Alpha' }, { name: 'b', label: 'Beta' }]),
      fakePng,
    );
    const result = await render({ vgl: 'x' });
    expect(result.isError).toBe(false);
    expect(kinds(result)).toEqual([
      'Warnings:\n- Too long',
      'default', 'image:svg:',
      'a: Alpha', 'image:svg:a',
      'b: Beta', 'image:svg:b',
    ]);
  });

  test('no views: the report and one uncaptioned picture, as before', async () => {
    const render = makeRenderDiagram(fakeApi([]), fakePng);
    expect(kinds(await render({ vgl: 'x' }))).toEqual(['Warnings:\n- Too long', 'image:svg:']);
  });

  test('a view without a label is captioned by its name', async () => {
    const render = makeRenderDiagram(fakeApi([{ name: 'a' }]), fakePng);
    expect(kinds(await render({ vgl: 'x' })).slice(1, 2)).toEqual(['default']);
    expect(kinds(await render({ vgl: 'x' }))[3]).toBe('a');
  });

  test('the input is still just vgl', async () => {
    const render = makeRenderDiagram(fakeApi([]), fakePng);
    expect((await render({})).isError).toBe(true);
  });
});
