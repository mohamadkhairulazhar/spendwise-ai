const {defineConfig} = require('@playwright/test');
module.exports = defineConfig({
  testDir: './browser_test',
  timeout: 90000,
  expect: {timeout: 30000},
  retries: 0,
  use: {viewport: {width: 1280, height: 1100}, baseURL: 'http://127.0.0.1:8080/spendwise-ai/', trace: 'retain-on-failure'},
  projects: [
    {name: 'chromium', use: {browserName: 'chromium', channel: 'chrome'}},
    {name: 'webkit', use: {browserName: 'webkit'}},
  ],
  webServer: {command: 'python3 tool/serve_web.py', url: 'http://127.0.0.1:8080/spendwise-ai/', reuseExistingServer: false},
  reporter: [['list'], ['html', {open: 'never'}]],
});
