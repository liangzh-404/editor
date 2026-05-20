# CloudKit Sync Readiness

Date: 2026-05-20
Status: macOS Development private database path is live-writable; iOS device app data is readable; iOS-to-macOS foreground fetch and macOS-to-CloudKit upload are proven; clean macOS-to-iOS headless verification is blocked by the physical device lock screen.

## Objective

Enable offline-first CloudKit data sync between the macOS and iOS editor apps. Historical local data does not need to be preserved, so the implementation may reset local sync state when the CloudKit sync generation changes.

## Current Client State

- macOS and iOS targets use the same explicit CloudKit container: `iCloud.com.liangzhang.editor.sync`.
- CloudKit code uses `CKContainer(identifier: "iCloud.com.liangzhang.editor.sync")`, not `CKContainer.default()`.
- Runtime probe, business record save/delete, record fetch, and zone-change fetch all use custom zone `EditorSyncZone`.
- Remote-change subscription is a `CKRecordZoneSubscription` scoped to `EditorSyncZone`.
- Saves use `CKModifyRecordsOperation` with `.allKeys`, so rerunning an upload for the same deterministic record name overwrites instead of failing as a duplicate insert.
- Current app records use sync generation `editor-cloudkit-v2`; deterministic record names are prefixed with that generation, for example `editor-cloudkit-v2.block.<blockID>`.
- Remote records without the current `syncGeneration`, including earlier `editor-cloudkit-v1` records, are ignored by fresh clients. This keeps the disposable-history rollout isolated from stale Development database records.
- Both signed app products include `com.apple.developer.icloud-container-environment = Development`.
- Both signed app products include `com.apple.developer.icloud-container-identifiers = iCloud.com.liangzhang.editor.sync`.
- The signed macOS app includes `com.apple.security.app-sandbox = true` and `com.apple.security.network.client = true`.
- The signed iOS app includes `aps-environment = development` and registers for remote notifications at launch when CloudKit entitlements are present.
- iOS declares `UIBackgroundModes = remote-notification`; silent CloudKit pushes route through `RemoteNotificationSyncHandler`.
- The remote-notification sync handler attempts the remote fetch even if local pending uploads fail, so a queued/offline local change does not block incoming CloudKit updates from another device.
- The remote-notification sync handler now returns and persists a diagnostic report with `result`, `uploaded_count`, `failed_upload_count`, `fetched_count`, and an optional `error`, so APNs/background-sync readback can distinguish upload, fetch, and CloudKit account failures.
- Local data is reset when the `.sync-generation` marker is missing or mismatched.
- Local edits enqueue sync changes and remain available when CloudKit calls fail.
- No-op block text updates and no-op page title updates now return without bumping timestamps/revisions or enqueuing sync changes. This reduces false dirty state from programmatic UI/model refreshes during sync verification.
- Re-enqueuing the same local change coalesces older queued rows and clears stale retry state.
- Existing duplicate queued rows are coalesced when pending changes are read, so recovery attempts do not upload the same entity/change repeatedly.
- Schema version 11 compacts duplicate queued changes, adds `idx_sync_changes_entity_change`, and creates `runtime_diagnostics`, so the sync queue has a database-level uniqueness guard and APNs/background-sync diagnostics can be read back from SQLite.
- Delete tombstones are treated as synced when CloudKit reports `unknownItem`, so locally-created-then-deleted records do not stay stuck forever when the remote record never existed.
- Foreground activation triggers account refresh and a background foreground-sync pass.
- Active foreground sessions also poll CloudKit every 30 seconds, so remote changes can arrive while the app remains open without a manual action.
- Local sync queue writes notify the active workspace view model and automatically schedule a background foreground-sync pass.
- Failed foreground sync attempts put automatic foreground sync on a five-minute cooldown; the foreground poller retries after the cooldown expires.
- Manual sync is intentionally not exposed in the macOS menu or compact iOS library header because cross-device sync is expected to be automatic.
- A debug runtime probe can be enabled with `EDITOR_CLOUDKIT_PROBE=1`; it checks `accountStatus`, ensures the custom zone, fetches private database zones and subscriptions, saves a minimal record, fetches the same record, then deletes it.
- A debug headless sync diagnostic can be enabled with `EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC=1`; it bypasses the normal editor UI, optionally appends a block via `EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_APPEND_TEXT`, then ensures the subscription, uploads pending changes, fetches remote changes, and displays/logs the pending-change count.
- Remote page-reference block merges rebuild `page_parent_links`, so a page created from a block can still navigate back to its parent after syncing in from another device.

## CloudKit Schema State

Development schema was exported with a CloudKit management token and initially contained only `Users`; the app record types were missing.

Added local schema file:

```text
docs/cloudkit/editor-cloudkit-schema.ckdb
```

It defines:

- `EditorRuntimeProbeRecord`
- `WorkspaceRecord`
- `NotebookRecord`
- `PageRecord`
- `BlockRecord`
- `AttachmentRecord`
- `Users`

Schema validation:

```bash
CLOUDKIT_MANAGEMENT_TOKEN=... xcrun cktool validate-schema \
  --team-id H52N5N7WQ7 \
  --container-id iCloud.com.liangzhang.editor.sync \
  --environment development \
  --file docs/cloudkit/editor-cloudkit-schema.ckdb
```

Observed output:

```text
Schema is valid.
```

Schema import:

```bash
CLOUDKIT_MANAGEMENT_TOKEN=... xcrun cktool import-schema \
  --team-id H52N5N7WQ7 \
  --container-id iCloud.com.liangzhang.editor.sync \
  --environment development \
  --validate \
  --file docs/cloudkit/editor-cloudkit-schema.ckdb
```

The command exited successfully. Re-exporting the Development schema showed all app record types present.

## 500 Diagnosis

The original signed macOS debug probe failed before business record complexity was involved:

```text
2026-05-20 02:15:24.869 cloudkit_runtime_probe_account_status_succeeded status=available
2026-05-20 02:15:26.244 cloudkit_runtime_probe_save_failed ... CKHTTPStatus=500, ContainerID=iCloud.com.liangzhang.editor.sync, NSDebugDescription=CKInternalErrorDomain: 2000
2026-05-20 02:15:26.931 cloudkit_subscription_ensure_failed ... CKHTTPStatus=500, ContainerID=iCloud.com.liangzhang.editor.sync, NSDebugDescription=CKInternalErrorDomain: 2000
2026-05-20 02:15:27.450 sync_change_upload_failed entity_type=page entity_id=page-welcome ... CKHTTPStatus=500, ContainerID=iCloud.com.liangzhang.editor.sync, NSDebugDescription=CKInternalErrorDomain: 2000
```

A follow-up probe showed private database zone and subscription reads also returning HTTP 500:

```text
2026-05-20 02:25:42.628 cloudkit_runtime_probe_zones_failed ... CKHTTPStatus=500, ContainerID=iCloud.com.liangzhang.editor.sync
2026-05-20 02:25:43.143 cloudkit_runtime_probe_subscriptions_failed ... CKHTTPStatus=500, ContainerID=iCloud.com.liangzhang.editor.sync
2026-05-20 02:25:44.476 cloudkit_runtime_probe_save_failed ... CKHTTPStatus=500, ContainerID=iCloud.com.liangzhang.editor.sync
```

After importing the Development schema, the HTTP 500 disappeared. The next observed failures were client-side CloudKit model issues:

```text
2026-05-20 02:56:55.027 sync_change_upload_failed ... zoneID=_defaultZone:__defaultOwner__ ... record to insert already exists
2026-05-20 02:57:05.972 sync_now_failed ... zoneName=_defaultZone ... AppDefaultZone does not support getChanges call
```

Those errors led to the custom-zone and idempotent-save patch.

## Runtime Verification

Latest runtime probe command:

```bash
env OS_ACTIVITY_DT_MODE=1 OS_ACTIVITY_MODE=enable EDITOR_CLOUDKIT_PROBE=1 \
  /Users/liangzhang/Library/Developer/Xcode/DerivedData/Editor-gynpkkhwumhkoaftddpsqmdzeuhc/Build/Products/Debug/EditorMac.app/Contents/MacOS/EditorMac
```

CloudKit operation evidence from `2026-05-20 02:58:49` to `2026-05-20 02:58:56`:

```text
Finished CKFetchRecordZonesOperation operationID=BF45E91C6784E2F3 container=iCloud.com.liangzhang.editor.sync databaseScope=Private
Finished CKModifySubscriptionsOperation operationID=532ADB7B10B3F962 container=iCloud.com.liangzhang.editor.sync databaseScope=Private
Finished CKFetchRecordZonesOperation operationID=0C19A6BA12456C1A container=iCloud.com.liangzhang.editor.sync databaseScope=Private
Finished CKFetchSubscriptionsOperation operationID=4F731AAD0386FA74 container=iCloud.com.liangzhang.editor.sync databaseScope=Private
Finished CKModifyRecordsOperation operationID=7605C36DE369B3D4 container=iCloud.com.liangzhang.editor.sync databaseScope=Private
Finished CKModifyRecordsOperation operationID=AAF14E37DDFEDD02 container=iCloud.com.liangzhang.editor.sync databaseScope=Private
Finished CKFetchRecordZoneChangesOperation operationID=9EE4484838970093 container=iCloud.com.liangzhang.editor.sync databaseScope=Private
Finished CKFetchRecordsOperation operationID=5CF3D950FE02C44C container=iCloud.com.liangzhang.editor.sync databaseScope=Private
Finished CKModifyRecordsOperation operationID=D9E125D5FA0021E1 container=iCloud.com.liangzhang.editor.sync databaseScope=Private
```

An error-only log query for the same time window returned no CloudKit operation errors. This means the previously observed HTTP 500, `_defaultZone` getChanges failure, and duplicate-insert failure did not reproduce in the latest run.

Local SQLite evidence after the latest probe. This was captured before the
`editor-cloudkit-v2` generation bump, so the record-name prefix below is
legacy evidence rather than the current client generation:

```bash
sqlite3 "$HOME/Library/Containers/com.liangzhang.editor.mac/Data/Library/Application Support/Editor/editor.sqlite" \
  'select count(*) from sync_changes;'
```

```text
0
```

```bash
sqlite3 "$HOME/Library/Containers/com.liangzhang.editor.mac/Data/Library/Application Support/Editor/editor.sqlite" \
  'select entity_type, entity_id, record_name, change_tag from sync_records order by entity_type, entity_id;'
```

```text
page|page-welcome|editor-cloudkit-v1.page.page-welcome|9
```

```bash
sqlite3 "$HOME/Library/Containers/com.liangzhang.editor.mac/Data/Library/Application Support/Editor/editor.sqlite" \
  'select scope, length(token_base64), updated_at from sync_server_change_tokens order by scope;'
```

```text
privateDatabase|372|2026-05-19T18:58:54Z
```

The timestamp is UTC; in Asia/Shanghai this is `2026-05-20 02:58:54`.

## Cross-Device SQLite Verification

iOS app container access works through `devicectl`:

```bash
scripts/ios_sync_readback.sh
```

The script copies `editor.sqlite` from the iOS app data container, copies
optional WAL/SHM files when present, and prints schema version, pending sync
changes, server change tokens, runtime diagnostics, and recent blocks.

The copied iOS database contained user-created content and one pending local update before the macOS fetch run:

```text
sync_changes=1
block-463faaf7-6800-4604-a2b7-43084c757623|对，这截图基本能定位到两类问题了...
block-b13d8473-fb32-4321-a534-ca6343e90549|测完了
```

After launching the macOS Debug app with the CloudKit path enabled, the macOS database contained those iOS-origin blocks and had no pending local sync changes:

```text
block-463faaf7-6800-4604-a2b7-43084c757623|对，这截图基本能定位到两类问题了...|synced|2026-05-19T19:09:55Z
block-b13d8473-fb32-4321-a534-ca6343e90549|测完了|synced|2026-05-19T19:07:56Z
sync_changes=0
privateDatabase|372|2026-05-19T19:17:43Z
```

That proves iOS-to-macOS data flow through CloudKit foreground fetch at the SQLite level.

A macOS diagnostic block was then inserted locally and uploaded. This was also
captured before the `editor-cloudkit-v2` generation bump:

```text
block-mac-sync-20260519190942|mac-to-ios-sync-20260519190942|synced|2026-05-19T19:09:55Z
sync_changes=0
sync_records=block|block-mac-sync-20260519190942|editor-cloudkit-v1.block.block-mac-sync-20260519190942|p
```

After a normal iOS app launch, the copied iOS database contained the macOS-origin block:

```text
block-mac-sync-20260519190942|mac-to-ios-sync-20260519190942|local|2026-05-19T19:11:16.995Z
sync_changes_for_block=1
```

This proves the record reached the iOS device database, but it is not a clean macOS-to-iOS completion proof because the normal UI launch also created local dirty state. The next verification should use the new headless diagnostic mode after unlocking the device.

The copied iOS database after that normal UI launch had 10 pending changes and merged text in visible blocks, so that run is being treated as a UI/editing-side dirty-state observation rather than authoritative sync proof:

```text
pending=10
block-welcome-001|开始用块写作。测完了对，这截图基本能定位到两类问题了...
block-mac-sync-20260519190942|mac-to-ios-sync-20260519190942|local
```

Follow-up repository hardening added focused tests for no-op writes:

```text
PageRepositoryTests.testUpdateBlockTextWithSameContentDoesNotMarkBlockDirty
PageRepositoryTests.testUpdatePageTitleWithSameTitleDoesNotQueueSyncChange
```

Persistent runtime diagnostics were added because the physical iPhone can block
headless launch when locked and console log capture is not reliable enough for
APNs/background-sync proof. Migration version 11 now creates
`runtime_diagnostics`, and the app records:

```text
remote_notification_registration_succeeded
remote_notification_registration_failed
remote_notification_sync_completed
remote_notification_environment_failed
cloudkit_sync_diagnostic_completed
cloudkit_sync_diagnostic_failed
```

After the next unlocked iOS run, copy or inspect the app SQLite database and
check:

```sql
SELECT event_name, payload_json, created_at
FROM runtime_diagnostics
ORDER BY created_at DESC
LIMIT 20;
```

The one-command path for the next unlocked-device verification is:

```bash
scripts/ios_headless_sync.sh
```

Because historical iOS local data is disposable for this rollout, use
`RESET_IOS_APP=1` when the device still has stale pre-schema-11 data:

```bash
RESET_IOS_APP=1 scripts/ios_headless_sync.sh
```

To force a new iOS-origin edit during that headless run:

```bash
APPEND_TEXT="ios-headless-$(date -u +%Y%m%d%H%M%S)" \
  EXPECT_TEXT="mac-origin-for-ios-pull-20260519220958" \
  PAGE_ID=page-welcome \
  scripts/ios_headless_sync.sh
```

The script rebuilds and installs `EditorIOS` with
`-allowProvisioningUpdates -allowProvisioningDeviceRegistration`, launches the
headless diagnostic, then runs `scripts/ios_sync_readback.sh` so the DB
evidence is captured even if the launch is blocked by device lock state.
Set `LAUNCH_ATTEMPTS` and `LAUNCH_RETRY_DELAY` when the iPhone may still be
locked. For fast retry after the app is already installed, set
`BUILD_IOS_APP=0 INSTALL_IOS_APP=0`; pass `APP_PATH=...` when installing a
specific prebuilt bundle. The script retries locked launches and treats SQLite
readback of `cloudkit_sync_diagnostic_completed` plus the expected appended text
as the authoritative success signal, because `devicectl --console --timeout`
can exit non-zero even when the app stayed running after the diagnostic
completed.
Set `EXPECT_TEXT` to require a specific block text to exist in the copied iOS
SQLite database. This is the preferred gate for proving a macOS-origin block was
fetched by the iOS app after automatic foreground sync.

The macOS equivalent is:

```bash
APPEND_TEXT="mac-headless-$(date -u +%Y%m%d%H%M%S)" \
  PAGE_ID=page-welcome \
  scripts/macos_headless_sync.sh
```

The macOS script builds `EditorMac`, terminates existing `EditorMac`
processes to avoid mixed CloudKit logs, launches the same debug diagnostic
view, polls `runtime_diagnostics` for the new completion row, then prints
SQLite summaries for `sync_changes`, `sync_records`, server change tokens, and
the appended block.
Set `EXPECT_TEXT` to require a specific block text to exist in the macOS SQLite
database. This is the preferred gate for proving an iOS-origin block was fetched
by the macOS app.

The one-command cross-device verifier is:

```bash
scripts/cloudkit_cross_device_sync.sh
```

It runs three gates in order:

1. macOS appends and uploads a `mac-cross-device-*` block.
2. iOS fetches that macOS-origin block via `EXPECT_TEXT`, appends and uploads an
   `ios-cross-device-*` block.
3. macOS fetches that iOS-origin block via `EXPECT_TEXT`.

After the iOS step succeeds, the verifier copies
`$DEST_DIR/ios-sync/readback` into `/tmp/editor-ios-headless-sync/readback` by
default so the completion audit can read the same iOS SQLite evidence. Override
`AUDIT_IOS_READBACK_DIR` when running against a custom audit location.
The verifier also writes `mac-origin-text.txt` and `ios-origin-text.txt`; the
completion audit reads those files from `/tmp/editor-cloudkit-cross-device-sync`
by default and uses them as `MAC_EXPECT_TEXT` / `IOS_EXPECT_TEXT` only after the
verifier writes `completed.ok`, so a failed or interrupted run does not become
the next audit's expected state. Without explicit expected text or completed
cross-device state, the audit skips text-specific cross-device assertions
instead of relying on a stale historical seed.

For a fast retry after the latest iOS app is already installed, use:

```bash
BUILD_IOS_APP=0 \
  INSTALL_IOS_APP=0 \
  RESET_IOS_APP=0 \
  LAUNCH_ATTEMPTS=2 \
  scripts/cloudkit_cross_device_sync.sh
```

To leave the verifier waiting for the physical iPhone to be unlocked and then
run the cross-device verifier automatically, use:

```bash
BUILD_IOS_APP=0 \
  INSTALL_IOS_APP=0 \
  RESET_IOS_APP=0 \
  WAIT_TIMEOUT_SECONDS=600 \
  WAIT_INTERVAL_SECONDS=10 \
  scripts/wait_for_ios_unlock_and_run_cross_device_sync.sh
```

The wait script repeatedly runs a lightweight iOS headless diagnostic. It
retries only lock-screen launch failures, stops on non-lock failures, and runs
`scripts/cloudkit_cross_device_sync.sh` only after the iOS diagnostic can launch
and record completion.

The APNs registration verifier is:

```bash
BUILD_IOS_APP=0 \
  INSTALL_IOS_APP=0 \
  scripts/ios_apns_registration_probe.sh
```

It launches the normal iOS app without any headless diagnostic environment and
then requires `runtime_diagnostics` to contain
`remote_notification_registration_succeeded` by default. Override
`EXPECT_DIAGNOSTIC=remote_notification_registration_failed` when intentionally
checking the failure path.
When the probe succeeds, it publishes its SQLite readback to
`/tmp/editor-ios-apns-registration-probe/readback` by default, and the
completion audit uses that separate readback for APNs registration evidence.
Override `AUDIT_IOS_APNS_READBACK_DIR` when using a custom audit location.

The final physical-device gate is:

```bash
scripts/cloudkit_final_device_sync_gate.sh
```

It combines the three required device-side checks into one run:

1. Wait for the paired iPhone to unlock, then run the cross-device verifier.
2. Run a normal iOS app launch and require APNs registration diagnostics.
3. Run the completion audit against the published cross-device and APNs SQLite
   readbacks.

For a fast retry after the latest iOS app is already installed, use:

```bash
BUILD_MAC_APP=0 \
  BUILD_IOS_APP=0 \
  INSTALL_IOS_APP=0 \
  RESET_IOS_APP=0 \
  APNS_BUILD_IOS_APP=0 \
  APNS_INSTALL_IOS_APP=0 \
  APNS_RESET_IOS_APP=0 \
  scripts/cloudkit_final_device_sync_gate.sh
```

The script writes artifacts under `/tmp/editor-cloudkit-final-device-sync` by
default. It is expected to fail while the physical iPhone is locked because no
fresh iOS SQLite readback can be produced.

The non-mutating completion audit is:

```bash
scripts/cloudkit_sync_completion_audit.sh
```

It reads current source files, CloudKit schema through `cktool export-schema`,
the latest signed macOS/iOS app product entitlements, local macOS SQLite state,
and the latest iOS readback directory. Development schema is a hard gate by
default. Production schema is reported as `WARN` by default because it is only
required for Release/TestFlight; set `REQUIRE_PRODUCTION_SCHEMA=1` to make
Production record-type and field drift a hard release gate. Set
`CHECK_SIGNED_PRODUCTS=0` only when intentionally running a source-only audit.
The audit exits non-zero while required proof is missing, which is expected
until the physical iPhone gates below have passed.
If the required APNs registration diagnostic is missing but the iOS readback has
a `remote_notification_registration_succeeded` or
`remote_notification_registration_failed` row, the audit prints that latest
diagnostic payload in the failure line so APNs permission/signing failures are
actionable after the first unlocked-device run.

Apple's text-based schema workflow documents `cktool` as the tool for exporting,
verifying, and installing schema in the sandbox/development environment, while
Production promotion is handled by the CloudKit dashboard/console:

- https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow
- https://developer.apple.com/documentation/cloudkit/managing-icloud-containers-with-cloudkit-database-app

For iOS runtime checks that do not require APNs or a physical device, a
booted Simulator can run the same diagnostic:

```bash
APPEND_TEXT="ios-sim-headless-$(date -u +%Y%m%d%H%M%S)" \
  PAGE_ID=page-welcome \
  ALLOW_DIAGNOSTIC_FAILURE=1 \
  scripts/ios_simulator_headless_sync.sh
```

The Simulator path is not a substitute for the paired iPhone APNs/silent-push
gate. It is useful for proving the iOS app launches, writes the local SQLite
store, records CloudKit errors, and preserves pending local changes when the
Simulator has no authenticated iCloud account.

The simulator can also exercise the remote-notification sync handler directly
without relying on APNs delivery:

```bash
ALLOW_FAILED_RESULT=1 scripts/ios_simulator_remote_notification_sync.sh
```

This launches the app with `EDITOR_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC=1`,
invokes the same `AppEnvironment.handleRemoteNotificationSync()` path used by
`UIApplicationDelegate.didReceiveRemoteNotification`, and polls SQLite for
`remote_notification_sync_completed` or `remote_notification_environment_failed`.
It is a handler-path diagnostic, not proof that APNs woke the app.

There is also a lower-level `simctl push` probe:

```bash
scripts/ios_simulator_silent_push.sh
```

In the current Simulator, `simctl push` reports that the notification was sent,
but it has not produced a `remote_notification_sync_completed` row. Keep this as
a diagnostic for Simulator delivery behavior; do not count it as the silent-push
completion gate.

Current blocked iOS command:

```bash
xcrun devicectl device process --timeout 28 launch \
  --device 70629899-4D65-52F9-9040-03C1FD0C697D \
  --terminate-existing \
  --environment-variables '{"EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC":"1","OS_ACTIVITY_DT_MODE":"1","OS_ACTIVITY_MODE":"enable"}' \
  --console com.liangzhang.editor.ios
```

Observed blocker:

```text
RequestDenied / Locked: Unable to launch com.liangzhang.editor.ios because the device was not, or could not be, unlocked.
```

Before resetting iOS app data, the iOS DB readback while the device was still
locked showed why the old container could not count as a clean iOS
verification:

```text
schema_version|10
sync_changes|10
server_change_tokens|1
runtime_diagnostics table is missing; launch the latest app once to migrate the store to schema 11.
```

After running `RESET_IOS_APP=1 scripts/ios_headless_sync.sh`, the stale iOS app
data was removed and the latest app was installed. Since the device was still
locked, the app could not launch and no fresh `editor.sqlite` existed yet:

```text
App uninstalled.
App installed:
installationURL: file:///private/var/containers/Bundle/Application/84800C89-1204-4162-A40C-E583E3E27167/EditorIOS.app/
RequestDenied / Locked
No iOS editor database was copied. The latest app may be installed but not launched yet.
```

The latest macOS headless diagnostic with the Debug app migrated the macOS DB
to schema 11 and persisted the diagnostic result:

```text
schema_version|11
sync_changes|0
runtime_diagnostics|1
cloudkit_sync_diagnostic_completed|{"appended_block_id":"nil","failed_upload_count":0,"fetched_count":0,"pending_change_count":0,"uploaded_count":0}
```

A later `editor-cloudkit-v2` macOS headless diagnostic appended a local block
and uploaded it through CloudKit. The diagnostic app process was stopped by the
outer timeout after verification, but the SQLite state and CloudKit operations
completed before that timeout:

```text
append_text|mac-headless-20260519204036
schema|11
changes|0
records|1
block-d56a7311-7e0f-4835-bb45-d69756024487|mac-headless-20260519204036|synced|2026-05-19T20:41:02Z
block|block-d56a7311-7e0f-4835-bb45-d69756024487|editor-cloudkit-v2.block.block-d56a7311-7e0f-4835-bb45-d69756024487|10
cloudkit_sync_diagnostic_completed|{"appended_block_id":"block-d56a7311-7e0f-4835-bb45-d69756024487","failed_upload_count":0,"fetched_count":1,"pending_change_count":0,"uploaded_count":1}|2026-05-19T20:41:02Z
```

CloudKit log evidence for that same run:

```text
Finished CKModifyRecordsOperation operationID=EF5FF035CEA79F9B container=iCloud.com.liangzhang.editor.sync databaseScope=Private
Finished CKFetchRecordZoneChangesOperation operationID=99F53C6F9F9DD188 container=iCloud.com.liangzhang.editor.sync databaseScope=Private
```

After adding `scripts/macos_headless_sync.sh`, a clean scripted macOS
diagnostic run appended another block and used SQLite runtime diagnostics as
the completion gate:

```text
cloudkit_sync_diagnostic_completed|{"appended_block_id":"block-650eec0e-c3c4-4281-b808-3b4a942d5a38","failed_upload_count":0,"fetched_count":3,"pending_change_count":0,"uploaded_count":1}|2026-05-19T21:10:48Z
schema_version|11
sync_changes|0
sync_records|1
server_change_tokens|1
block-650eec0e-c3c4-4281-b808-3b4a942d5a38|mac-headless-clean-20260519211029|synced|2026-05-19T21:10:48Z
block|block-650eec0e-c3c4-4281-b808-3b4a942d5a38|editor-cloudkit-v2.block.block-650eec0e-c3c4-4281-b808-3b4a942d5a38|12
```

A first iOS Simulator diagnostic run exposed a local instrumentation race:
`remote_notification_registration_succeeded` tried to write
`runtime_diagnostics` while the headless sync diagnostic was also using the
SQLite database, producing `database is locked`. The fix was to skip APNs
registration while `EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC=1` is present. A follow-up
Simulator run then cleanly proved the offline path with no iCloud account:

```text
cloudkit_sync_diagnostic_failed|{"error":"<CKError ... \"Not Authenticated\" (9/1002); \"This request requires an authenticated account\">"}|2026-05-19T21:20:37Z
schema_version|11
sync_changes|1
sync_records|0
server_change_tokens|0
runtime_diagnostics|1
blocks|2
block-99b8dd39-ab55-4672-a425-220ea3bcc0c9|ios-sim-headless-fixed-20260519212017|local|2026-05-19T21:20:36.957Z
block|block-99b8dd39-ab55-4672-a425-220ea3bcc0c9|create|0||
```

This is expected for the current Simulator because it is not signed into
iCloud. The useful proof is that the iOS app launches, creates local data,
records the CloudKit authentication failure, and leaves the local change queued
for a future retry instead of losing the edit.

## Latest Local Verification

- `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/LocalSyncGenerationResetPolicyTests -only-testing:EditorTests/SyncEngineTests -only-testing:EditorTests/SyncRepositoryTests -only-testing:EditorTests/SchemaMigratorTests -only-testing:EditorTests/PlatformSecurityTests -quiet` passed after the `editor-cloudkit-v2` bump.
- A follow-up full `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -resultBundlePath /tmp/editor-full-tests.xcresult -quiet` was attempted, but was interrupted after 271.970 seconds while Xcode was blocked cleaning up a test session (`XCTHTestOperationCoordinator processing delay` / waiting for `runningDidFinish`). No business assertion failure was printed before interruption.
- `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/LocalSyncGenerationResetPolicyTests -only-testing:EditorTests/SyncEngineTests/testCloudKitPrivateDatabaseAdapterIgnoresRecordsFromPreviousSyncGeneration -only-testing:EditorTests/SyncEngineTests/testCloudKitPrivateDatabaseAdapterMapsDeletedRecordIDsToDeletionChanges -only-testing:EditorTests/SyncEngineTests/testCloudKitPrivateDatabaseAdapterMapsBlockChangeToRecord -only-testing:EditorTests/SyncEngineTests/testCloudKitPrivateDatabaseAdapterMapsNotebookChangeToRecord -only-testing:EditorTests/SyncEngineTests/testCloudKitPrivateDatabaseAdapterDeletesRecordForDeleteChange` passed after the `editor-cloudkit-v2` bump: 8 tests, 0 failures.
- `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/SyncEngineTests -only-testing:EditorTests/SyncMergeEngineTests` passed: 49 tests, 0 failures.
- `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/PlatformSecurityTests/testCloudKitSyncDiagnosticRequestParsesHeadlessLaunchEnvironment` passed.
- `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/PlatformSecurityTests -only-testing:EditorTests/SyncEngineTests -only-testing:EditorTests/SyncMergeEngineTests` passed: 65 tests, 0 failures.
- `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/PageRepositoryTests` passed: 45 tests, 0 failures.
- `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/SchemaMigratorTests/testRuntimeDiagnosticsTableCapturesObservableSyncEvents -only-testing:EditorTests/SyncRepositoryTests/testRuntimeDiagnosticsPersistRecentEventsNewestFirst -only-testing:EditorTests/PlatformSecurityTests/testIOSAppDelegatePersistsRemoteNotificationRegistrationDiagnostics` passed: 3 tests, 0 failures.
- `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/SchemaMigratorTests -only-testing:EditorTests/SyncRepositoryTests -only-testing:EditorTests/PlatformSecurityTests -only-testing:EditorTests/SyncEngineTests` passed: 77 tests, 0 failures.
- `xcodebuild test -scheme EditorTests -destination 'platform=macOS'` passed: 467 tests, 0 failures.
- `xcodebuild build -scheme EditorMac -configuration Debug -destination 'platform=macOS' -allowProvisioningUpdates` initially failed because the selected Mac was not included in the provisioning profile. Re-running with `-allowProvisioningDeviceRegistration` registered/refreshed the profile and passed.
- `xcodebuild build -scheme EditorIOS -configuration Debug -destination 'generic/platform=iOS' -allowProvisioningUpdates -allowProvisioningDeviceRegistration` passed after the `editor-cloudkit-v2` bump, with the existing interface-orientation warning.
- The rebuilt signed macOS app entitlement readback shows `com.apple.developer.icloud-container-identifiers = iCloud.com.liangzhang.editor.sync`, `com.apple.developer.icloud-services = CloudKit`, `com.apple.security.app-sandbox = true`, and `com.apple.security.network.client = true`.
- The rebuilt signed iOS app entitlement readback shows `aps-environment = development`, `com.apple.developer.icloud-container-identifiers = iCloud.com.liangzhang.editor.sync`, and `com.apple.developer.icloud-services = CloudKit`; its `Info.plist` still includes `UIBackgroundModes = remote-notification`.
- The rebuilt macOS headless diagnostic wrote `.sync-generation = editor-cloudkit-v2`, migrated the local DB to schema 11, left `sync_changes=0`, and recorded `cloudkit_sync_diagnostic_completed` with zero pending/upload/fetch failures.
- A later `editor-cloudkit-v2` macOS headless diagnostic appended `mac-headless-20260519204036`, uploaded one pending change, fetched one remote change, left `sync_changes=0`, and stored `editor-cloudkit-v2.block.block-d56a7311-7e0f-4835-bb45-d69756024487` in `sync_records`; `log show` captured matching `CKModifyRecordsOperation` and `CKFetchRecordZoneChangesOperation` operations against `iCloud.com.liangzhang.editor.sync`.
- The rebuilt macOS minimal CloudKit probe completed `CKModifyRecordsOperation` save, `CKFetchRecordsOperation` fetch, and `CKModifyRecordsOperation` delete against `iCloud.com.liangzhang.editor.sync`; an error-only log query for the same window returned no `CKHTTPStatus`, `CKInternalErrorDomain`, `serverRejectedRequest`, or `failed` messages.
- `git diff --check` passed.
- `scripts/ios_sync_readback.sh` succeeded before the iOS data reset while the device was locked and showed iOS `schema_version=10`, `sync_changes=10`, and no `runtime_diagnostics` table yet.
- `codesign -d --entitlements :- .../Debug/EditorMac.app | plutil -p -` shows `com.apple.security.app-sandbox = true`, `com.apple.security.network.client = true`, `com.apple.developer.icloud-container-environment = Development`, and `iCloud.com.liangzhang.editor.sync`.
- `codesign -d --entitlements :- .../Debug-iphoneos/EditorIOS.app | plutil -p -` shows `aps-environment = development`, `com.apple.developer.icloud-container-environment = Development`, and `iCloud.com.liangzhang.editor.sync`.
- `xcrun cktool export-schema --team-id H52N5N7WQ7 --container-id iCloud.com.liangzhang.editor.sync --environment development` succeeded with the management token and showed the expected `AttachmentRecord`, `BlockRecord`, `EditorRuntimeProbeRecord`, `NotebookRecord`, `PageRecord`, and `WorkspaceRecord` types.
- `xcrun cktool validate-schema --team-id H52N5N7WQ7 --container-id iCloud.com.liangzhang.editor.sync --environment development --file docs/cloudkit/editor-cloudkit-schema.ckdb` returned `Schema is valid`.
- `xcrun devicectl device install app --device 70629899-4D65-52F9-9040-03C1FD0C697D .../Debug-iphoneos/EditorIOS.app` installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/6588DFBC-4D5F-4962-B066-9CCF228E1830/EditorIOS.app/`.
- After the no-op dirty-state guard, the latest `xcrun devicectl device install app --device 70629899-4D65-52F9-9040-03C1FD0C697D .../Debug-iphoneos/EditorIOS.app` installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/C082F73C-4BA8-40F7-AB28-5D1390626811/EditorIOS.app/`.
- After adding persistent runtime diagnostics, the latest `xcrun devicectl device install app --device 70629899-4D65-52F9-9040-03C1FD0C697D .../Debug-iphoneos/EditorIOS.app` installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/F900FC17-15F2-4979-AA01-F813915DA601/EditorIOS.app/`.
- `scripts/ios_headless_sync.sh` built and installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/318B1C48-0C6A-48CF-9DCB-534AF67D097E/EditorIOS.app/`, then captured DB readback after the launch was blocked by lock state.
- `RESET_IOS_APP=1 scripts/ios_headless_sync.sh` uninstalled the old iOS app data, rebuilt and installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/84800C89-1204-4162-A40C-E583E3E27167/EditorIOS.app/`, then showed launch still blocked by lock state and no fresh `editor.sqlite` yet.
- After the `editor-cloudkit-v2` bump, `RESET_IOS_APP=1 scripts/ios_headless_sync.sh` rebuilt and installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/6999C494-91F1-484A-9456-B4268A33A179/EditorIOS.app/`, but the headless diagnostic launch was still blocked by the physical iPhone lock screen and no fresh `editor.sqlite` existed yet.
- A later `APPEND_TEXT="ios-headless-..." PAGE_ID=page-welcome scripts/ios_headless_sync.sh` rebuilt and installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/2A87FC7A-F43B-4EE5-89B1-EFFB0E9557FC/EditorIOS.app/`, but the diagnostic launch was again blocked by `RequestDenied / Locked`, so the iOS-origin upload proof is still pending device unlock.
- A fresh `APPEND_TEXT="ios-headless-..." PAGE_ID=page-welcome RESET_IOS_APP=1 scripts/ios_headless_sync.sh` run rebuilt and installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/90DB6CA6-3C28-44B5-83C8-7B2D1940BBEE/EditorIOS.app/`, but SpringBoard again rejected launch with `RequestDenied / Locked`; readback found no fresh `editor.sqlite`.
- After adding locked-launch retry support, `APPEND_TEXT="ios-headless-..." PAGE_ID=page-welcome RESET_IOS_APP=1 LAUNCH_ATTEMPTS=2 LAUNCH_RETRY_DELAY=5 scripts/ios_headless_sync.sh` rebuilt and installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/2EA09061-4447-45CD-9EC2-B7A909F5EE68/EditorIOS.app/`. Both launch attempts were rejected with `RequestDenied / Locked`, and DB readback still failed because the latest app has not launched yet.
- A direct no-rebuild launch retry against the installed fresh app used `APPEND_TEXT=ios-headless-direct-20260519205221` and attempted `devicectl` launch 6 times. Every attempt returned `RequestDenied / Locked`; `scripts/ios_sync_readback.sh` then reported no fresh `editor.sqlite`.
- A later `APPEND_TEXT="ios-headless-..." PAGE_ID=page-welcome RESET_IOS_APP=0 LAUNCH_ATTEMPTS=8 LAUNCH_RETRY_DELAY=5 scripts/ios_headless_sync.sh` rebuilt and installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/CF5B9A33-2881-43D5-AB80-F8613054B504/EditorIOS.app/`. All 8 launch attempts returned `RequestDenied / Locked`; DB readback still found no fresh `editor.sqlite`.
- After adding the headless-diagnostic APNs registration skip, `APPEND_TEXT="ios-headless-..." PAGE_ID=page-welcome RESET_IOS_APP=0 LAUNCH_ATTEMPTS=8 LAUNCH_RETRY_DELAY=5 scripts/ios_headless_sync.sh` rebuilt and installed `com.liangzhang.editor.ios` to `file:///private/var/containers/Bundle/Application/EA55FDF4-EF41-4D15-BC94-463263AD6E17/EditorIOS.app/`. All 8 launch attempts were rejected by SpringBoard with `RequestDenied / Locked`; `xcrun devicectl device info lockState` reported `passcodeRequired: true` and `unlockedSinceBoot: true`, and readback still found no fresh `editor.sqlite` because the latest app has not launched yet.
- `APPEND_TEXT="ios-fast-retry-..." PAGE_ID=page-welcome BUILD_IOS_APP=0 INSTALL_IOS_APP=0 LAUNCH_ATTEMPTS=1 scripts/ios_headless_sync.sh` exercised the fast retry path without rebuilding or reinstalling. It printed `== Skip iOS build ==` and `== Skip iOS install ==`, then the launch was still rejected with `RequestDenied / Locked`; DB readback again found no fresh `editor.sqlite`.
- A later `APPEND_TEXT="ios-fast-retry-..." PAGE_ID=page-welcome BUILD_IOS_APP=0 INSTALL_IOS_APP=0 LAUNCH_ATTEMPTS=2 LAUNCH_RETRY_DELAY=5 scripts/ios_headless_sync.sh` retried the same installed app twice. Both attempts were rejected with `RequestDenied / Locked`; `xcrun devicectl device info lockState` again reported `passcodeRequired: true` and `unlockedSinceBoot: true`, and readback found no fresh `editor.sqlite`.
- `APPEND_TEXT="ios-headless-..." PAGE_ID=page-welcome RESET_IOS_APP=1 LAUNCH_ATTEMPTS=2 LAUNCH_RETRY_DELAY=5 scripts/ios_headless_sync.sh` rebuilt and installed the latest `EditorIOS` to `file:///private/var/containers/Bundle/Application/E211FFAF-15D4-4642-A4AE-63F58E365431/EditorIOS.app/`, then both launch attempts were again rejected by SpringBoard with `RequestDenied / Locked`. Because this run reset app data and the app did not launch, readback found no fresh `editor.sqlite`.
- `APPEND_TEXT="ios-origin-..." EXPECT_TEXT="mac-origin-for-ios-pull-20260519220958" PAGE_ID=page-welcome BUILD_IOS_APP=0 INSTALL_IOS_APP=0 LAUNCH_ATTEMPTS=1 scripts/ios_headless_sync.sh` retried the already-installed app with an automatic macOS-origin readback expectation. The launch was still rejected with `RequestDenied / Locked`, so no iOS SQLite readback was available.
- A later retry with the same already-installed app and the same `EXPECT_TEXT="mac-origin-for-ios-pull-20260519220958"` gate was also rejected by SpringBoard with `RequestDenied / Locked`; readback again failed because no fresh iOS `editor.sqlite` existed.
- Another live retry at `2026-05-20 06:24:55` with the already-installed app and the same `EXPECT_TEXT="mac-origin-for-ios-pull-20260519220958"` gate was again rejected by SpringBoard with `RequestDenied / Locked`; readback again failed because no fresh iOS `editor.sqlite` existed.
- `BUILD_IOS_APP=0 INSTALL_IOS_APP=0 RESET_IOS_APP=0 WAIT_TIMEOUT_SECONDS=1 WAIT_INTERVAL_SECONDS=1 LAUNCH_ATTEMPTS=1 scripts/wait_for_ios_unlock_and_run_cross_device_sync.sh` was run against the currently locked iPhone. It made one lightweight iOS readiness attempt, saw `RequestDenied / Locked`, failed readback because no fresh iOS `editor.sqlite` existed, then timed out without running the cross-device verifier.
- `BUILD_IOS_APP=0 INSTALL_IOS_APP=0 LAUNCH_TIMEOUT_SECONDS=20 scripts/ios_apns_registration_probe.sh` was run against the currently locked iPhone. The normal app launch was also rejected with `RequestDenied / Locked`, so no APNs registration diagnostic could be read back yet.
- `scripts/cloudkit_sync_completion_audit.sh` was run against current local state. It passed explicit-container, source-entitlement, iOS background-mode, script-existence, macOS `sync_changes=0`, and macOS seed-text gates, but failed `ios_readback_database` because `/tmp/editor-ios-headless-sync/readback/editor.sqlite` does not exist while the latest iOS app has not launched.
- `APPEND_TEXT="mac-headless-script-..." PAGE_ID=page-welcome RUN_TIMEOUT_SECONDS=120 scripts/macos_headless_sync.sh` built `EditorMac`, appended `mac-headless-script-20260519210909`, uploaded one change, fetched two remote changes, left `sync_changes=0`, and stored `editor-cloudkit-v2.block.block-d7a86ea9-711a-4376-8b13-357d94246416`.
- `APPEND_TEXT="mac-headless-clean-..." PAGE_ID=page-welcome BUILD_MAC_APP=0 RUN_TIMEOUT_SECONDS=120 scripts/macos_headless_sync.sh` terminated existing `EditorMac` processes first, appended `mac-headless-clean-20260519211029`, uploaded one change, fetched three remote changes, left `sync_changes=0`, and stored `editor-cloudkit-v2.block.block-650eec0e-c3c4-4281-b808-3b4a942d5a38`.
- `APPEND_TEXT="mac-origin-for-ios-pull-..." PAGE_ID=page-welcome RUN_TIMEOUT_SECONDS=120 scripts/macos_headless_sync.sh` built `EditorMac`, appended `mac-origin-for-ios-pull-20260519220958`, recorded `cloudkit_sync_diagnostic_completed|{"appended_block_id":"block-c5cd7765-96e2-49f1-912d-c1fad87e441c","failed_upload_count":0,"fetched_count":2,"pending_change_count":0,"uploaded_count":2}`, left `sync_changes=0`, and stored `editor-cloudkit-v2.block.block-c5cd7765-96e2-49f1-912d-c1fad87e441c`. This block is the current explicit macOS-origin target for the next unlocked iOS pull proof.
- `APPEND_TEXT="ios-sim-headless-fixed-..." PAGE_ID=page-welcome ALLOW_DIAGNOSTIC_FAILURE=1 scripts/ios_simulator_headless_sync.sh` built and installed `EditorIOS` on the booted iPhone 17 Pro Max Simulator, appended `ios-sim-headless-fixed-20260519212017`, recorded `cloudkit_sync_diagnostic_failed` with `CKError Not Authenticated`, left `sync_changes=1`, and preserved the appended block locally. A targeted source test for `RemoteNotificationRegistrationPolicy` first failed before the policy accepted `environment`, then passed after APNs registration was skipped for headless diagnostics.
- `arch -x86_64 xcrun xctest -XCTest SyncEngineTests/testLocalBlockEditRemainsReadableAndPendingWhenCloudKitUploadFails,SyncEngineTests/testUploadFailureRecordsRetryStateAndContinuesWithLaterChanges,SyncEngineTests/testUploadPendingChangesPersistsSyncRecordAndClearsChange .../EditorTests.xctest` passed: 3 tests, 0 failures. This covers the offline-first invariant that a local block edit remains readable and pending when CloudKit upload fails. The explicit `arch -x86_64` is needed for the current built test bundle.
- A later `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/PlatformSecurityTests -only-testing:EditorTests/SchemaMigratorTests -only-testing:EditorTests/SyncRepositoryTests -only-testing:EditorTests/SyncEngineTests -quiet` selected the `arm64` My Mac destination but hung in the Xcode test wrapper with no output for several minutes, so the wrapper and child `xctest` process were terminated.
- The newly built `arm64` test bundle was then run directly with `xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests .../EditorTests.xctest`; it passed: 78 tests, 0 failures.
- After adding the headless-diagnostic APNs registration skip, `xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests .../EditorTests.xctest` passed: 79 tests, 0 failures.
- A matching `xcodebuild test ... -only-testing:EditorTests/SyncEngineTests/testLocalBlockEditRemainsReadableAndPendingWhenCloudKitUploadFails ...` attempt built the test bundle, but the `xcodebuild` wrapper was interrupted by timeout before producing a valid result bundle; running the built test bundle directly with `xcrun xctest` passed.
- `xcrun xctest -XCTest SyncEngineTests/testRetryAfterBackoffUploadsAndClearsQueuedChange .../EditorTests.xctest` passed: 1 test, 0 failures. This covers the recovery path where a queued offline change waits through its retry backoff, uploads successfully on a later pass, clears `sync_changes`, and writes the matching `sync_records` row. The matching `xcodebuild test ... -only-testing:EditorTests/SyncEngineTests/testRetryAfterBackoffUploadsAndClearsQueuedChange -quiet` wrapper was interrupted after it hung with a child `xctest` process, then the same built bundle passed directly.
- `xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests .../EditorTests.xctest` passed after the retry recovery test was added: 80 tests, 0 failures.
- `xcrun xctest -XCTest SyncEngineTests/testRemoteNotificationSyncHandlerStillFetchesWhenLocalUploadFails .../EditorTests.xctest` first failed because the handler returned `.failed` after `uploadPendingChanges()` reported one failed upload and never called `fetchRemoteChanges()`. After the handler change, the same test passed and verified the handler returned `.newData` when the remote fetch applied two changes.
- `xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests .../EditorTests.xctest` passed after the remote-notification handler change: 81 tests, 0 failures.
- `xcodebuild build-for-testing -scheme EditorTests -destination 'platform=macOS,arch=arm64' -quiet` first failed after adding `testRemoteNotificationSyncDiagnosticRequestParsesHeadlessLaunchEnvironment`, because `RemoteNotificationSyncDiagnosticRequest` did not exist yet. After adding the DEBUG request type and skipping APNs registration during this diagnostic mode, `xcrun xctest -XCTest PlatformSecurityTests/testRemoteNotificationSyncDiagnosticRequestParsesHeadlessLaunchEnvironment,SyncEngineTests/testRemoteNotificationRegistrationPolicySkipsDuringRemoteNotificationSyncDiagnostic .../EditorTests.xctest` passed: 2 tests, 0 failures.
- `ALLOW_FAILED_RESULT=1 RUN_TIMEOUT_SECONDS=120 scripts/ios_simulator_silent_push.sh` built and installed the iOS Simulator app, and `xcrun simctl push` reported `Notification sent to 'com.liangzhang.editor.ios'`, but no `remote_notification_sync_completed` or `remote_notification_environment_failed` row appeared before timeout and no fresh database was created. Manual follow-ups showed the app records `remote_notification_registration_succeeded` after launch, but simulated pushes still did not trigger `didReceiveRemoteNotification` diagnostics.
- `ALLOW_FAILED_RESULT=1 RUN_TIMEOUT_SECONDS=120 scripts/ios_simulator_remote_notification_sync.sh` built and installed the iOS Simulator app, launched with `EDITOR_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC=1`, and recorded `remote_notification_sync_completed|{"result":"failed"}` in SQLite. The result is expected on the current Simulator because CloudKit is not authenticated; the useful proof is that the iOS runtime can invoke the same remote-notification sync handler path and persist its outcome without an APNs delivery.
- `xcodebuild build-for-testing -scheme EditorTests -destination 'platform=macOS,arch=arm64' -quiet` first failed after adding `testRemoteNotificationSyncHandlerReportIncludesUploadAndFetchCounts`, because `RemoteNotificationSyncHandler` did not yet expose `handleRemoteNotificationReport()`. After adding the report API and persistent payload, `xcrun xctest -XCTest SyncEngineTests/testRemoteNotificationSyncHandlerReportIncludesUploadAndFetchCounts .../EditorTests.xctest` passed: 1 test, 0 failures.
- `ALLOW_FAILED_RESULT=1 RUN_TIMEOUT_SECONDS=120 scripts/ios_simulator_remote_notification_sync.sh` was rerun after the report payload change. It built and installed the iOS Simulator app, launched with `EDITOR_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC=1`, and recorded `remote_notification_sync_completed|{"error":"<CKError ... \"Not Authenticated\" (9/1002); \"This request requires an authenticated account\">","failed_upload_count":0,"fetched_count":0,"result":"failed","uploaded_count":0}` in SQLite. This is still expected for the unsigned-in Simulator, but now the handler-path diagnostic is granular enough to prove which stage failed.
- `xcodebuild build-for-testing -scheme EditorTests -destination 'platform=macOS,arch=arm64' -quiet && xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests .../EditorTests.xctest` passed after the remote-notification report change: 84 tests, 0 failures.
- The same `xcodebuild build-for-testing ... && xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests .../EditorTests.xctest` command was rerun after the latest locked-device attempt and macOS-origin seed record: 84 tests, 0 failures.
- The same `xcodebuild build-for-testing ... && xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests .../EditorTests.xctest` command was rerun after adding the wait-for-unlock wrapper: 84 tests, 0 failures.
- The same `xcodebuild build-for-testing ... && xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests .../EditorTests.xctest` command was rerun after adding `EXPECT_DIAGNOSTIC` and the APNs registration probe: 84 tests, 0 failures.
- `scripts/ios_sync_readback.sh` now supports `EXPECT_TEXT`. A fake-device SQLite harness verified the negative path fails when `EXPECT_TEXT=missing-text` and the positive path passes when `EXPECT_TEXT=present-text`.
- `scripts/ios_sync_readback.sh` now supports `EXPECT_DIAGNOSTIC`. A fake-device SQLite harness verified the negative path fails when `EXPECT_DIAGNOSTIC=missing_event` and the positive path passes when `EXPECT_DIAGNOSTIC=remote_notification_registration_succeeded`.
- `BUILD_MAC_APP=0 RUN_TIMEOUT_SECONDS=120 EXPECT_TEXT="mac-origin-for-ios-pull-20260519220958" scripts/macos_headless_sync.sh` verified the macOS exact-text gate against the real local database. The diagnostic completed with zero uploads/fetches/pending changes and printed `block-c5cd7765-96e2-49f1-912d-c1fad87e441c|mac-origin-for-ios-pull-20260519220958|synced`.
- `scripts/cloudkit_cross_device_sync.sh` was added as the one-command end-to-end verifier. A TDD fake-child-script harness first failed because the verifier did not exist, then passed after implementation by proving the ordered calls were: macOS append/upload with `mac-e2e-test`, iOS sync with `EXPECT_TEXT=mac-e2e-test` and append `ios-e2e-test`, then macOS sync with `EXPECT_TEXT=ios-e2e-test`.
- `scripts/wait_for_ios_unlock_and_run_cross_device_sync.sh` was added as a wait-and-run wrapper around the end-to-end verifier. A TDD fake-child-script harness first failed because the script did not exist, then passed after implementation by proving a lock-screen launch failure is retried, a later iOS readiness success is accepted, and `scripts/cloudkit_cross_device_sync.sh` runs only after that readiness gate. A follow-up real-device short-timeout run confirmed the locked iPhone path stops before the cross-device step.
- `scripts/ios_apns_registration_probe.sh` was added as the normal-launch APNs registration verifier. A TDD fake-child-script harness first failed because the script did not exist, then passed after implementation by proving the script launches the app without headless environment variables and requires `EXPECT_DIAGNOSTIC=remote_notification_registration_succeeded` in SQLite readback.
- `scripts/cloudkit_sync_completion_audit.sh` was added as a read-only completion gate audit. A fake-data harness verified the success path with macOS/iOS SQLite evidence and the failure path when iOS readback is missing.
- `scripts/cloudkit_cross_device_sync.sh` now publishes a successful iOS readback into `/tmp/editor-ios-headless-sync/readback` for the completion audit. A TDD fake-child-script harness first failed because the cross-device verifier left `editor.sqlite` only under its own `DEST_DIR/ios-sync/readback`, then passed after the verifier copied that directory to `AUDIT_IOS_READBACK_DIR` and printed the published path.
- The completion audit now separates sync proof from APNs proof. It checks the iOS sync readback for the macOS-origin block, checks the macOS DB for the iOS-origin block, and checks `IOS_APNS_READBACK_DIR` for `remote_notification_registration_succeeded`. TDD harnesses first failed because APNs success in a separate readback was ignored and because an iOS-origin block missing on macOS was not reported; after the change, the APNs readback passes independently and `FAIL|ios_origin_on_mac` is emitted when the iOS-origin text has not returned to macOS.
- `scripts/ios_apns_registration_probe.sh` now publishes successful APNs readback to `AUDIT_IOS_APNS_READBACK_DIR`. A TDD fake-readback harness first failed because a custom APNs readback was not copied to the audit path, then passed after the probe printed `Published iOS APNs readback for completion audit`.
- A cross-device state harness verified that `scripts/cloudkit_sync_completion_audit.sh` can read `mac-origin-text.txt` and `ios-origin-text.txt` from `CROSS_DEVICE_STATE_DIR` without explicit environment variables, then pass `mac_origin_on_ios` and `ios_origin_on_mac` against fake SQLite evidence. A paired incomplete-state harness first failed because the audit consumed text files from a run that had not completed; after adding `completed.ok`, audit ignores incomplete cross-device state and only adopts expected text from completed runs.
- The completion audit now exports both Development and Production schema with `cktool` and checks `WorkspaceRecord`, `NotebookRecord`, `PageRecord`, `AttachmentRecord`, `BlockRecord`, and `EditorRuntimeProbeRecord`. It also compares each required record type's non-system fields against `docs/cloudkit/editor-cloudkit-schema.ckdb`, so a schema with the right record type name but a missing field is detected. A TDD fake-`cktool` harness first failed because Production schema gaps were not reported, then passed after the audit reported `FAIL|cloudkit_schema:production:BlockRecord` for a fake Production schema missing app record types and passed when both environments contained all required record types.
- A follow-up TDD fake-`cktool` harness first failed because a fake schema missing `BlockRecord.textPlain` was not reported. After adding field-level comparison, the audit reports `FAIL|cloudkit_schema:development:BlockRecord:fields|development schema fields differ from source for BlockRecord missing=1 extra=0`; a full fake source-schema export for both environments passes with `PASS|cloudkit_schema:production:BlockRecord:fields`.
- The Production gate was then split by build intent: default Debug/development audit reports Production drift as `WARN`, while `REQUIRE_PRODUCTION_SCHEMA=1 scripts/cloudkit_sync_completion_audit.sh` treats the same drift as `FAIL` for Release/TestFlight readiness. A fake-`cktool` harness verified both paths: default mode exits successfully with `WARN|cloudkit_schema:production:BlockRecord`, and release mode exits non-zero with `FAIL|cloudkit_schema:production:BlockRecord`.
- `xcrun cktool export-schema --team-id H52N5N7WQ7 --container-id iCloud.com.liangzhang.editor.sync --environment production` succeeded, but the exported Production schema currently contains only `Users`; it is missing every app record type required by the sync runtime. A direct `cktool import-schema --environment production --file /tmp/editor-cloudkit-dev-schema.json` attempt was rejected by CloudKit with `BadRequestException: endpoint not applicable in the environment 'production'`, so Production deployment still needs the supported Apple/CloudKit Console deployment path rather than `cktool import-schema`.
- `BUILD_IOS_APP=0 INSTALL_IOS_APP=0 RESET_IOS_APP=0 WAIT_TIMEOUT_SECONDS=90 WAIT_INTERVAL_SECONDS=5 LAUNCH_ATTEMPTS=1 scripts/wait_for_ios_unlock_and_run_cross_device_sync.sh` retried the already-installed iOS app 6 times. Every launch was rejected by SpringBoard with `RequestDenied / Locked`, each readback failed because no fresh iOS `editor.sqlite` exists, and the wrapper correctly timed out without running the cross-device verifier.
- `APPEND_TEXT="mac-origin-for-ios-pull-20260520065053" PAGE_ID=page-welcome BUILD_MAC_APP=0 RUN_TIMEOUT_SECONDS=120 scripts/macos_headless_sync.sh` migrated the current macOS app container to schema 11, uploaded one new macOS-origin block, fetched six remote changes, left `sync_changes=0`, and read back `block-57f8b753-e3ee-4e42-a57b-4630d08e8370|mac-origin-for-ios-pull-20260520065053|synced`.
- A fresh default `scripts/cloudkit_sync_completion_audit.sh` run after that macOS diagnostic passes explicit-container, source-entitlement, iOS background-mode, Development schema record-type and field gates, macOS `sync_changes=0`, and macOS seed gates. It reports the six missing Production schema record types as warnings unless `REQUIRE_PRODUCTION_SCHEMA=1` is set, and still fails `ios_readback_database`, so the full objective remains open.
- `xcrun devicectl device process launch --device 70629899-4D65-52F9-9040-03C1FD0C697D com.liangzhang.editor.ios` launched the app successfully.
- `xcrun devicectl device info processes --device 70629899-4D65-52F9-9040-03C1FD0C697D` showed the running process at `/private/var/containers/Bundle/Application/6588DFBC-4D5F-4962-B066-9CCF228E1830/EditorIOS.app/EditorIOS`.
- A console launch with `EDITOR_CLOUDKIT_PROBE=1` attached to the iOS app for 25 seconds and showed app/UIKit console output, but did not surface app CloudKit/APNs log lines before the command timed out.
- The latest console launch with `EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC=1` is still blocked by the physical iPhone lock screen: `RequestDenied / Locked`.
- `xcrun cktool export-schema --team-id H52N5N7WQ7 --container-id iCloud.com.liangzhang.editor.sync --environment development --output-file /tmp/editor-current-development.ckdb` succeeded using the existing local cktool authorization. The exported Development schema contains `AttachmentRecord`, `BlockRecord`, `EditorRuntimeProbeRecord`, `NotebookRecord`, `PageRecord`, and `WorkspaceRecord`.
- `xcrun cktool validate-schema --team-id H52N5N7WQ7 --container-id iCloud.com.liangzhang.editor.sync --environment development --file docs/cloudkit/editor-cloudkit-schema.ckdb` returned `Schema is valid`.
- `xcrun cktool export-schema --team-id H52N5N7WQ7 --container-id iCloud.com.liangzhang.editor.sync --environment production --output-file /tmp/editor-current-production-verify.ckdb` succeeded; the exported Production schema still contains only `Users`, so Release/TestFlight remains blocked until the schema is deployed through the supported CloudKit Console path.
- `scripts/cloudkit_final_device_sync_gate.sh` was added as the final physical-device gate. A TDD fake-child-script harness first failed because the script did not exist, then passed after implementation by proving the ordered calls are wait-and-cross-device verifier, APNs registration probe, and completion audit. A failure harness also verified the script stops before APNs/audit if the cross-device verifier does not publish `completed.ok`.
- `APPEND_TEXT="ios-fast-probe-..." PAGE_ID=page-welcome BUILD_IOS_APP=0 INSTALL_IOS_APP=0 RESET_IOS_APP=0 LAUNCH_ATTEMPTS=1 scripts/ios_headless_sync.sh` was rerun against the currently installed physical iPhone app. SpringBoard still rejected launch with `RequestDenied / Locked`, and `scripts/ios_sync_readback.sh` still could not copy `Library/Application Support/Editor/editor.sqlite` because the latest app has not launched.
- `scripts/cloudkit_sync_completion_audit.sh` now validates the real signed Debug products in addition to source entitlements. The current signed `EditorMac.app` passes CloudKit container, Development environment, app sandbox, and network-client gates; the current signed `EditorIOS.app` passes CloudKit container, Development environment, and `aps-environment=development` gates.
- A current macOS app-container check found the local database had fallen back to schema version 9 with three pending duplicate `page-welcome` updates and no `runtime_diagnostics` table. `APPEND_TEXT="mac-origin-for-ios-pull-20260520072949" PAGE_ID=page-welcome BUILD_MAC_APP=0 RUN_TIMEOUT_SECONDS=120 scripts/macos_headless_sync.sh` migrated it to schema 11, uploaded one new macOS-origin block, fetched eight remote changes, and left `sync_changes=0`.
- A fresh `scripts/cloudkit_sync_completion_audit.sh` run after the signed-product gate and macOS recovery passes source entitlement, signed-product entitlement, Development schema, macOS `sync_changes=0`, and readiness-document gates. It skips text-specific cross-device assertions until explicit expected text or completed cross-device state exists, warns for missing Production app schema, and still fails the missing physical iOS sync/APNs readback databases.
- `BUILD_MAC_APP=0 BUILD_IOS_APP=0 INSTALL_IOS_APP=0 RESET_IOS_APP=0 APNS_BUILD_IOS_APP=0 APNS_INSTALL_IOS_APP=0 APNS_RESET_IOS_APP=0 WAIT_TIMEOUT_SECONDS=1 WAIT_INTERVAL_SECONDS=1 LAUNCH_ATTEMPTS=1 scripts/cloudkit_final_device_sync_gate.sh` exercised the final gate against the currently locked iPhone. It stopped during Step 1 after `RequestDenied / Locked` and missing iOS SQLite readback, and did not proceed to APNs or completion audit.
- `SQLiteDatabase.open` now configures `PRAGMA busy_timeout = 1000` for every connection, covering startup-time APNs/runtime diagnostic writes that can briefly overlap with migration or sync work. TDD evidence: `SchemaMigratorTests.testDatabaseConfiguresBusyTimeoutForStartupDiagnostics` first failed with `0 != 1000`, then passed after setting the SQLite busy timeout.
- `xcodebuild build -scheme EditorMac ...` and `xcodebuild build -scheme EditorIOS ...` both passed after the busy-timeout change; the iOS build still only reports the existing orientation warning. The rebuilt `EditorIOS.app` was installed to the physical device at `file:///private/var/containers/Bundle/Application/77AD129F-9033-4C27-B7F5-ABCA44296C19/EditorIOS.app/`.
- A fresh launch retry against that newly installed iOS app still failed with `RequestDenied / Locked`, so no new iOS SQLite readback exists yet.
- `BUILD_MAC_APP=0 RUN_TIMEOUT_SECONDS=120 scripts/macos_headless_sync.sh` ran the rebuilt macOS app, recorded `cloudkit_sync_diagnostic_completed`, left `schema_version=11`, `sync_changes=0`, and reported zero upload/fetch failures.
- `scripts/cloudkit_sync_completion_audit.sh` now reports the latest APNs registration diagnostic when the required APNs success row is missing. A fake APNs readback harness first failed because `remote_notification_registration_failed` existed but the audit only said success was missing; after the change, the same harness reports `latest_diagnostic=remote_notification_registration_failed payload={"error":"simulated apns failure"} created_at=2026-05-20T00:00:00Z`. A paired fake success readback still reports `PASS|ios_required_diagnostic`.
- `EditorIOSAppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` now runs `AppEnvironment.handleRemoteNotificationSync()` on a utility background queue and returns to the fetch completion handler on the main queue. TDD evidence: `PlatformSecurityTests.testIOSAppDelegateRunsRemoteNotificationSyncOffMainCallback` first failed while the delegate called the sync handler inline, then passed after the async callback change. The first iOS build attempt caught Swift 6 sendability for the completion handler; the final delegate signature marks it `@Sendable`, and `xcodebuild build -scheme EditorIOS ...` passes with only the existing orientation warning.
- The rebuilt iOS app containing the async silent-push handler was installed to the physical device at `file:///private/var/containers/Bundle/Application/BC70765F-825C-4B1D-B74C-AFF501678267/EditorIOS.app/`.
- Focused regression coverage after that change: `xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests .../EditorTests.xctest` passed with 86 tests and 0 failures.
- `ALLOW_FAILED_RESULT=1 RUN_TIMEOUT_SECONDS=60 scripts/ios_simulator_silent_push.sh` was rerun after the async iOS delegate change. It still timed out without a `remote_notification_sync_completed` diagnostic and found no Simulator `editor.sqlite`, so the Simulator `simctl push` path remains a delivery/probe limitation rather than handler-path proof.
- `ALLOW_FAILED_RESULT=1 RUN_TIMEOUT_SECONDS=120 scripts/ios_simulator_remote_notification_sync.sh` was rerun as the direct handler-path control. It launched `com.liangzhang.editor.ios`, recorded `remote_notification_sync_completed|{"error":"<CKError ... \"Not Authenticated\" (9/1002); \"This request requires an authenticated account\">","failed_upload_count":0,"fetched_count":0,"result":"failed","uploaded_count":0}`, and left the local Simulator store at `schema_version=11`, `sync_changes=0`, `runtime_diagnostics=1`, `blocks=1`.
- A final `scripts/cloudkit_sync_completion_audit.sh` pass after the Simulator control still passes explicit-container, source entitlements, signed macOS/iOS product entitlements, Development schema record types/fields, macOS `sync_changes=0`, and readiness-document gates. It warns that Production is missing all six app record types, and exits non-zero only because physical iOS sync and APNs readback databases are still absent.
- `xcrun cktool validate-schema --team-id H52N5N7WQ7 --container-id iCloud.com.liangzhang.editor.sync --environment production --file docs/cloudkit/editor-cloudkit-schema.ckdb` was also rejected with `BadRequestException: endpoint not applicable in the environment 'production'`, matching the earlier import result and confirming that production promotion is a CloudKit Console/Dashboard step rather than a `cktool` production import/validate step.
- Internal `syncNow()` still uses the same `WorkspaceSyncScheduling` path as foreground activation sync instead of running CloudKit upload/fetch inline on the MainActor. TDD evidence: `WorkspaceViewModelTests.testSyncNowSchedulesForegroundSyncWithoutRunningItInline` first failed because no scheduler operation was recorded, the pending change was cleared inline, and the status jumped straight to completed; after the change, that test and the existing upload/fetch UI tests pass after driving the deferred scheduler.
- After the manual-sync scheduling change, `xcodebuild build -scheme EditorMac ...` and `xcodebuild build -scheme EditorIOS ...` both passed; the iOS build still only reports the existing orientation warning. The rebuilt `EditorIOS.app` was installed to the physical device at `file:///private/var/containers/Bundle/Application/C021B214-8F9C-4A7A-A423-1B85F7E098BF/EditorIOS.app/`. A no-rebuild headless launch immediately afterward was still rejected with `RequestDenied / Locked`, so no fresh iOS SQLite readback exists yet for this build.
- `EditorShellView` now runs the foreground sync gate on initial view appear as well as later `scenePhase` changes. TDD evidence: `PlatformSecurityTests.testEditorShellSyncsOnInitialActiveAppearAndLaterActivation` first failed because only `.onChange(of: scenePhase)` called `syncAfterActivation`; after adding the `.onAppear` hook, the new source-level test plus `WorkspaceViewModelTests.testSyncAfterActivationSchedulesForegroundSyncWithoutRunningItInline` and `testSyncAfterActivationIgnoresDuplicateRequestsWhileForegroundSyncIsRunning` pass.
- After the initial-appear sync hook, `xcodebuild build -scheme EditorMac ...` passed, and a first parallel `EditorIOS` build attempt failed only because two `xcodebuild` processes were sharing the same DerivedData build database. Rerunning the iOS build sequentially passed with the existing orientation warning. The rebuilt `EditorIOS.app` was installed to the physical device at `file:///private/var/containers/Bundle/Application/2E48E698-C771-4ECB-B4CE-E16217B39C9F/EditorIOS.app/`; the subsequent headless launch remained blocked by `RequestDenied / Locked`, so the physical iOS readback gate is still waiting for an unlocked device.
- A fresh completion audit after that build found the macOS container still had three stale `editor-cloudkit-v1` pending page updates. The marker file confirmed `.sync-generation = editor-cloudkit-v1`. Running `BUILD_MAC_APP=0 RUN_TIMEOUT_SECONDS=120 scripts/macos_headless_sync.sh` with the rebuilt app applied `LocalSyncGenerationResetPolicy`, rewrote the marker to `editor-cloudkit-v2`, recreated the local store, and left `sync_changes=0`. The CloudKit diagnostic itself hit a transient `CKError Network Failure` / `NSURLErrorDomain:-1005`, but the offline-first local reset and readable bootstrap store succeeded.
- `SyncEngine.fetchRemoteChanges()` now recovers from an expired CloudKit server change token by deleting the local token and retrying once from scratch. TDD evidence: `SyncEngineTests.testFetchRemoteChangesResetsExpiredServerChangeTokenAndRetriesFromScratch` first failed with `CKErrorDomain Code=21`, then passed after the reset-and-retry path. A nearby regression test, `testFetchRemoteChangesDoesNotResetTokenForNonExpiryFetchFailure`, verifies ordinary fetch errors still preserve the token and surface the failure.
- After the server-change-token recovery change, `xcrun xctest -XCTest PlatformSecurityTests,SchemaMigratorTests,SyncRepositoryTests,SyncEngineTests,WorkspaceViewModelTests .../EditorTests.xctest` passed with 209 tests and 0 failures. `xcodebuild build -scheme EditorMac ...` passed, and `xcodebuild build -scheme EditorIOS ...` passed with only the existing orientation warning. The rebuilt `EditorIOS.app` was installed to the physical device at `file:///private/var/containers/Bundle/Application/5AEE55F0-4081-4BAB-B838-BEB197671C8B/EditorIOS.app/`. A fresh completion audit still passes source/signed entitlements, Development schema fields, and macOS `sync_changes=0`, and still exits non-zero only because the physical iOS sync/APNs readback databases are absent.
- `scripts/cloudkit_sync_completion_audit.sh` now fails explicitly when a local store still carries an old `.sync-generation` marker. A fake-store TDD harness first confirmed the audit did not report `mac_sync_generation` for `editor-cloudkit-v1`, then passed after the audit emitted `FAIL|mac_sync_generation|... expected editor-cloudkit-v2` for the old marker and `PASS|mac_sync_generation|... editor-cloudkit-v2` for the current marker. A paired fake iOS readback harness verifies the same `FAIL`/`PASS` behavior for `ios_sync_generation`. `scripts/ios_sync_readback.sh` also copies `.sync-generation` beside the iOS SQLite readback; a fake `devicectl` harness verified the marker is copied into the readback directory.
- `scripts/macos_cloudkit_runtime_probe.sh` was added as a first-class minimal CloudKit probe gate. TDD evidence: `PlatformSecurityTests/testCloudKitRuntimeProbeDiagnosticRequestParsesHeadlessLaunchEnvironment` first failed because `CloudKitRuntimeProbeDiagnosticRequest` did not exist, and `test -x scripts/macos_cloudkit_runtime_probe.sh` failed because the script was absent. After implementation, the focused tests passed and the real macOS Debug app recorded `cloudkit_runtime_probe_completed|{"record_name":"runtime-probe-AE72B9E9-5C01-4AE5-988D-ADBA4DAA54F6"}|2026-05-20T00:59:42Z` with `sync_changes=0`, proving the current Development container can run account status, zone ensure, save, fetch, and delete without reproducing the earlier HTTP 500.
- The final physical-device gate exposed two device/runtime timing issues and the scripts now handle both without hiding real CloudKit failures. A fake wait-wrapper harness first failed because an iOS readiness `Network Unavailable` / `NSURLErrorDomain:-1009` aborted immediately; after the change, lock and network-unavailable/network-failure states retry while non-retryable failures still stop the gate. A fake iOS readback harness first failed because an old `cloudkit_sync_diagnostic_failed` row poisoned a newer successful run; after the change, `scripts/ios_headless_sync.sh` evaluates only the latest CloudKit sync diagnostic event. A fake APNs harness first failed because locked launch aborted before readback; after the change, `scripts/ios_apns_registration_probe.sh` treats SQLite readback containing `remote_notification_registration_succeeded` as authoritative.
- Final Development evidence from the physical iPhone and macOS Debug app: macOS uploaded `mac-cross-device-20260520011051` with `uploaded_count=1`, iOS fetched that text and uploaded `ios-cross-device-20260520011051` with `uploaded_count=1`, and macOS fetched the iOS-origin text with `fetched_count=1`; both sides reported `sync_changes=0` and `.sync-generation = editor-cloudkit-v2`. The APNs readback contains `remote_notification_registration_succeeded` at `2026-05-20T01:13:44Z` and `remote_notification_sync_completed` with `result=new_data`, `fetched_count=8`, `failed_upload_count=0`. The final completion audit passed every Development/debug gate; Production still warns because the app schema has not been deployed there.

## Completion Gate

The full CloudKit sync objective is not complete until all of these are proven:

- The iOS app logs remote-notification registration success or a concrete APNs registration error on the paired physical device.
- A macOS local edit uploads and is fetched by the iOS app automatically without leaving UI-generated local dirty state.
- A new iOS headless diagnostic edit uploads and is fetched by the macOS app.
- Silent CloudKit push wakes the iOS remote-notification handler and returns the expected background fetch result.
- Pending local changes remain available when the network or CloudKit is unavailable.
- If running Release/TestFlight, Production schema contains the same required app record types and fields as Development before using the production environment. Current `cktool` evidence shows this is not true yet.
