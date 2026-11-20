# SpendWise AI

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
2. Tap Transaction to record income or spending. Choose a bank/cash account for
   cash movement, a credit card for a card purchase, or source and destination accounts for transfers
   and repayments. Amounts are MYR with at most two decimal places.
3. Open Activity and search notes, account names, operation types, MYR amounts,
   local dates (for example `2026-11-19`) or ledger references. Search ignores case
   and combines words. Use Day, Month or Year to group the matching audit entries.
4. Tap an account to open its history, including opening balances and both sides
   of transfers and card repayments. Amount signs show that account's movement;
   for cards, positive amounts increase debt and negative amounts reduce it.
   Rename the account with the edit button on its history screen.
5. Expand an activity entry to see its full note, local recorded timestamp,
   immutable reference and each persisted balance movement.

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

Each operation stores a stable reference (UUID for user entry), SQLite sequence, UTC recorded timestamp,
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
app-private but the ledger is not additionally encrypted. Android platform backup
and device transfer are disabled; iOS backups depend on device settings. Uninstalling the app can delete its database. Export/backup recovery
and stronger storage protection are outside Phase 1.

## Verification

GitHub Actions runs Dart formatting, static analysis, unit/widget tests,
Android debug APK and iOS simulator builds, plus a release web build and browser
checks. Run the same commands above locally. Browser checks use Chrome, WebKit
and actual Safari via WebDriver on macOS. CI reports are available under the
repository's Actions tab and the PR checks. Physical-device testing is not part
of these automated checks.

Native project templates come from Flutter 3.35.7; see
`FLUTTER_TEMPLATE_LICENSE` for their license.

## Web demo (Chrome and Safari)

The web app shares the mobile ledger, migrations and SQLite repository. A
conditional adapter uses `sqflite_common_ffi_web` 1.0.2: SQLite WebAssembly with
IndexedDB persistence. Modern Chrome and Safari 16+ are targets. SharedWorker
coordinates cross-tab access; browsers falling back to a dedicated worker should
use one tab at a time. Restricted/private browsing or storage quota exhaustion
can prevent persistence; the app reports an error instead of silently resetting.
Browser storage can be evicted or cleared and is not a backup.

```sh
flutter pub get
dart run sqflite_common_ffi_web:setup --force
flutter run -d chrome --web-port 8080 --dart-define=SPENDWISE_DEMO=true
# Build exactly as Pages does, then serve at its real subdirectory:
bash tool/build_web.sh
python3 tool/serve_web.py
# Open http://127.0.0.1:8080/spendwise-ai/
npm ci
npx playwright install --with-deps chrome webkit
npm run test:browser
```

`SPENDWISE_DEMO=true` atomically seeds a dedicated `spendwise-demo-v1.db` once,
only when empty. All names and amounts are invented. The sample includes opening
balances, income, expenses, a transfer, a card purchase and a repayment. Expected
net worth is **RM5,490.00**, income **RM2,500.00**, expenses **RM110.00**, and card
debt **RM85.00**. Reloads preserve edits. The visible banner labels every finance
screen as a synthetic demo and asks visitors not to enter real financial data.
Normal mobile runs start empty. No financial data is uploaded or shared between
visitors; each browser has its own database.

The Pages base path is **`/spendwise-ai/`**, including its trailing slash. Worker,
WASM, CanvasKit and the bundled Roboto font are served locally. The build script
normalizes the service worker to its Pages subdirectory and precaches all bundled
assets. Offline reload works after the first online load and service-worker
activation. SQLite requires no SharedArrayBuffer or cross-origin isolation headers.
Generated SQLite assets are recreated from locked Dart dependencies; browser test
dependencies are locked in `package-lock.json`.

### Build, browser checks and deployment

`.github/workflows/pages.yml` builds the release demo and runs browser integration
checks in Chrome and WebKit before uploading the exact tested output as a Pages
artifact. The checks cover account creation and opening balances for bank, cash
and credit cards; income, expenses, transfers, card purchases and repayments;
invalid precision and over-repayment rejection; unchanged reporting totals for
transfers/repayments; audit postings; and persistence after browser reload. Chrome
also checks offline reload. Each scenario uses a fresh synthetic browser context;
no test writes financial data to a backend. A macOS WebDriver job loads that artifact
in actual Safari. Safari runs independently of publishing so macOS runner queues do not block the
verified Chrome/WebKit demo. A passing WebKit check alone is not an actual Safari check;
physical iPhone/iPad tests remain separate from desktop browser automation.

The repository is public and Pages Source is **GitHub Actions**. Deployment uses
the `github-pages` environment and only `pages: write` / `id-token: write` in the
deployment job. Main-branch builds and manual dispatch can publish. The explicitly
authorized initial `feat/phase-1-offline-ledger` PR in this repository may also
publish without merging; other PRs and forks cannot publish. Only generated
synthetic-demo assets are deployed. The deployment job checks the live app base
path and the SQLite WASM/worker URLs.

Demo URL: https://mohamadkhairulazhar.github.io/spendwise-ai/

The Flutter workflow separately checks formatting, analysis, all unit/widget
tests and Android/iOS builds. Native apps retain platform SQLite storage and do
not depend on any web assets or hosting service. See the PR's Actions checks for
the results associated with each revision.

The Playwright WebKit **offline-emulation** case is explicitly skipped because
`context.setOffline(true)` produces an internal navigation error in that engine.
Its online editing and IndexedDB reload checks still run. Offline operation is
checked in Chrome and in actual Safari, where the test stops the HTTP server
before reloading instead of using emulated network flags.

## Interface

The interface follows the device's light or dark appearance automatically.
Activity has searchable audit entries grouped by day, month or year; Accounts shows bank,
cash and card balances and account setup. First-time users start on Accounts.
The overview totals remain all-time figures. Tapping a transaction reveals its
ledger reference and postings. Transaction entry puts the MYR amount first and
uses the native keyboard. This is a presentation refresh of Phase 1; no budgets,
categories or other Phase 2 features are added.

Presentation code is split into `app_theme.dart`, `app_chrome.dart`,
`overview_screen.dart` and `forms.dart`. Responsive widget checks cover narrow
screens, larger text and live system-theme changes. Browser checks capture light
and dark mobile previews as the `interface-screenshots` Actions artifact.

Search and grouping are read-only views of the persisted audit ledger. Calendar
boundaries and displayed timestamps follow the device time zone; entries keep
ledger sequence order within each group. Groups appear newest first. Search and
account filters do not change the all-time overview totals or stored balances.
The account history uses persisted postings to include incoming transfers and
repayments as well as outgoing operations.

## Android notification capture — Phase 2 / PR #2

Android now has **Settings → Automatic Tracking** for opt-in, selected-application
notification capture. It starts disabled. Native Kotlin persists an encrypted,
private notification inbox before signalling Flutter, so capture does not depend
on the Flutter UI being open. Detection history shows captured/ignored metadata,
retention state and fixed failure diagnostics. Raw content requires an explicit
view action and can be deleted without touching the financial ledger.

This milestone does **not** parse, map accounts or post transactions. No banking
notification format or physical-device delivery has been validated. iOS and Web
retain manual tracking and show capture as unavailable. Android backups/device
transfer are disabled for privacy, including the existing ledger; uninstalling or
clearing app data can remove all local data.

See [Android capture architecture, limitations and physical-device verification](docs/android-notification-capture.md)
for verified package listing sources, privacy screening, retention, automated
commands, Xiaomi HyperOS guidance and the outstanding device test matrix.
PR #3 must wait for review and merge of PR #2.
