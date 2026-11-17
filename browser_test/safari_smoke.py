"""Actual Safari/WebDriver smoke test; run on the macOS CI runner."""
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

browser = webdriver.Safari()
try:
    browser.get('http://127.0.0.1:8080/spendwise-ai/')
    wait = WebDriverWait(browser, 60)
    wait.until(lambda d: d.find_elements(By.CSS_SELECTOR, 'flt-semantics-placeholder'))
    browser.execute_script("document.querySelector('flt-semantics-placeholder').click()")
    wait.until(lambda d: 'Net worth RM 5490.00' in d.page_source)
    assert 'SYNTHETIC DEMO' in browser.page_source
    assert 'Synthetic Credit Card' in browser.page_source
    browser.refresh()
    wait.until(lambda d: d.find_elements(By.CSS_SELECTOR, 'flt-semantics-placeholder'))
    browser.execute_script("document.querySelector('flt-semantics-placeholder').click()")
    wait.until(lambda d: 'Net worth RM 5490.00' in d.page_source)
    print('Actual Safari: synthetic SQLite ledger rendered after initial load and reload')
finally:
    browser.quit()
