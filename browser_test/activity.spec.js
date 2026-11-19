const {test, expect} = require('@playwright/test');

test.use({viewport: {width: 1280, height: 1100}});

async function search(page, value) {
  const field = page.getByRole('textbox', {name: /Search activity/});
  await field.click();
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  await expect(field).toHaveValue('');
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await page.keyboard.type(value, {delay: 20});
  await expect(field).toHaveValue(value);
  await page.keyboard.press('Tab');
}

test('search and calendar grouping preserve the ledger and open scoped account history', async ({page}) => {
  await page.goto('./');
  await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
  await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();
  await expect(page.locator('flt-semantics-host').getByText('8 entries', {exact: true})).toBeVisible();
  await page.getByRole('button', {name: 'Month', exact: true}).click();
  const {month, year} = await page.evaluate(() => ({
    month: new Date().toLocaleString('en-GB', {month: 'long'}),
    year: String(new Date().getFullYear()),
  }));
  await expect(page.getByRole('heading', {name: `${month} ${year}`, exact: true})).toBeVisible();
  await page.getByRole('button', {name: 'Year', exact: true}).click();
  await expect(page.getByRole('heading', {name: year, exact: true})).toBeVisible();
  await search(page, 'GROCERIES rm85.00');
  await expect(page.locator('flt-semantics-host').getByText('1 entry', {exact: true})).toBeVisible();
  await expect(page.getByRole('button', {name: /Synthetic groceries/})).toBeVisible();
  await search(page, 'demo-transfer');
  await expect(page.locator('flt-semantics-host').getByText('1 entry', {exact: true})).toBeVisible();
  await page.getByRole('button', {name: /Synthetic wallet top-up/}).click();
  await expect(page.getByText('Reference: demo-transfer', {exact: true})).toBeVisible();
  await expect(page.getByText('Account: demo-bank', {exact: false})).toBeVisible();
  await expect(page.getByText('Account: demo-cash', {exact: false})).toBeVisible();
  await search(page, 'does not exist synthetic');
  await expect(page.locator('flt-semantics-host').getByText('0 entries', {exact: true})).toBeVisible();
  await expect(page.locator('flt-semantics-host').getByText('No matching activity.', {exact: false})).toBeVisible();
  await page.getByRole('button', {name: 'Clear search', exact: true}).click();
  await expect(page.locator('flt-semantics-host').getByText('8 entries', {exact: true})).toBeVisible();
  await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();

  await page.getByRole('button', {name: 'Accounts', exact: true}).click();
  await page.getByRole('button', {name: /^Synthetic Wallet /}).click();
  await expect(page.getByRole('heading', {name: 'Account history', exact: true})).toBeVisible();
  await expect(page.getByText('Account balance RM 325.00', {exact: false})).toBeVisible();
  await expect(page.locator('flt-semantics-host').getByText('3 entries', {exact: true})).toBeVisible();
  await expect(page.getByRole('button', {name: /Synthetic wallet top-up/})).toBeVisible();
  await expect(page.getByRole('button', {name: /Synthetic wallet top-up.*\+RM 150\.00/})).toBeVisible();
  await expect(page.getByRole('button', {name: /Synthetic groceries/})).toHaveCount(0);
  await search(page, 'repayment');
  await expect(page.locator('flt-semantics-host').getByText('0 entries', {exact: true})).toBeVisible();
  await page.getByRole('button', {name: 'Back', exact: true}).click();

  await page.getByRole('button', {name: /^Synthetic Credit Card /}).click();
  await expect(page.getByText('Amount owed RM 85.00', {exact: false})).toBeVisible();
  await expect(page.locator('flt-semantics-host').getByText('3 entries', {exact: true})).toBeVisible();
  await expect(page.getByRole('button', {name: /Synthetic groceries.*\+RM 85\.00/})).toBeVisible();
  await expect(page.getByRole('button', {name: /Synthetic card repayment.*−RM 100\.00/})).toBeVisible();
  await search(page, 'bank repayment');
  await expect(page.locator('flt-semantics-host').getByText('1 entry', {exact: true})).toBeVisible();
  await page.getByRole('button', {name: /Synthetic card repayment/}).click();
  await expect(page.getByText('Reference: demo-repayment', {exact: true})).toBeVisible();
  await expect(page.getByText('Account: demo-bank', {exact: false})).toBeVisible();
  await expect(page.getByText('Account: demo-card', {exact: false})).toBeVisible();
  await page.getByRole('button', {name: 'Back', exact: true}).click();
  await expect(page.getByText('All-time expenses RM 110.00', {exact: false})).toBeVisible();
  await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();
});
