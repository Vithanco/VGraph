import { test, expect } from '@playwright/test';
import { s, sel, openEditor, vglText } from '../helpers/editor.js';

// System is detailed by Container and Store; Person is not detailed at all.
const architecture = `vnotation Arch {
  node type: Person [nodeStyle: simpleRoundedText, backgroundColor: "#438dd5"]
  node type: System [nodeStyle: simpleRoundedText, backgroundColor: "#438dd5", detailedBy: (Container, Store)]
  node type: Container [nodeStyle: simpleRoundedText, backgroundColor: "#438dd5"]
  node type: Store [nodeStyle: simpleRoundedText, backgroundColor: "#438dd5"]
  edge type: uses from: Person to: System
  edge type: systemToSystem from: System to: System
}

vgraph g: Arch "G" {
  node alice: Person "Alice";
  node bank: System "Bank";
  node mail: System "Mail";
  edge alice -> bank "logs in";
  edge bank -> mail "pays";
}`;

const item = (page, name) => page.locator(s.menuItem, { hasText: name });
const rightClickNode = (page, id) => page.locator(`${sel.node(id)} text`).first().click({ button: 'right' });

test('Decompose is offered only on a node whose type has a detailing', async ({ page }) => {
  await openEditor(page, architecture);

  await rightClickNode(page, 'alice');
  await expect(page.locator(s.menu)).toBeVisible();
  await expect(item(page, 'Decompose')).toHaveCount(0);

  await page.mouse.click(5, 5);
  await rightClickNode(page, 'bank');
  await expect(item(page, 'Decompose')).toBeVisible();
});

test('decomposing a node with two edges gives each edge its own detail', async ({ page }) => {
  await openEditor(page, architecture);
  await rightClickNode(page, 'bank');
  await item(page, 'Decompose').click();

  await expect(page.locator(s.menu)).toHaveCount(0);
  const vgl = await vglText(page);
  expect(vgl).toContain('group bank: System "Bank"');
  expect(vgl).toMatch(/node container_1: Container "Change Me"/);
  expect(vgl).toMatch(/node container_2: \w+ "Change Me"/);
  expect(vgl).toContain('edge alice -> container_1 "logs in"');
  expect(vgl).toContain('edge container_2 -> mail "pays"');
});

test('the decomposed node is shown unfolded, its details on the canvas', async ({ page }) => {
  await openEditor(page, architecture);
  await rightClickNode(page, 'bank');
  await item(page, 'Decompose').click();

  await expect(page.locator(sel.node('container_1'))).toBeVisible();
  await expect(page.locator(sel.node('container_2'))).toBeVisible();
});
