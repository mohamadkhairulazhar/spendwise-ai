const {test, expect} = require('@playwright/test');

async function enableAccessibility(page) {
  // Flutter paints with CanvasKit; enable its standard accessibility tree.
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({state: 'attached'});
  await placeholder.evaluate(element => element.click());
}

test('synthetic ledger, editing, IndexedDB persistence and offline reload', async ({page, context}) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('./');
  await enableAccessibility(page);
  await expect(page.getByText('SYNTHETIC DEMO', {exact: false})).toBeVisible();
  await expect(page.getByText('Net worth RM 5490.00', {exact: true})).toBeVisible();
  await expect(page.getByText('Synthetic Credit Card', {exact: true})).toBeVisible();
  // Renaming exercises a browser SQLite write, rather than relying only on seed.
  await page.getByText('Synthetic Wallet', {exact: true}).click();
  await page.getByRole('textbox', {name: /Account name/}).fill('Synthetic Demo Pocket');
  await page.getByRole('button', {name: 'Save account', exact: true}).click();
  await expect(page.getByText('Synthetic Demo Pocket', {exact: true})).toBeVisible();
  await page.reload();
  await enableAccessibility(page);
  await expect(page.getByText('Synthetic Demo Pocket', {exact: true})).toBeVisible();
  await expect(page.getByText('Net worth RM 5490.00', {exact: true})).toBeVisible();
  // Wait for the generated Flutter service worker to take control before going offline.
  await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.ready;
    if (!navigator.serviceWorker.controller) {
      await new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, {once: true}));
    }
    return registration.active.state;
  });
  await context.setOffline(true);
  await page.reload();
  await enableAccessibility(page);
  await expect(page.getByText('Synthetic Demo Pocket', {exact: true})).toBeVisible();
  await expect(page.getByText('Net worth RM 5490.00', {exact: true})).toBeVisible();
  expect(errors).toEqual([]);
});
