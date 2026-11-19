"""Actual Safari/WebDriver check, including reload with the HTTP server stopped."""
import subprocess
import sys
import time
import urllib.request

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

url = 'http://127.0.0.1:8080/spendwise-ai/'
server = subprocess.Popen([sys.executable, 'tool/serve_web.py'])
browser = None
try:
    for attempt in range(40):
        try:
            urllib.request.urlopen(url, timeout=1).close()
            break
        except OSError:
            time.sleep(0.25)
    else:
        raise RuntimeError('Synthetic demo server did not start')
    browser = webdriver.Safari()
    browser.set_window_size(1280, 1100)
    wait = WebDriverWait(browser, 60)

    def check_ledger():
        wait.until(lambda d: d.find_elements(By.CSS_SELECTOR, 'flt-semantics-placeholder'))
        browser.execute_script("document.querySelector('flt-semantics-placeholder').click()")
        wait.until(lambda d: 'Net worth RM 5490.00' in d.page_source)
        assert 'SYNTHETIC DEMO' in browser.page_source
        assert 'Synthetic Credit Card' in browser.page_source

    browser.get(url)
    check_ledger()
    browser.refresh()
    check_ledger()
    browser.set_script_timeout(60)
    browser.execute_async_script('''
      const done = arguments[arguments.length - 1];
      navigator.serviceWorker.ready.then(() => {
        if (navigator.serviceWorker.controller) done(true);
        else navigator.serviceWorker.addEventListener('controllerchange', () => done(true), {once: true});
      });
    ''')
    # Real network loss avoids Playwright WebKit's setOffline navigation error.
    server.terminate()
    server.wait(timeout=10)
    browser.refresh()
    check_ledger()
    print('Actual Safari passed: synthetic SQLite ledger, reload, and offline reload with server stopped')
finally:
    if browser is not None:
        browser.quit()
    if server.poll() is None:
        server.terminate()
        server.wait(timeout=10)
