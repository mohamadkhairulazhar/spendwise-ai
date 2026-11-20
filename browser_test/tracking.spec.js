const {test, expect} = require('@playwright/test');

test('web keeps Android capture unavailable without changing the ledger', async ({page}) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('./');
  await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
  await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();
  await page.getByRole('button', {name: 'Settings', exact: true}).click();
  await expect(page.getByRole('heading', {name: 'Settings', exact: true})).toBeVisible();
  await page.getByRole('button', {name: /^Automatic Tracking/}).click();
  await expect(page.getByRole('heading', {name: 'Automatic Tracking', exact: true})).toBeVisible();
  await expect(page.getByText('Notification capture is available only in the Android app.', {exact: false})).toBeVisible();
  await expect(page.getByRole('button', {name: 'Open settings', exact: true})).toHaveCount(0);
  await page.getByRole('button', {name: 'Back', exact: true}).click();
  await page.getByRole('button', {name: 'Back', exact: true}).click();
  await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();
  expect(errors).toEqual([]);
});
