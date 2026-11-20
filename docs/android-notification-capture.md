# Phase 2 / PR #2 — Android notification capture

**Scope: capture only. No parsing, account mapping, classification, background
ledger posting, transfer matching or financial deduplication is enabled.**
No financial institution's notification formats have been validated. A package
listing is not evidence that its financial notifications are supported.
PR #3 must wait until this PR has been reviewed and merged.

## Phase 1 inspection and boundaries

`FinanceController` delegates transactions to `FinanceRepository.record`.
`SqliteFinanceRepository.record` calls the pure integer-sen `Ledger.plan` inside
one SQLite transaction, then inserts immutable operations and postings. The
version-2 schema has accounts, operations, postings, foreign keys, unique operation
IDs, unique opening entries and audit immutability triggers. Transfers and
repayments do not contribute income/expense totals; card purchases increase debt.
These services, accounting rules, schema and migrations are unchanged by PR #2.
The existing conditional SQLite native/Web adapter remains unchanged.

Android previously contained only a FlutterActivity. This PR isolates Kotlin
capture code under `android/app/.../capture`; Flutter talks to a small MethodChannel
adapter without Android imports in shared Dart code. iOS and Web show an
unavailable message for capture and retain every Phase 1 function.

## Transport architecture

1. Android binds the manifest-declared `NotificationListenerService` under the
   system-only `BIND_NOTIFICATION_LISTENER_SERVICE` permission.
2. The listener filters the package registry, then checks persisted user selection
   before accessing title/body. Everything starts disabled with no sources selected.
3. A process-wide serial native executor screens content and writes an app-private
   SQLite transport inbox, without creating a Flutter engine or requiring a channel.
4. Only after the SQLite commit does an optional EventChannel send an empty change
   signal. Flutter reads metadata from the durable inbox on start/resume and refresh.
5. No consumer acknowledges or removes captured events in this milestone. They
   remain `captured` or `ignored`, with raw-content availability recorded separately.

`notification-capture.db` is schema version 1 in Android's `noBackupFilesDir`.
It is deliberately separate from `spendwise.db`: capture cannot require starting
Dart or racing the ledger's migrations. It contains settings, selected sources
and notification envelopes, **no accounts, balances or financial transactions**.
SQLiteOpenHelper creates the new inbox; unsupported upgrades fail without a reset.
Future versions must add ordered native migrations. Phase 1 data is not migrated,
reset or opened by Kotlin. Existing ledger migration tests still run.

Later posting must still use the existing repository. A future consumer must
commit its idempotent operation and notification link atomically in the ledger
DB before acknowledging the native envelope. A crash between those steps must
be safe to retry. PR #2 does not implement that consumer or claim ledger-level
idempotency, account matching or verification of financial events.

## Identity, recovery and errors

Captured metadata includes source package, notification ID, post time, capture
time, an identity hash, stable capture reference, callback delivery count,
status, omission reason and content state. When retained, encrypted content also
holds title, ordinary/big/multiline body text, native key, tag, group key and the
application-supplied notification `when` value. Post time is not asserted to be
a verified financial transaction time.

Exact repeats of the same native identity, post time and content reuse one row
under a UNIQUE capture reference and transaction, incrementing delivery count.
Changed content or a new post time creates another envelope, even with the same
notification ID. This preserves updates for future review. It does not establish
that two envelopes are the same payment, or that a manually entered transaction
is a duplicate. Amount-only and timestamp-only financial matching do not exist.
Deletion/expiry leaves the capture reference, so an exact replay does not restore
previously deleted raw content. Inbox reads are paginated by SQLite sequence.

On listener connection, still-active selected notifications are re-read. Already
committed envelopes are immediately available after app/process restart. Settings
query current Android access permission rather than caching a granted flag.
Disconnect/reconnect state is exposed, a reconnect control requests system rebind,
and the app refreshes status on resume. Android remains responsible for binding
and restoring the listener after reboot/unlock; no custom boot receiver is added.

Exceptions produce fixed diagnostic codes/counts and timestamps, never exception
messages or notification text. Encryption failure has no plaintext fallback.
Unreadable content is marked unavailable without clearing metadata or the ledger.
Storage exhaustion can prevent a capture from committing; a diagnostic is attempted
separately. There is no claim that disk failure or Android delivery gaps can be
recovered. Recovery can only revisit notifications Android still exposes.

## Privacy and retention

- No backend, network calls, analytics, banking credentials, SMS permission,
  Accessibility Service, foreground service or wake lock is added.
- Android's access grant is broad; SpendWise only inspects text for explicitly
  selected registry entries. Disabling capture stops new capture, not retention.
- Raw envelopes use AES-256-GCM with a fresh IV and authenticated capture identity.
  The production key is generated in Android Keystore and is not exported.
  Keystore availability/security on a real device still requires verification.
- Generic credential/OTP markers, standalone code-like digits, unreadable content,
  oversized notifications and grouped summaries retain metadata only with a reason.
  This conservative privacy screen is not a bank parser and can omit genuine
  financial information. Unknown notification formats are not a promise of reliable
  credential recognition. Android may already redact sensitive content.
- Raw content defaults to **one day**, with explicit 7/30-day options. Shortening
  retention also shortens existing envelopes; increasing it only affects new ones.
  Expiry is checked before raw reads and on capture/settings/history operations.
  Physical cleanup waits for an execution opportunity; no periodic background job
  is claimed. Metadata remains to preserve replay suppression and diagnostics.
- Users can delete one envelope's raw content or all retained content. This removes
  encrypted text/native identifiers, not capture metadata or ledger audit history.
  SQLite secure-delete is enabled; only ciphertext is written for raw envelopes.
- History lists do not decrypt content. A separate explicit action reveals retained
  content; backgrounding hides it and invalidates pending reads. Do not share real
  notifications in screenshots, bug reports, CI fixtures or logs.
- Android platform backup is disabled. Android 12+ extraction rules also exclude
  app data from cloud backup and device transfer, including the existing ledger.
  Capture files additionally reside in no-backup storage. Uninstall/clear-data can
  remove all local data. There is no export/recovery feature in this milestone.

## Published package registry

Verified against publisher Google Play listings on 20 November 2026. These are
**opt-in capture source identities, not validated banking integrations**. CIMB is
excluded. No notification format is inferred from these listings.

| Application | Package / publisher listing |
| --- | --- |
| Touch 'n Go eWallet (P0) | [`my.com.tngdigital.ewallet`](https://play.google.com/store/apps/details?id=my.com.tngdigital.ewallet) |
| MAE by Maybank2u | [`com.maybank2u.life`](https://play.google.com/store/apps/details?id=com.maybank2u.life) |
| HLB Connect | [`my.com.hongleongconnect.mobileconnect`](https://play.google.com/store/apps/details?id=my.com.hongleongconnect.mobileconnect) |
| RHB Mobile Banking | [`com.rhbgroup.rhbmobilebanking`](https://play.google.com/store/apps/details?id=com.rhbgroup.rhbmobilebanking) |
| AEON Bank | [`com.personal.adb`](https://play.google.com/store/apps/details?id=com.personal.adb) |
| allianceonline Mobile | [`com.alliance.AOPMobileApp`](https://play.google.com/store/apps/details?id=com.alliance.AOPMobileApp) |

## Android execution limitations

A system-bound notification listener can capture while the Flutter Activity is
closed; it is not an always-running foreground service. The serial executor has
a short in-memory interval before the durable commit; process death before that
commit can lose the callback. Android does not guarantee every notification.
There is no parser/posting worker in PR #2. The later background ledger coordinator
must consider WorkManager or another justified strategy and execution delays;
WorkManager is not a guarantee of immediate posting.

Force-stop, disabled notification access, source-app notification settings, work
profiles, locked/pre-unlock credential storage, Android's sensitive-content
redaction and OEM battery management can prevent delivery. On Android 13+, a
sideloaded build may require the user to allow restricted settings from App info
before granting Notification Access. Do not bypass system security restrictions.

For Xiaomi/Redmi/POCO HyperOS, check **Settings → Apps → Background autostart** and
allow SpendWise, then set SpendWise's app battery saver to **No restrictions** where
available. Also verify notifications are enabled for each selected financial app.
Paths vary by model/region/HyperOS version. Test both normal and battery-saver
conditions, reboot/unlock and swipe-away behavior. These settings improve execution
opportunities; they do not guarantee delivery or justify disabling bank security.

Primary references:
[Android listener lifecycle](https://developer.android.com/reference/android/service/notification/NotificationListenerService),
[Android Keystore](https://developer.android.com/privacy-and-security/keystore),
[Android backup](https://developer.android.com/identity/data/autobackup),
[Android 15 sensitive notification restrictions](https://developer.android.com/about/versions/15/behavior-changes-all),
[WorkManager scheduling](https://developer.android.com/develop/background-work/background-tasks/persistent),
[Xiaomi background autostart](https://www.mi.com/uk/support/faq/details/KA-507608/),
[Xiaomi battery restrictions](https://www.mi.com/global/support/faq/details/KA-538010/).

## Automated checks

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
python3 tool/check_kotlin_format.py
flutter analyze
flutter test --coverage
flutter build apk --debug
(cd android && ./gradlew app:testDebugUnitTest --no-daemon)
# macOS with Xcode:
flutter build ios --simulator --debug
bash tool/build_web.sh
npm ci
npx playwright install --with-deps chrome webkit
npm run test:browser
```

The Kotlin formatter is a checksum/version-pinned development tool, not an APK
runtime dependency. JUnit/Robolectric are test-only dependencies. Native tests
simulate selection, callback extraction with no Flutter Activity/channel, replay
and revision handling, concurrent retries, reopen/pagination, encryption/AAD,
retention, deletion, unreadable-key failure and permission revocation. They do
not prove real Android binder delivery, device Keystore behavior or OEM lifecycle
behavior. All notification strings in tests are synthetic, not claimed bank formats.

CI retains a debug APK (`spendwise-android-capture-debug`) for physical verification
and native JUnit reports (`android-native-test-results`). The Web PR workflow only
builds/tests an artifact; this new feature branch cannot publish Pages before merge.

## Physical Android verification — required before capture acceptance

**Not executed in the cloud environment. No TNG/bank integration is validated.**
Record device model, Android/HyperOS build, SpendWise commit/APK, installed financial
app versions, date and tester. Keep notification content and credentials on the
owned test device. Do not commit real financial content or manufacture notification
formats. Do not make a financial payment just to test the listener.

1. Install the CI debug APK (or `flutter run`). Confirm existing ledger balances and
   histories survive an in-place update; use a synthetic ledger for testing.
2. Open **Settings → Automatic Tracking**. Confirm capture is off, no app selected,
   and permission status reflects Android settings. Open Notification Access and
   explicitly grant it. Return and confirm current status updates.
3. Select **TNG only** and enable capture. Verify listener connected or use reconnect.
   Let an ordinary notification arrive from the installed TNG app, if available;
   inspect it privately. Verify source, post time, ID, title/body and content state.
   Record only redacted field availability/template notes outside the repository.
4. Close/swipe away SpendWise's Flutter UI while keeping Notification Access enabled.
   Observe another selected-app notification. Reopen and verify the new envelope
   persisted and no financial ledger entry was created. Repeat with screen locked
   after first unlock, then after reboot/unlock. Distinguish swipe-away from force-stop.
5. Deliver/observe an unselected-app notification: no envelope should be captured.
   Turn global capture off and verify no new envelope is captured even from TNG.
6. Where a source legitimately reposts or updates a notification, check exact repeats
   increment deliveries, while changed content/post time remains a separate capture.
   Do not infer financial duplicates from this check.
7. Revoke Notification Access in Android settings and return to the app. Confirm
   revoked status. Regrant/reconnect and verify only still-visible callbacks can be
   recovered. Confirm old committed capture references remain after process restart.
8. Privately verify credential/OTP notifications are omitted; never copy an OTP to a
   test report. Verify omitted/summary/redacted events cannot expose raw content.
9. Show retained content, background the app and return: it must be hidden. Delete
   one/all retained content; metadata and every Phase 1 balance/audit entry must remain.
   With a disposable synthetic device profile, verify expiry and backup exclusion.
10. Repeat lifecycle checks on the actual Xiaomi HyperOS device with default battery
    policy and the documented opt-in settings. Record missing/delayed events honestly.

Test-only Android/Robolectric callbacks with synthetic package names exercise the
code path, not genuine bank delivery. `adb shell cmd notification post` uses the
shell package and **must be filtered out**; it cannot validate or spoof TNG/MAE.

| Physical verification | Result |
| --- | --- |
| TNG source delivery / real field availability | Not run |
| Closed Flutter UI / process restart | Not run |
| Reboot/unlock / HyperOS battery restrictions | Not run |
| Real Notification Access revoke/regrant | Not run |
| Device Android Keystore / backup exclusion | Not run |
| All other registered bank applications | Not run; formats unverified |

Only add sanitized, consented templates as PR #3 fixtures after local verification,
with app version/language and explicit validation evidence. No automatic posting
rule may be enabled from package identity or these synthetic callback tests alone.
