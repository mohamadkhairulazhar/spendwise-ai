const {test, expect} = require('@playwright/test');

test.use({viewport: {width: 393, height: 852}});
for (const colorScheme of ['light', 'dark']) {
  test(`minimal interface follows ${colorScheme} device appearance`, async ({page}, testInfo) => {
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.emulateMedia({colorScheme});
    await page.goto('./');
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    await expect(page.getByText('Net worth RM 5490.00', {exact: false})).toBeVisible();
    await expect(page.getByRole('button', {name: 'Activity', exact: true})).toBeVisible();
    await expect(page.getByText('SYNTHETIC DEMO', {exact: false})).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    await page.screenshot({path: testInfo.outputPath(`interface-overview-${colorScheme}.png`)});
    await page.getByRole('button', {name: 'Transaction', exact: true}).click();
    await expect(page.getByRole('heading', {name: 'New transaction'})).toBeVisible();
    await expect(page.getByRole('textbox', {name: /Amount \(MYR\)/})).toBeVisible();
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    await page.screenshot({path: testInfo.outputPath(`interface-entry-${colorScheme}.png`)});
    expect(errors).toEqual([]);
  });
}
