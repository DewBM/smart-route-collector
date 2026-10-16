# Glassline: Test Plan

Manual test plan for the Flutter app and the .NET backend. Tick each box as you go and note failures in the **Result** column.
Suggested order: A (setup), then B to G in sequence (they build on the same trip), then U (supplier sheet), the UI section (X), the API checks (API), robustness (Z) and the recording script (K).

Legend: **P** = pass, **F** = fail, **-** = not tested. IDs are stable, so you can quote them in bug notes (e.g. "S-4 fails").

---

## A. Setup and test data

### A1. Backend

```bash
cd backend

# 1. Apply all migrations (4 are new: skip, photo, supplier contact, signature)
dotnet ef database update

# 2. First run: create depot + 10 suppliers, 10 days of history, and a clean trip for today
Seed__Suppliers=true Seed__History=true Seed__ResetToday=true dotnet run
```

| Flag | What it does | Safe to leave on? |
|---|---|---|
| `Seed__Suppliers=true` | Adds a depot (if none) and 10 demo suppliers `GL-SUP-001..010`. Idempotent, never edits or deletes existing rows. | Yes |
| `Seed__History=true` | Creates completed trips for the last 10 days (about 70% of stops on target, the rest short; mixed conditions). Idempotent. | Yes |
| `Seed__SupplierDetails=true` | Fills only *empty* contact fields with fake values. Not needed if you used `Seed__Suppliers`. | Yes |
| `Seed__ResetToday=true` | **Deletes today's trip** (stops, collections, photos, signatures) so a fresh one is generated. Runs on every start while set. | **No.** Use only when you want to redo today. |
| `Database__AutoMigrate=true` | Applies pending migrations at startup. | Yes |

**Redo today's trip:** stop the server, start it again with `Seed__ResetToday=true`, and refresh the app.
**Hosted (Railway):** set the same names as environment variables, redeploy once, then remove `Seed__ResetToday`.

> **Hand-made suppliers:** if your database still has suppliers you inserted manually, they will join today's trip and change the expected route. For a clean run, delete them or use an empty database.

### A2. App

- [ ] `mobile/lib/services/api_service.dart` `baseUrl` points to a server the phone can reach (LAN IP for a real phone, `http://10.0.2.2:5081` for an emulator).
- [ ] Run with a **full restart**: `flutter run` (not hot reload).
- [ ] Debug builds can call `http://` addresses. A **release APK cannot** (Android blocks cleartext), so test the release build against the hosted **https** URL.
- [ ] Barcodes ready: open `docs/testing/test-barcodes.pdf` on a second screen (or print it). Single PNGs are in `docs/testing/barcodes/`.

### A3. Barcodes (Code 128)

| Code | Supplier | Notes |
|---|---|---|
| `GL-SUP-001` | Kurunegala Glass Traders | 120 kg clear / 80 kg coloured expected |
| `GL-SUP-002` | Kuliyapitiya Bottle Depot | 90 / 60 |
| `GL-SUP-003` | Narammala Hotel & Bar | 60 / 110 |
| `GL-SUP-004` | Polgahawela Supermarket | 150 / 40 |
| `GL-SUP-005` | Mawathagama Beverages | 80 / 50 |
| `GL-SUP-006` | Alawwa Restaurant Group | 45 / 95 |
| `GL-SUP-007` | Pannala Bottling Works | 200 / 70 |
| `GL-SUP-008` | Wariyapola Wholesale | 110 / 65 |
| `GL-SUP-009` | Nikaweratiya Canteen | 35 / 55 |
| `GL-SUP-010` | Galgamuwa Liquor Store | 70 / 130 |
| `GL-WRONG-999` | *(not a supplier)* | For the negative test |

### A4. Expected route per weekday

The order is nearest-neighbour from the depot (Kurunegala). Distances are Haversine (straight-line), so they should match the app to 0.1 km.

**Mon / Wed / Fri: 7 stops, 87.6 km, 1250 kg expected**

| # | Supplier | Km from previous |
|---|---|---|
| 1 | Kurunegala Glass Traders (001) | 0.7 |
| 2 | Mawathagama Beverages (005) | 8.0 |
| 3 | Polgahawela Supermarket (004) | 20.9 |
| 4 | Alawwa Restaurant Group (006) | 7.6 |
| 5 | Narammala Hotel & Bar (003) | 15.2 |
| 6 | Kuliyapitiya Bottle Depot (002) | 19.8 |
| 7 | Pannala Bottling Works (007) | 15.5 |

**Tue / Thu / Sat: 7 stops, 144.8 km, 1175 kg expected**

| # | Supplier | Km from previous |
|---|---|---|
| 1 | Kurunegala Glass Traders (001) | 0.7 |
| 2 | Narammala Hotel & Bar (003) | 17.5 |
| 3 | Polgahawela Supermarket (004) | 14.1 |
| 4 | Kuliyapitiya Bottle Depot (002) | 32.2 |
| 5 | Wariyapola Wholesale (008) | 28.2 |
| 6 | Nikaweratiya Canteen (009) | 18.8 |
| 7 | Galgamuwa Liquor Store (010) | 33.3 |

**Sunday: 4 stops, 64.5 km, 710 kg expected**: 001, 003, 004, 002 (same order and distances as Tue/Thu/Sat).

---

## B. Route screen (Screen 1)

| ID | Steps | Expected | Result |
|---|---|---|---|
| R-1 | Open the app with the backend running. | Skeleton loader, then the route. Header shows today's date, ring `0/7`, total distance and remaining = 7. | |
| R-2 | Compare order and distances with A4. | Same order; distances match to 0.1 km; total matches. | |
| R-3 | Look at statuses. | Stop 1 is **Next** (highlighted card, pulsing marker, Navigate and Scan buttons). Others are **Pending**. | |
| R-4 | Pull down on the list; tap the refresh icon. | List refreshes without flicker; no duplicate stops. | |
| R-5 | Tap the map icon in the header. | "Route overview" opens: OSM tiles, a route line that follows roads, numbered pins (stop 1 highlighted). | |
| R-6 | Tap different pins. | Bottom card switches stop (name, status, km, expected kg). **Details** and **Navigate** buttons present. | |
| R-7 | Tap **Navigate** on the Next stop. | Google Maps opens with driving directions from your location to that supplier. Without Google Maps installed, it opens in the browser. | |
| R-8 | Turn the network off and open Route overview. | Map area may be blank (no tiles), but the pins and line still show; no crash. | |
| R-9 | Tap a stop card (any status). | Supplier sheet opens (see U-tests below). | |
| R-10 | Backend down and network off; force-close and reopen the app. | The cached route loads; the connectivity strip says you're offline. | |
| R-11 | Fresh install, no network. | "Something went wrong" error state with **Retry**; retry works once online. | |

## C. Scan and collect (Screen 2)

Complete stop 1 (`GL-SUP-001`) unless the row says otherwise.

| ID | Steps | Expected | Result |
|---|---|---|---|
| S-1 | Tap **Scan** on the Next stop. | Camera opens automatically with a scan frame and animated line. Form is dimmed and locked ("Scan the barcode to unlock"). | |
| S-2 | Scan `GL-WRONG-999`. | Blocked: red banner, shake, heavy vibration. Form stays locked. | |
| S-3 | Scan `GL-SUP-005` (a real supplier, wrong stop). | Blocked: "That barcode belongs to a different supplier". The banner does not reveal the expected code. | |
| S-4 | Hold the wrong barcode steady for 5 s. | Feedback repeats no more than about once every 2 s (no vibration spam). | |
| S-5 | Toggle the torch button. | Torch turns on and off; icon state matches. | |
| S-6 | Scan `GL-SUP-001` (the correct code). | Success vibration; "Location verified" banner; camera closes; form unlocks. | |
| S-7 | Tap Confirm with everything empty. | Validation: weights required; condition required. | |
| S-8 | Use **+ / −** steppers. | Value changes by 1 kg; never below 0. | |
| S-9 | Tap **Use expected** on both fields. | Fields fill with 120 and 80. | |
| S-10 | Enter clear 100, coloured 80. | Amber hint: "20 kg below expected…". | |
| S-11 | Enter clear 120, coloured 80. | Hint disappears. | |
| S-12 | Type letters or a value like `1.234`. | Only digits and up to 2 decimals are accepted. | |
| S-13 | Choose a condition chip. | Chip selected (tick vibration); error text gone. | |
| S-14 | **Photo:** tap "Take photo of the glass", take one. | Thumbnail appears; **Retake** and **Remove** work; tap opens full screen with pinch zoom. | |
| S-15 | Deny the camera permission, then tap the photo button. | Snackbar "Could not open the camera"; app does not crash. | |
| S-16 | **Signature:** tap "Get supplier signature". | Sheet opens; drawing works; **Clear** resets; **Save** disabled until something is drawn. Optional name accepted. | |
| S-17 | Save the signature. | Thumbnail with "Signed by …"; **Redo** and **Remove** work. | |
| S-18 | Tap **Confirm collection**. | Returns to the Route; stop 1 is **Collected** (green tick); ring `1/7`; stop 2 is now **Next**. | |
| S-19 | Confirm without photo and signature. | Works (both are optional). | |
| S-20 | Rotate or lock the phone mid-form. | Entered values survive; no crash. | |
| S-21 | Press back before verifying. | Returns to the Route; nothing changed. | |

## D. Skip stop

| ID | Steps | Expected | Result |
|---|---|---|---|
| K-1 | On a Next stop's scan screen, tap **Skip** in the app bar. | Bottom sheet with four reasons. **Skip stop** disabled until one is chosen. | |
| K-2 | Choose **Other** without a note. | **Skip stop** stays disabled until a note is typed. | |
| K-3 | Cancel the sheet. | Nothing changes. | |
| K-4 | **Online:** skip the Next stop (e.g. stop 2, Mawathagama) with "Supplier closed". | Snackbar "Skipped … Route updated". Stop shows amber **Skipped** with the reason. Remaining stops are **re-ordered from that stop's location** (see note). Exactly one stop is Next. | |
| K-5 | Check total distance after the skip. | Value changes; per-stop "km from previous" recomputed for remaining stops. | |
| K-6 | The Skip button after scanning succeeds. | Hidden once the barcode is verified. | |
| K-7 | Skip until only one stop remains, then skip it. | Trip completes: **View trip report** appears. | |
| K-8 | **Offline:** skip a stop in airplane mode. | Snackbar says it will sync when online. Stop shows Skipped locally; strip says "1 change saved…". | |
| K-9 | Reconnect. | Strip syncs and flashes green; route refreshes; server order takes over. | |
| K-10 | Skipped stop in the reports (Section F, G). | Shows as **Skipped** with reason, **not** as a shortfall. | |

*Note (K-4):* the server re-runs the routing from the skipped supplier's coordinates. Verify sanity: each next stop is the nearest remaining one.

## E. Offline mode and sync queue

Do these with the same trip. Watch the strip above the bottom navigation.

| ID | Steps | Expected | Result |
|---|---|---|---|
| Q-1 | Airplane mode on; complete a stop (with photo and signature). | Completes instantly. Strip: "Offline · 3 changes saved, will sync when you're back online" (collection + photo + signature). | |
| Q-2 | Complete another stop offline, then skip a third. | Count increases. Route screen still consistent (stops Collected/Skipped, one Next). | |
| Q-3 | Force-close and reopen the app while offline. | Pending count is preserved; cached route shown with local statuses. | |
| Q-4 | Turn the network back on. | Within a few seconds: "Syncing N changes…" then green "All changes synced" (about 2.5 s), then the strip hides. | |
| Q-5 | Refresh the Route. | Server state matches the app; **no completed stop comes back as Pending/Next**. | |
| Q-6 | Wi-Fi on, but stop the backend server. Complete a stop. | Strip: "N changes not synced · Tap to retry". Stop still shows Collected in the app. | |
| Q-7 | Restart the backend; wait up to 45 s, or tap the strip. | Syncs; strip turns green. | |
| Q-8 | Refresh the Route while the backend is up but changes are pending. | Pending changes are pushed first, then the route loads; no flicker back to old statuses. | |
| Q-9 | Complete stops out of the server's expected order while offline (scan in a different order using the Next stop only, then skip so the order diverges). | After sync, server accepts every collection (no "not the current stop" rejection). | |
| Q-10 | Kill the app right after tapping Confirm. | On reopening, the collection is still queued and syncs. | |
| Q-11 | Sync while a photo is large (take a high-detail photo). | Photo uploads; no timeout error (limit 3 MB, phone compresses to ~200 KB). | |

## F. Trip report (Screen 3)

Finish the whole trip (mix of on-target, shortfall and one skipped stop), then open **View trip report**.

| ID | Steps | Expected | Result |
|---|---|---|---|
| T-1 | Open the report. | Total kg counts up; distance, duration (first to last collection), stop count shown. | |
| T-2 | Check the donut chart and legend. | Clear and coloured totals and percentages add up to 100%. | |
| T-3 | Check totals manually. | Sum of collected kg matches what you entered. | |
| T-4 | Stops collected below expected (clear **or** coloured). | Amber **Shortfall** badge and amber bar; banner "N suppliers delivered less than expected". | |
| T-5 | Stop at or above expected. | Green **On target**. | |
| T-6 | Skipped stop. | Card shows **Skipped** and reason; header shows "N stops · 1 skipped". | |
| T-7 | Stop with photo and/or signature. | Thumbnails shown; tap the photo for full screen; "Signed by …" text. | |
| T-8 | Tap **Sync to server** with everything already synced. | Success state "Synced to server". | |
| T-9 | Turn the network off, then tap **Sync to server**. | Red error with "Your data is safe on this device" and **Retry sync**. Data unchanged. | |
| T-10 | Back online, tap **Retry sync**. | Success. | |
| T-11 | Tap the share icon. | PDF is generated; the Android share sheet opens; sharing to Drive or WhatsApp works. | |
| T-12 | Open the PDF. | Header with total kg, stat boxes, table with amber shortfall/skipped rows, page numbers. Signed stops show "Signed by …" under the supplier. | |
| T-13 | Share while offline. | Still works (PDF is generated on the phone). | |
| T-14 | Server check (section API): `GET /api/trips/{id}/summary`. | Same totals and flags as the app. | |

## G. History and Insights

| ID | Steps | Expected | Result |
|---|---|---|---|
| H-1 | Open the **History** tab. | List of about 10 past trips (newest first) with date, kg, stops, distance, duration, badges. Today's trip is included. | |
| H-2 | Check a card with shortfalls. | "N shortfalls" in amber. | |
| H-3 | Today's unfinished trip. | Badge "In progress x/y" (collected plus skipped over total). | |
| H-4 | Tap a past trip. | Skeleton, then the full report (read-only, no sync bar) with the trip date in the header. | |
| H-5 | Open a trip you completed with photo and signature (after sync). | Thumbnails load from the server. | |
| H-6 | Share a past trip as PDF. | Works. | |
| H-7 | Offline, open History for the first time. | Error state with retry; no crash. | |
| H-8 | Open the **Insights** tab. | Total kg in the header; 4 stat cards; stacked bar chart of daily kg; shortfall ring; top suppliers. | |
| H-9 | Switch **7 days / 30 days**. | Chart re-renders (30 days: labels every 5th bar); values update. | |
| H-10 | Tap a bar. | Tooltip shows the day's total kg. | |
| H-11 | Check the shortfall rate against the seed. | Roughly 30% for the seeded history (varies). | |
| H-12 | Empty database (no trips). | "No data yet" empty state. | |

## U. Supplier sheet

| ID | Steps | Expected | Result |
|---|---|---|---|
| U-1 | Tap a stop card. | Draggable sheet: name, status, expected kg, **Navigate**, **Call**. | |
| U-2 | Check the contact card and site notes. | Contact person, phone, address; notes in an amber callout. | |
| U-3 | Tap **Call**. | Dialer opens with the number. | |
| U-4 | Recent collections. | Up to 3 rows with kg, condition and a shortfall marker; "N collections, X kg average". | |
| U-5 | Open the sheet offline. | Contact and notes still show (cached). History shows "unavailable offline" with a retry. | |
| U-6 | Supplier without any contact data. | "No contact details on file." and no Call button. | |
| U-7 | Map view: tap a pin, then **Details**. | Same sheet opens. | |

---

## X. UI, UX and accessibility

| ID | Steps | Expected | Result |
|---|---|---|---|
| X-1 | Switch the phone to dark mode. | Every screen readable; charts, map tiles and status chips adapt; no white flashes. | |
| X-2 | Set the system font to the largest size. | Text capped at 1.3x; no overflow stripes on any screen. | |
| X-3 | Test on a small phone (or a 320 dp wide emulator). | No horizontal overflow; buttons remain tappable. | |
| X-4 | Turn on TalkBack and go through Route, Scan and Report. | Stops read as "Stop 2, name"; status announced; progress ring "3 of 7 stops done"; map pins labelled; buttons have names. | |
| X-5 | Page transitions. | Fade and slight slide; back gesture works. | |
| X-6 | App icon and splash. | Indigo route icon; splash in light or dark to match the theme. | |
| X-7 | Loading states. | Skeletons on Route, History, Insights; no blank screens. | |
| X-8 | Trip with 0 stops (e.g. clear suppliers). | "No stops today" empty state. | |

## API. Backend checks (curl)

```bash
API=http://localhost:5081
TRIP=$(curl -s $API/api/trips/today | python3 -c "import sys,json;print(json.load(sys.stdin)['tripId'])")
```

| ID | Command | Expected | Result |
|---|---|---|---|
| API-1 | `curl -s $API/api/trips/today` | 200, `stops` sorted by `stopOrder`; exactly one `Next`; each stop has `address`, `phone`, `notes`. | |
| API-2 | Same call twice. | Same `tripId` (one trip per day). | |
| API-3 | `curl -s -X POST $API/api/collections -H 'Content-Type: application/json' -d '{"tripId":'$TRIP',"supplierId":1,"clearKg":100,"colouredKg":70,"condition":"Clean","collectedAt":"2026-09-30T05:00:00Z"}'` | 200 "Collection recorded". Stop becomes Collected; a Next remains. | |
| API-4 | Repeat API-3. | 200 "already recorded" (idempotent); still one collection. | |
| API-5 | Same call with `"supplierId":99999`. | 404 "Trip stop not found". | |
| API-6 | POST a collection for a **Pending** (not Next) stop. | 200 (accepted, for offline order changes). | |
| API-7 | POST a collection for a skipped stop. | 400 "This stop was skipped". | |
| API-8 | `curl -s -X POST $API/api/trips/$TRIP/stops/2/skip -H 'Content-Type: application/json' -d '{"reason":"Supplier closed"}'` | 200; returns the updated trip; that stop `Skipped`; remaining re-ordered. | |
| API-9 | Repeat API-8. | 200; no change (idempotent). | |
| API-10 | Skip a Collected stop. | 400 "already been collected". | |
| API-11 | Skip with an empty `reason`. | 400 (validation). | |
| API-12 | `curl -s $API/api/trips/history` | Array of trips, newest first, with `skippedCount`. | |
| API-13 | `curl -s $API/api/trips/$TRIP/summary` | Totals, per-stop `skipped`, `skipReason`, `photoUrl`, `signatureUrl`, `signedBy`. | |
| API-14 | `curl -s "$API/api/insights?days=7"` | 7 daily entries (empty days included); `shortfallRate` 0 to 1; up to 5 top suppliers. | |
| API-15 | `curl -s "$API/api/insights?days=500"` | Clamped to 90 days. | |
| API-16 | `curl -s $API/api/suppliers/1` | Contact fields, `recentCollections` (max 3), averages. | |
| API-17 | `curl -s -X PUT $API/api/suppliers/1/contact -H 'Content-Type: application/json' -d '{"phone":"+94 77 555 9999"}'` | 200; the phone is updated (other contact fields cleared, since PUT replaces them). | |
| API-18 | `curl -s -F tripId=$TRIP -F supplierId=1 -F file=@docs/testing/barcodes/GL-SUP-001.png $API/api/collections/photo` | 200 "Photo saved" (PNG is accepted). Then `GET /api/collections/photo/$TRIP/1` returns the image. | |
| API-19 | Upload a file larger than 3 MB to `/photo`. | 400 or 413 "too large". | |
| API-20 | Upload a photo for a stop with **no** collection. | 404 "Sync the collection first". | |
| API-21 | `curl -s -o /dev/null -w '%{http_code}' $API/api/collections/photo/$TRIP/1` | 200 with the image after upload; 404 if none. | |
| API-22 | Upload a **JPEG** as a signature. | 400 "must be a PNG". | |
| API-23 | `curl -s -F tripId=$TRIP -F supplierId=1 -F signerName=Test -F file=@docs/testing/barcodes/GL-SUP-001.png $API/api/collections/signature` | 200; `signedBy` appears in the summary. | |
| API-24 | `POST /api/collections/sync` with 3 stops in a body. | All three Collected; the trip ends complete when all stops are done. | |

## Z. Robustness and regression

| ID | Scenario | Expected | Result |
|---|---|---|---|
| Z-1 | Upgrade path: install an older build, collect a stop offline, then install this build over it. | Local database upgrades (v1 to v5); pending data survives. | |
| Z-2 | Deny location/camera permissions permanently. | Features degrade gracefully with a message. | |
| Z-3 | Double-tap **Confirm collection**. | Only one collection is recorded. | |
| Z-4 | Low storage or an unwritable photo directory. | Error snackbar; the collection can still be saved without the photo. | |
| Z-5 | Timezone: run at 00:00 to 05:30 Colombo time (UTC still yesterday). | Route uses the Colombo date; `today/summary` may disagree (known: it uses UTC). | |
| Z-6 | Two phones on the same trip. | Second phone sees the first's collections after refresh; duplicate submissions are ignored. | |
| Z-7 | Leave the app in the background for an hour, then reopen. | No crash; strip and route refresh correctly. | |
| Z-8 | Complete the trip, close, reopen next day. | New trip generated; yesterday appears in History. | |

---

## K. Screen-recording script (submission demo, about 3 minutes)

1. Open the app; the route loads from the hosted backend.
2. Route screen: point out order, distance, remaining, then the map overview.
3. Scan a **wrong** barcode (blocked), then the **correct** one (form unlocks).
4. Enter quantities (one below expected to show the hint), add a photo and a signature, confirm.
5. Show the next stop advancing; skip one stop with a reason and show the route re-ordering.
6. Go offline, complete a stop, show the strip; reconnect and show it syncing.
7. Complete all stops; open the trip report with the shortfall flag and the skipped stop.
8. Tap **Sync to server** (success), then share the PDF.
9. Show History (open a past trip) and Insights (7 and 30 days).
10. Switch to dark mode for a final shot.

## Known limitations (not bugs)

- History and Insights need a connection (they are not cached).
- Map tiles need a connection; the pins and route line still draw offline.
- Route distance is straight-line (Haversine); the map shows road geometry, so the road length is longer.
- After an offline skip, the app uses the original order until the server re-optimises.
- The PDF uses a built-in Latin font. Non-Latin supplier names will not render.
- A collection the server permanently rejects (4xx) is dropped from the queue without a message.
