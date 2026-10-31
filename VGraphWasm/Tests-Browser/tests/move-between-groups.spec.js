// Dragging elements from one group into another (ADR-0019).
//
// The gesture is shared with `connect` and told apart by where it is dropped, so
// what needs a real browser is precisely that: which of two commands a release
// runs, whether a group can be grabbed by its label, and that the two feedbacks
// never appear together.

import { test, expect } from '@playwright/test';
import { s, sel, openEditor, vglText, rectOf } from '../helpers/editor.js';

const nested = `vgraph demo: ConceptMap "Demo" {
  node outside: Concept "Outside";
  group box "Box" {
    node one: Concept "One";
    node two: Concept "Two";
  }
}`;

const twoGroups = `vgraph demo: ConceptMap "Demo" {
  group alpha "Alpha" {
    node one: Concept "One";
  }
  group beta "Beta" {
    node two: Concept "Two";
  }
}`;

async function centreOf(page, selector) {
  const r = await rectOf(page, selector);
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
}

// A group's label, which is both its drag handle and the drop target for moving
// into it — the one part of a group its children never cover.
async function labelOf(page, text) {
  return page.evaluate((wanted) => {
    const el = [...document.querySelectorAll('.vgraph-group-label')].find(
      (e) => e.textContent.trim().toUpperCase() === wanted.toUpperCase(),
    );
    if (!el) return null;
    const b = el.getBoundingClientRect();
    return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
  }, text);
}

// Several steps, not one jump: the first must clear ADR-0012's 4px threshold and
// the rest are what a real drag looks like.
async function dragFromTo(page, from, to) {
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  await page.mouse.move(from.x + 12, from.y + 12);
  await page.mouse.move(to.x, to.y, { steps: 4 });
}

const washed = (page) =>
  page.evaluate(() => [...document.querySelectorAll('.vg-drop-target')].map((e) => e.id));

const emptyPoint = async (page) => {
  const box = await page.locator(s.preview).boundingBox();
  return { x: box.x + 8, y: box.y + box.height - 10 };
};

test('a node dropped on a boundary label joins it', async ({ page }) => {
  await openEditor(page, nested);

  await dragFromTo(page, await centreOf(page, sel.node('outside')), await labelOf(page, 'Box'));
  await page.mouse.up();

  expect(await vglText(page)).toMatch(/group box[\s\S]*node outside/);
});

// "Out" is not a direction — the canvas is the root group, so leaving a boundary
// is joining the group outside it (ADR-0016, ADR-0019).
test('a node dropped on blank canvas leaves its boundary', async ({ page }) => {
  await openEditor(page, nested);

  await dragFromTo(page, await centreOf(page, sel.node('one')), await emptyPoint(page));
  await page.mouse.up();

  const vgl = await vglText(page);
  expect(vgl).toMatch(/node one[\s\S]*group box/);
});

// The root draws no element of its own, so the canvas carries its wash — which
// is what the canvas is (ADR-0016). It appears only when the move would do
// something, so it doubles as "this release will take it out of the boundary".
test('the canvas washes when a drop there would move something out', async ({ page }) => {
  await openEditor(page, nested);
  const onCanvas = () => page.locator(`${s.preview}.vg-drop-root`).count();

  await dragFromTo(page, await centreOf(page, sel.node('one')), await emptyPoint(page));
  expect(await onCanvas(), 'one is inside box, so it would move').toBe(1);
  await page.mouse.up();
  expect(await onCanvas(), 'cleared on drop').toBe(0);

  await dragFromTo(page, await centreOf(page, sel.node('outside')), await emptyPoint(page));
  expect(await onCanvas(), 'outside is already at the top level').toBe(0);
  await page.mouse.up();
});

// A folded group is a legal destination (the drop unfolds it, ADR-0019), so it
// washes like any other while the drag is over it.
test('a folded group washes as a drop target', async ({ page }) => {
  await openEditor(page, `vgraph demo: ConceptMap "Demo" {
  node outside: Concept "Outside";
  folded group box "Box" {
    node one: Concept "One";
  }
}`);

  await dragFromTo(page, await centreOf(page, sel.node('outside')), await centreOf(page, sel.group('box')));
  expect(await washed(page)).toContain('group-box');
  await page.mouse.up();

  expect(await vglText(page)).toMatch(/group box[\s\S]*node outside/);
});

test('a group is dragged by its label', async ({ page }) => {
  await openEditor(page, twoGroups);

  await dragFromTo(page, await labelOf(page, 'Alpha'), await labelOf(page, 'Beta'));
  await page.mouse.up();

  expect(await vglText(page)).toMatch(/group beta[\s\S]*group alpha/);
});

// A group's interior stays the rubber band's, or band-selecting inside a
// boundary would become impossible.
test('dragging a boundary by its interior still rubber-bands', async ({ page }) => {
  await openEditor(page, nested);
  const box = await rectOf(page, sel.group('box'));

  await dragFromTo(
    page,
    { x: box.left + 4, y: box.bottom - 4 },
    { x: box.right + 30, y: box.bottom + 30 },
  );
  await page.mouse.up();

  expect(await vglText(page), 'nothing moved').toContain('group box');
  expect(await page.evaluate(() => [...document.querySelectorAll('.vg-selected')].length)).toBe(0);
});

test('the receiving group is washed while the pointer is over it', async ({ page }) => {
  await openEditor(page, nested);

  await dragFromTo(page, await centreOf(page, sel.node('outside')), await labelOf(page, 'Box'));
  expect(await washed(page)).toEqual(['group-box']);

  await page.mouse.up();
  expect(await washed(page), 'cleared on drop').toEqual([]);
});

// The two feedbacks are alternatives: a green "you may connect" line drawn over
// a boundary the drop would move into would be a lie.
test('the ghost line gives way to the wash over a group', async ({ page }) => {
  await openEditor(page, nested);

  await dragFromTo(page, await centreOf(page, sel.node('outside')), await centreOf(page, sel.node('one')));
  expect(await page.locator(s.dragLine).count(), 'over a node it is a line').toBe(1);
  expect(await washed(page)).toEqual([]);

  await page.mouse.move((await labelOf(page, 'Box')).x, (await labelOf(page, 'Box')).y, { steps: 3 });
  expect(await page.locator(s.dragLine).count(), 'over a group it is not').toBe(0);
  expect(await washed(page)).toEqual(['group-box']);

  await page.mouse.up();
});

// Structural, so it stays silent rather than turning red — there is no notation
// rule here for a user to learn.
test('a group cannot be dropped into its own descendant', async ({ page }) => {
  await openEditor(
    page,
    `vgraph demo: ConceptMap "Demo" {
  group outer "Outer" {
    group inner "Inner" {
      node f: Concept "F";
    }
  }
}`,
  );
  const before = await vglText(page);

  await dragFromTo(page, await labelOf(page, 'Outer'), await labelOf(page, 'Inner'));
  expect(await washed(page), 'no wash means no').toEqual([]);
  await page.mouse.up();

  expect(await vglText(page)).toBe(before);
});

// Cancelling is dropping it back where it came from: that is "move into the
// group it already occupies", which is refused and therefore does nothing.
test('dropping back on its own group does nothing', async ({ page }) => {
  await openEditor(page, nested);
  const before = await vglText(page);

  await dragFromTo(page, await centreOf(page, sel.node('one')), await labelOf(page, 'Box'));
  expect(await washed(page), 'its own group is not offered').toEqual([]);
  await page.mouse.up();

  expect(await vglText(page)).toBe(before);
});

test('connect is untouched — a node dropped on a node still makes an edge', async ({ page }) => {
  await openEditor(
    page,
    `vgraph demo: ConceptMap "Demo" {
  node idea: Concept "Idea";
  node link: Relation "leads to";
}`,
  );

  await dragFromTo(page, await centreOf(page, sel.node('idea')), await centreOf(page, sel.node('link')));
  await page.mouse.up();

  expect(await vglText(page)).toContain('edge idea -> link');
});

test('a move is one undo step', async ({ page }) => {
  await openEditor(page, nested);
  const before = await vglText(page);

  await dragFromTo(page, await centreOf(page, sel.node('outside')), await labelOf(page, 'Box'));
  await page.mouse.up();
  await expect(page.locator(s.textarea)).not.toHaveValue(before);

  await page.locator(s.textarea).press('ControlOrMeta+z');
  await expect(page.locator(s.textarea)).toHaveValue(before);
});

// Containment is a notation rule, so unlike the structural refusals above ⌥
// reaches past it (ADR-0032).
test.describe('containment', () => {
  const hierarchical = `vnotation Arch {
	node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
	node type: Container [nodeStyle: roundedBox, detailedBy: (Component)]
	node type: Component [nodeStyle: roundedBox]
}

vgraph g: Arch "G" {
	group sys: System "Sys" {
		isfolded: false;
		group api: Container "API" {
			isfolded: false;
			node auth: Component "Auth";
			node token: Component "Token";
		};
	};
}`;

  const apiBlock = (vgl) => vgl.match(/group api[^{]*\{[^}]*\}/)?.[0] ?? '';

  test('a component dropped on a system is refused, silently', async ({ page }) => {
    await openEditor(page, hierarchical);
    const before = await vglText(page);

    await dragFromTo(page, await centreOf(page, sel.node('auth')), await labelOf(page, 'Sys'));
    expect(await washed(page), 'no wash means no').toEqual([]);
    await page.mouse.up();

    expect(await vglText(page)).toBe(before);
  });

  test('with ⌥ the component moves into the system', async ({ page }) => {
    await openEditor(page, hierarchical);

    await page.keyboard.down('Alt');
    await dragFromTo(page, await centreOf(page, sel.node('auth')), await labelOf(page, 'Sys'));
    expect(await washed(page)).toEqual(['group-sys']);
    await page.mouse.up();
    await page.keyboard.up('Alt');

    const vgl = await vglText(page);
    expect(vgl).toContain('node auth');
    expect(apiBlock(vgl)).not.toContain('auth');
  });
});
