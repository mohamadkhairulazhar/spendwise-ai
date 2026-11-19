const {test, expect} = require('@playwright/test');

test.use({viewport: {width: 1280, height: 1100}});

async function search(page, value) {
  const field = page.getByRole('textbox', {name: /Search activity/});
  await field.click();
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(value, {delay: 20});
  await expect(field).toHaveValue(value);
  await page.keyboard.press('Tab');
}

test('search and calendar grouping preserve the ledger and open scoped account history', async ({page}) => {
  await page.goto('./');
  await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
  await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();
  await expect(page.getByText('8 entries', {exact: true})).toBeVisible();
  await page.getByRole('button', {name: 'Month', exact: true}).click();
  const {month, year} = await page.evaluate(() => ({
    month: new Date().toLocaleString('en-GB', {month: 'long'}),
    year: String(new Date().getFullYear()),
  }));
  await expect(page.getByText(`${month} ${year}`, {exact: true})).toBeVisible();
  await page.getByRole('button', {name: 'Year', exact: true}).click();
  await expect(page.getByText(year, {exact: true})).toBeVisible();
  await search(page, 'GROCERIES rm85.00');
  await expect(page.getByText('1 entry', {exact: true})).toBeVisible();
  await expect(page.getByRole('button', {name: /Synthetic groceries/})).toBeVisible();
  await search(page, 'demo-transfer');
  await expect(page.getByText('1 entry', {exact: true})).toBeVisible();
  await page.getByRole('button', {name: /Synthetic wallet top-up/}).click();
  await expect(page.getByText('Reference: demo-transfer', {exact: true})).toBeVisible();
  await expect(page.getByText('Account: demo-bank', {exact: false})).toBeVisible();
  await expect(page.getByText('Account: demo-cash', {exact: false})).toBeVisible();
  await search(page, 'does not exist synthetic');
  await expect(page.getByText('0 entries', {exact: true})).toBeVisible();
  await expect(page.getByText('No matching activity.', {exact: false})).toBeVisible();
  await page.getByRole('button', {name: 'Clear search', exact: true}).click();
  await expect(page.getByText('8 entries', {exact: true})).toBeVisible();
  await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();

  await page.getByRole('button', {name: 'Accounts', exact: true}).click();
  await page.getByRole('button', {name: /^Synthetic Wallet /}).click();
  await expect(page.getByText('Account history', {exact: true})).toBeVisible();
  await expect(page.getByText('Account balance RM 325.00', {exact: false})).toBeVisible();
  await expect(page.getByText('3 entries', {exact: true})).toBeVisible();
  await expect(page.getByRole('button', {name: /Synthetic wallet top-up/})).toBeVisible();
  await expect(page.getByText('+RM 150.00', {exact: true})).toBeVisible();
  await expect(page.getByRole('button', {name: /Synthetic groceries/})).toHaveCount(0);
  await search(page, 'repayment');
  await expect(page.getByText('0 entries', {exact: true})).toBeVisible();
  await page.getByRole('button', {name: 'Back', exact: true}).click();

  await page.getByRole('button', {name: /^Synthetic Credit Card /}).click();
  await expect(page.getByText('Amount owed RM 85.00', {exact: false})).toBeVisible();
  await expect(page.getByText('3 entries', {exact: true})).toBeVisible();
  await expect(page.getByText('+RM 85.00', {exact: true})).toBeVisible();
  await expect(page.getByText('−RM 100.00', {exact: true})).toBeVisible();
  await search(page, 'bank repayment');
  await expect(page.getByText('1 entry', {exact: true})).toBeVisible();
  await page.getByRole('button', {name: /Synthetic card repayment/}).click();
  await expect(page.getByText('Reference: demo-repayment', {exact: true})).toBeVisible();
  await expect(page.getByText('Account: demo-bank', {exact: false})).toBeVisible();
  await expect(page.getByText('Account: demo-card', {exact: false})).toBeVisible();
  await page.getByRole('button', {name: 'Back', exact: true}).click();
  await expect(page.getByText('All-time expenses RM 110.00', {exact: false})).toBeVisible();
  await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();
});
