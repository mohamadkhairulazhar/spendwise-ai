const {test, expect} = require('@playwright/test');

// Fresh browser contexts keep every scenario synthetic and independent.
test.setTimeout(120000);
test.use({viewport: {width: 1280, height: 1100}});

async function openLedger(page) {
  await page.goto('./');
  await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
  await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();
}

async function typeText(page, label, value) {
  const field = page.getByRole('textbox', {name: label});
  await field.click();
  // Focus replaces Flutter's DOM editor; wait for the render/focus frames.
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  // Keyboard events update Flutter's editor in both Chrome and WebKit.
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  await expect(field).toHaveValue('');
  await page.keyboard.type(value, {delay: 20});
  await expect(field).toHaveValue(value);
  await page.keyboard.press('Tab');
}

async function choose(page, field, option) {
  await page.getByRole('button', {name: field}).click();
  await page.getByRole('menuitem', {name: option, exact: true}).click();
}

async function summary(page, {net, income, expenses}) {
  await expect(page.getByText(`Net worth RM ${net}`, {exact: false})).toBeVisible();
  await expect(page.getByText(`All-time income RM ${income}`, {exact: false})).toBeVisible();
  await expect(page.getByText(`All-time expenses RM ${expenses}`, {exact: false})).toBeVisible();
}

async function balance(page, name, type, amount) {
  await expect(page.getByRole('button', {
    name: `${name} ${type} RM ${amount}`, exact: true,
  })).toBeVisible();
}

async function startEntry(page, kind, source, destination) {
  await page.getByRole('button', {name: 'Transaction', exact: true}).click();
  await expect(page.getByRole('heading', {name: 'New transaction'})).toBeVisible();
  await choose(page, /^Transaction type /, kind);
  await choose(page, destination ? /^From bank \/ cash$/ : /^Account$/, source);
  if (destination) {
    await choose(page, kind === 'Card repayment' ? /^Credit card to repay$/ : /^To bank \/ cash$/, destination);
  }
}

async function saveEntry(page, amount, note) {
  await typeText(page, /Amount \(MYR\)/, amount);
  await typeText(page, /Note \(optional\)/, note);
  await page.getByRole('button', {name: 'Record transaction', exact: true}).click();
}

test('account opening balances reach SQLite and reporting without becoming income or expense', async ({page}) => {
  await openLedger(page);
  const accounts = [
    ['Synthetic Integration Bank', 'Bank account', '10.01'],
    ['Synthetic Integration Wallet', 'Cash wallet', '0.02'],
    ['Synthetic Integration Card', 'Credit card', '3.04'],
  ];
  for (const [name, type, opening] of accounts) {
    await page.getByRole('button', {name: 'Add account', exact: true}).click();
    await typeText(page, /Account name/, name);
    await choose(page, /^Account type /, type);
    await typeText(page, /Opening (balance|debt) \(MYR\)/, opening);
    await page.getByRole('button', {name: 'Save account', exact: true}).click();
    await balance(page, name, type === 'Credit card' ? 'Credit card · Amount owed' : type, opening);
  }
  await summary(page, {net: '5496.99', income: '2500.00', expenses: '110.00'});
  await page.reload();
  await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
  for (const [name, type, opening] of accounts) {
    await balance(page, name, type === 'Credit card' ? 'Credit card · Amount owed' : type, opening);
  }
  await summary(page, {net: '5496.99', income: '2500.00', expenses: '110.00'});
});

test('transaction forms preserve ledger rules, failed writes, audit legs and exact sen across reload', async ({page}) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await openLedger(page);

  await startEntry(page, 'Income', 'Synthetic Bank');
  await saveEntry(page, '100.01', 'Synthetic integration income');
  await balance(page, 'Synthetic Bank', 'Bank account', '5350.01');
  await summary(page, {net: '5590.01', income: '2600.01', expenses: '110.00'});

  await startEntry(page, 'Expense', 'Synthetic Wallet');
  await saveEntry(page, '0.001', 'Synthetic integration expense');
  await expect(page.locator('flt-semantics-host').getByText('Enter MYR with up to two decimal places.', {exact: true})).toBeVisible();
  await expect(page.getByRole('heading', {name: 'New transaction'})).toBeVisible();
  // Reuse the failed form: invalid precision must not create an expense.
  await saveEntry(page, '12.34', 'Synthetic integration expense');
  await balance(page, 'Synthetic Wallet', 'Cash wallet', '312.66');
  await summary(page, {net: '5577.67', income: '2600.01', expenses: '122.34'});

  await startEntry(page, 'Transfer', 'Synthetic Bank', 'Synthetic Wallet');
  await saveEntry(page, '50.02', 'Synthetic integration transfer');
  await balance(page, 'Synthetic Bank', 'Bank account', '5299.99');
  await balance(page, 'Synthetic Wallet', 'Cash wallet', '362.68');
  await summary(page, {net: '5577.67', income: '2600.01', expenses: '122.34'});

  await startEntry(page, 'Card purchase', 'Synthetic Credit Card');
  await saveEntry(page, '20.03', 'Synthetic integration card purchase');
  await balance(page, 'Synthetic Bank', 'Bank account', '5299.99');
  await balance(page, 'Synthetic Credit Card', 'Credit card · Amount owed', '105.03');
  await summary(page, {net: '5557.64', income: '2600.01', expenses: '142.37'});

  await startEntry(page, 'Card repayment', 'Synthetic Bank', 'Synthetic Credit Card');
  await saveEntry(page, '999.99', 'Synthetic integration repayment');
  await expect(page.locator('flt-semantics-host').getByText('Insufficient balance, excess repayment, or balance limit exceeded.', {exact: true})).toBeVisible();
  await expect(page.getByRole('heading', {name: 'New transaction'})).toBeVisible();
  // A rejected repayment must leave no posting, including when retried on this form.
  await saveEntry(page, '30.04', 'Synthetic integration repayment');
  await balance(page, 'Synthetic Bank', 'Bank account', '5269.95');
  await balance(page, 'Synthetic Wallet', 'Cash wallet', '362.68');
  await balance(page, 'Synthetic Credit Card', 'Credit card · Amount owed', '74.99');
  await summary(page, {net: '5557.64', income: '2600.01', expenses: '142.37'});

  const audit = page.getByRole('button', {name: /Synthetic integration repayment/});
  await expect(audit).toHaveCount(1);
  await audit.click();
  await expect(page.getByText('Account: demo-bank', {exact: false})).toBeVisible();
  await expect(page.getByText('Account: demo-card', {exact: false})).toBeVisible();
  await expect(page.getByText('RM -30.04', {exact: false})).toHaveCount(2);

  await page.reload();
  await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
  await balance(page, 'Synthetic Bank', 'Bank account', '5269.95');
  await balance(page, 'Synthetic Wallet', 'Cash wallet', '362.68');
  await balance(page, 'Synthetic Credit Card', 'Credit card · Amount owed', '74.99');
  await summary(page, {net: '5557.64', income: '2600.01', expenses: '142.37'});
  await expect(page.getByRole('button', {name: /Synthetic integration repayment/})).toHaveCount(1);
  expect(errors).toEqual([]);
});
