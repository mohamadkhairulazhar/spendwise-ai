# SpendWise AI — Phase 1

Offline-first personal finance for Malaysian users. Flutter/Dart, MYR only,
SQLite on iOS and Android. No server, login, AI, sync or bank connection.
The app starts empty; all examples and test fixtures are synthetic.

## Run

Use Flutter **3.35.7** (Dart 3.9), Android SDK and JDK 17 for Android, or
macOS with Xcode and CocoaPods for iOS. Enable developer mode on a physical
Android phone or start an emulator. For iOS, start a simulator or configure
your own signing team in `ios/Runner.xcworkspace` for a device.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

No environment variables, API keys or backend setup are needed. On first run,
SQLite creates `spendwise.db` in the application's database directory.
`flutter pub get`/the first build generates platform tooling and plugin registrants.

```sh
dart format lib test
flutter analyze
flutter test --coverage
flutter build apk --debug
# macOS with Xcode only:
flutter build ios --simulator --debug
```

On Linux the SQLite FFI tests need `libsqlite3` (Ubuntu: `libsqlite3-dev`).
Development APKs use debug signing; configure release signing before distribution.

## Use

1. Add accounts with names and opening balances. Choose bank, cash wallet or
   credit card. For cards, enter the **debt owed**, not a credit limit.
2 oil card for a card purchase, or source and destination accounts for transfers
   and repayments. Amounts are MYR with at most two decimal places.
3. Tap an account to rename it. Open audit history entries to see the operation
   reference, timestamp, note and each persisted balance movement.

Example: a synthetic bank starts at RM1,000 and a card at RM0. A RM50 card
purchase creates RM50 debt and RM50 expenses, with bank cash still RM1,000.
Repaying RM30 leaves bank cash RM970 and card debt RM20; expenses stay RM50.
Moving RM100 from that bank to a wallet leaves net worth and spending unchanged.

## Financial model

All money is an integer number of **sen**, from exact decimal parsing through
SQLite storage and formatting. No floating-point conversion is used. The maximum
amount or per-account balance is 999,999,999,999 sen (RM9,999,999,999.99).
Balances and card liabilities must stay nonnegative. Overdrafts, credit balances
on cards and repayments beyond the outstanding debt are rejected in Phase 1.

| Operation | Bank / cash | Card debt | Reporting |
| --- | --- | --- | --- |
| Opening | increases assets if applicable | increases opening debt if applicable | neither |
| Income | increases | unchanged | income |
| Expense | decreases | unchanged | expense |
| Card purchase | unchanged | increases | expense |
| Repayment | decreases | decreases | neither |
| Transfer | decreases source, increases destination | not supported | neither |

Balances are derived from the sum of immutable signed postings, not editable
balance fields. Asset postings represent cash held; card postings represent debt
owed (a positive card posting increases a liability). Net worth subtracts debt.
This is a personal-finance ledger, not a general-purpose double-entry accounting
system. Reports are all-time totals and exclude opening balances.

Each operation stores a stable UUID, SQLite sequence, UTC recorded timestamp,
kind, integer amount, account references, note and postings. Sequence determines
audit ordering even when timestamps match. A new account and its opening posting
(including zero) are created atomically. One opening per account is enforced.
Ledger entries cannot be edited or deleted; account identity/type is immutable,
and renaming never alters financial history. Corrections, refunds, account
closure and backdated reporting are future work.

Validation, balance reads, operation insertion and both postings share one SQLite
write transaction. Foreign keys and checks supplement domain validation. Duplicate
operation IDs are rejected, and failed writes roll back in full. The transaction
form keeps its UUID across retries and disables submission while saving.

## Architecture

- `lib/domain`: pure Dart financial rules, exact money parsing, entities and
  repository interface; no Flutter or SQLite dependencies.
- `lib/data`: SQLite repository and ordered forward-only migrations. Version 1
  creates accounts, operations and postings; version 2 adds indexes, unique
  opening constraint and immutability triggers. Downgrades fail without reset.
- `lib/presentation`: Provider/ChangeNotifier state, account forms, transaction
  forms, summaries and audit history. Widgets delegate financial rules to domain.
- `test`: money boundaries, deterministic ledger plans, full financial lifecycle,
  failed-operation rollback, duplicate IDs, concurrent spending, persistence,
  v1→v2 migration, foreign keys, audit immutability and basic widget validation.

SQLite is the local source of truth. Once installed, all app functionality works
without a network. No analytics or financial data leaves the app. Storage is
app-private but is not additionally encrypted; OS backups are subject to device
settings. Uninstalling the app can delete its database. Export/backup recovery
and stronger storage protection are outside Phase 1.

## Verification status

The implementation environment initially had no Flutter or Dart SDK. Bootstrap
was attempted with the official Flutter 3.35.7 source, but its SDK download from
`storage.googleapis.com` was blocked with HTTP 403. Local Flutter formatting,
static analysis, unit/widget tests and native builds therefore could not run at
that stage. GitHub Actions is configured to run formatting, analysis, all tests,
an Android debug APK build and a macOS iOS simulator build. Consult the PR checks
for actual results; configuration alone is not evidence of a passing build.

Native project templates come from Flutter 3.35.7; see
`FLUTTER_TEMPLATE_LICENSE` for their license.

## Web demo (Chrome and Safari)

The web build uses the same ledger, migrations and SQLite repository as mobile.
A conditional adapter selects `sqflite_common_ffi_web` 1.0.2 (SQLite WASM backed by
IndexedDB). Modern Chrome and Safari 16+ are targets. SharedWorker coordinates
SQLite access across tabs when supported. Browsers falling back to a dedicated
worker should use one tab at a time. Private browsing/storage restrictions or
quota exhaustion can prevent persistence; startup shows a retry error rather
than silently replacing the database. Browser storage can be cleared by the user
or evicted by the OS and is not a backup.

```sh
flutter pub get
dart run sqflite_common_ffi_web:setup --force
flutter run -d chrome --web-port 8080 --dart-define=SPENDWISE_DEMO=true
# Production-equivalent Pages build, including worker and WASM setup:
bash tool/build_web.sh
python3 tool/serve_web.py
# Open http://127.0.0.1:8080/spendwise-ai/
npm ci
npx playwright install --with-deps chromium webkit
npm run test:browser
```

`SPENDWISE_DEMO=true` seeds a dedicated `spendwise-demo-v1.db` once, only when
empty, with invented bank/wallet/card balances, income, spending, transfer and
repayment. The entire seed is atomic. Its expected net worth is **RM5,490.00**,
income **RM2,500.00**, expenses **RM110.00**, and card debt **RM85.00**. Reloads
preserve changes. A visible banner labels every demo screen and asks visitors
not to enter real financial information. There are no real customer details in
source, fixtures or deployed assets. Normal mobile runs remain empty; demo mode
is opt-in. All visitors' edits remain in their own browser; no data is uploaded.

The Pages base path is `/spendwise-ai/`, including the trailing slash. Worker,
WASM, CanvasKit and bundled Roboto font assets are served locally. Flutter's
service worker supports offline reload after the first successful load and
activation; the very first visit requires network access. No cross-origin
isolation headers or SharedArrayBuffer are required for SQLite.

`.github/workflows/pages.yml` builds and runs Chromium and WebKit persistence /
offline smoke tests on PRs. It uploads the exact tested output as a Pages
artifact. Deployment runs on `main` after merge, or an explicit workflow dispatch
of a reviewed ref. PRs never publish automatically. In GitHub **Settings → Pages**,
select **GitHub Actions** as the build source and permit deployment from the
chosen ref in the `github-pages` environment. A private repository may need a
Pages-capable GitHub plan. The expected URL is
https://mohamadkhairulazhar.github.io/spendwise-ai/ once deployment succeeds.
No custom domain is required. Chromium and Playwright WebKit are automated
coverage; real Safari on macOS/iOS should also receive a device smoke test before
claiming full Safari device certification.

### Pages hosting setup

An owner must enable **Settings → Pages → Source: GitHub Actions**. Repository
plan/visibility must permit Pages hosting. The connected API in the implementation
environment cannot administer Pages settings (it returns Forbidden). The workflow
uses only `pages: write` and `id-token: write` for deployment, and targets the
`github-pages` environment. PRs build and test; publication runs on `main` after
review, or by manual dispatch once the workflow exists on the default branch.
No merge or public deployment is implied by an open PR. The intended public URL
is `https://mohamadkhairulazhar.github.io/spendwise-ai/` once hosting is enabled
and a deployment succeeds. Only generated synthetic-demo assets are published.

Chrome is checked with Playwright's Chrome channel, WebKit tests cover reload,
editing, IndexedDB persistence and offline operation, and a macOS WebDriver job
loads the build in actual Safari. Desktop/mobile native builds stay in their
separate Flutter workflow. A passing WebKit job alone is not an actual Safari
verification. All generated WASM/worker assets are rebuilt from the locked Dart
dependencies. Browser automation dependencies are in `package-lock.json`.
