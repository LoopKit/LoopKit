# Reporting Insulin Doses to Loop — A Guide for PumpManager Authors

> **Read this before you ship a driver.** Loop dynamically doses insulin based on its
> running estimate of insulin-on-board (IOB). That estimate is built almost entirely
> from the doses *your* `PumpManager` reports. If you report a dose that didn't happen,
> fail to report one that did, or report the wrong amount, Loop will under- or
> over-deliver insulin. **Mis-tracked insulin can cause severe hypo- or hyperglycemia
> and can be fatal.** Correct dose reporting is the single most safety-critical
> responsibility of a pump driver.

This guide explains the *contract* between a `PumpManager` and Loop's `DoseStore`: how
doses are reported, how in-progress ("mutable") doses are finalized, how
`lastReconciliation` establishes trust, and the failure modes that have actually bitten
real drivers. It is grounded in the LoopKit source and in the three in-tree drivers
(OmnipodKit, MinimedKit, MedtrumKit).

File references in this document point at LoopKit as of this writing; line numbers may
drift, but the symbol names are stable.

---

## 1. The one method that matters

Everything flows through a single `PumpManagerDelegate` call
(`LoopKit/DeviceManager/PumpManager.swift`):

```swift
func pumpManager(_ pumpManager: PumpManager,
                 hasNewPumpEvents events: [NewPumpEvent],
                 lastReconciliation: Date?,
                 replacePendingEvents: Bool,
                 completion: @escaping (_ error: Error?) -> Void)
```

In the Loop app this is implemented in `DeviceDataManager` and forwards directly to:

```swift
try await doseStore.addPumpEvents(events,
                                  lastReconciliation: lastReconciliation,
                                  replacePendingEvents: replacePendingEvents)
```

So the real contract is **`DoseStore.addPumpEvents`**
(`LoopKit/InsulinKit/DoseStore.swift`). Read its doc comment; it is authoritative. The
rest of this guide unpacks the three coupled concepts you must get right:

1. **The mutable dose lifecycle** — reporting in-progress doses and finalizing them.
2. **`replacePendingEvents`** — how Loop knows which pending doses to drop.
3. **`lastReconciliation`** — the trust boundary up to which delivery is accounted for.

> The protocol doc comment summarizes the intent of `lastReconciliation`:
> *"This should be called any time the PumpManager synchronizes with the pump, even if
> there are no new doses in the log, as changes to lastReconciliation indicate we can
> trust insulin delivery status up until that point, even if there are no new doses."*

---

## 2. The data model: `NewPumpEvent` and `DoseEntry`

You report an array of `NewPumpEvent` (`LoopKit/InsulinKit/NewPumpEvent.swift`):

```swift
public struct NewPumpEvent {
    public let date: Date          // when the event occurred
    public let dose: DoseEntry?    // the insulin dose, if this event is a dose
    public let raw: Data           // OPAQUE unique identifier — see §4
    public let type: PumpEventType?
    public let title: String
    public let alarmType: PumpAlarmType?
}
```

Crucially, the initializer sets the dose's `syncIdentifier` **from `raw`**:

```swift
public init(date: Date, dose: DoseEntry?, raw: Data, title: String, ...) {
    var dose = dose
    dose?.syncIdentifier = raw.hexadecimalString   // <-- raw IS the identity
    self.dose = dose
    ...
}
```

So `raw` is not just for de-duplication of the pump-event log — it becomes the identity
of the dose all the way down into the InsulinDeliveryStore / HealthKit. **§4 is about
getting `raw` right; it is the linchpin of the whole machine.**

The dose itself is a `DoseEntry` (`LoopKit/InsulinKit/DoseEntry.swift`). The fields that
matter most for reporting:

| Field | Meaning |
|---|---|
| `type` | `.bolus`, `.tempBasal`, `.basal`, `.suspend`, `.resume` |
| `startDate` / `endDate` | delivery window. `endDate` for a temp basal is when it is *scheduled* to end |
| `value` + `unit` | the **programmed** amount (units, or units/hour) |
| `deliveredUnits` | the **actually delivered** amount — set this when you finalize |
| `isMutable` | `true` while delivery is still in progress / not yet final — see §3 |
| `wasProgrammedByPumpUI` | `true` if the user set this dose on the pump itself, not via Loop — see §6 |
| `decisionId` | correlates the dose back to the Loop dosing decision that requested it (pass it through from `enactBolus`/`enactTempBasal`) |
| `automatic` | whether the dose was automatic vs. user-commanded |
| `syncIdentifier` | set for you from `raw` — do not set it manually |

---

## 3. The mutable dose lifecycle (the heart of it)

A dose with `isMutable == true` means **"delivery is still happening; this is my best
estimate and I will update it."** A bolus that's mid-delivery, a temp basal that's
currently running, an open suspend — all are mutable.

### The report-or-delete rule

This is the behavior every driver author must internalize:

> **A mutable dose only continues to exist in Loop for as long as you keep reporting it.**
> If you report a mutable dose in one `addPumpEvents` call (with
> `replacePendingEvents: true`) and then *omit* it from the next call, Loop **deletes**
> it.

Why: when `replacePendingEvents == true`, `addPumpEvents` first purges every stored
mutable pump event before inserting the new batch
(`DoseStore.swift`, in `addPumpEvents`):

```swift
if replacePendingEvents {
    try self.purgePumpEventObjects(matching: NSPredicate(format: "mutable == YES"))
}
```

The same logic is mirrored one tier down in `InsulinDeliveryStore.addDoseEntries(...,
resolveMutable: true)` — which `addPumpEvents` always calls. It marks **all** existing
mutable cached doses deleted, then *un-deletes* only the ones whose `syncIdentifier`
matches an incoming entry:

```swift
if resolveMutable {
    // fetch all non-deleted mutable objects, mark them all deleted
    mutableObjects.forEach { $0.deletedAt = now }
}
// ... then for each incoming entry, if it matches a mutable object by
//     provenanceIdentifier + syncIdentifier, update it and un-delete it.
```

This is *deliberate*: it's how you retract or finalize an in-progress dose. But it means
silence is destructive. The three correct transitions are:

| Situation | What to report |
|---|---|
| **Still delivering** | Re-send the same dose (same `raw`), `isMutable: true`, updated estimate |
| **Finished** | Send the same dose (same `raw`), `isMutable: false`, with final `deliveredUnits` and a real `endDate` |
| **Never happened / fully canceled with zero delivery** | Stop sending it (with `replacePendingEvents: true`) and it is removed |

### Finalization in practice

When `isMutable` flips to `false`, the dose stops being purged on subsequent calls and
becomes eligible to be written to HealthKit (mutable doses are **never** persisted to
HealthKit — only immutable, non-fault entries are; see
`InsulinDeliveryStore.addDoseEntries`). Finalization is what makes a dose permanent.

**Reference — OmnipodKit** derives mutability from whether the dose's delivery window has
elapsed (`UnfinalizedDose.isMutable` → `!isFinished(at:)`). On finalize it stamps
`finishTime` and moves the dose to `finalizedDoses`; the regenerated `DoseEntry` then
carries `endDate` + `deliveredUnits` and `isMutable == false`.

**Reference — MedtrumKit** sets it explicitly: `unfinalizedDose.toDoseEntry(isMutable:
true)` while running, and `toDoseEntry(isMutable: false)` on completion. Note its
`toDoseEntry` returns `deliveredUnits: isMutable ? nil : deliveredUnits` — i.e. an
in-progress dose reports **no** delivered amount, and the finalized one reports the real
delivered amount. That is the right shape.

---

## 4. `syncIdentifier` / `raw` must be **stable** across a dose's life

Because `raw` *is* the dose's identity (§2), the matching that turns "update an
in-progress dose" into "update" rather than "delete + duplicate" depends entirely on
`raw` staying **byte-for-byte identical** every time you re-report the same evolving
dose.

- ✅ **OmnipodKit** key: `"\(doseType) \(scheduledUnits ?? units) \(startTime)"`. On
  cancellation it sets `scheduledUnits = units` so the key still evaluates to the
  original programmed amount — **the key is stable through cancellation**. This is the
  pattern to copy.
- ✅ **MinimedKit** uses the pump's own binary history record (`event.pumpEvent.rawData`)
  as `raw` for historical events, and a stable per-dose `UUID` for pending doses. Pump
  history bytes are inherently identical on re-read.
- ⚠️ **MedtrumKit** builds the bolus key as `"\(DoseType.bolus.rawValue) \(units)
  \(date)"`. For normal delivery `units` is `programmedUnits` (stable), but the
  *cancellation* path passes `units: dose.deliveredUnits` (`MedtrumPumpManager`
  `cancelBolus`), so the `raw` **changes** when a bolus is canceled. It still produces a
  correct end state — because `replacePendingEvents: true` purges the stale mutable row
  by its `mutable == YES` flag regardless of identity — but it relies on that safety net
  rather than on identity matching. **Prefer the Omnipod approach:** keep the
  `syncIdentifier` constant for the entire life of a dose, including cancellation, and
  finalize by flipping `isMutable` and setting `deliveredUnits` — not by changing the
  key.

**Rule of thumb:** pick the identity of a dose *once*, when you first learn about it, and
never let it change. If your key is derived from any value that mutates during delivery
(delivered units, current rate, end time), you have a latent duplicate-dose bug.

---

## 5. `replacePendingEvents`

This flag controls the mutable purge in §3.

- `true` (default, and what you want most of the time): "this batch is the complete,
  current set of pending/mutable delivery — drop any pending doses I'm not re-sending."
- `false`: "append these events without disturbing my existing in-flight mutable doses."

Use `false` when you need to add an event **without** clobbering a live mutable dose.
OmnipodKit, for example, reports pod-change and pod-fault events with
`replacePendingEvents: false` (they must not wipe an in-progress bolus), but reports its
dose batch with `replacePendingEvents: true`. MedtrumKit emits the *initial* mutable
bolus with `replacePendingEvents: false` (add it alongside whatever else is pending) and
all finalizing/replacing updates with `true`.

> Pitfall: if you change a dose's `syncIdentifier` mid-life (§4) **and** use
> `replacePendingEvents: false`, the stale mutable copy will survive and you'll
> double-count. The two bugs compound.

---

## 6. `lastReconciliation` — the trust boundary

`lastReconciliation` is **not a dose**. It's a timestamp meaning *"I have fully accounted
for pump delivery up to this instant."* It is stored as
`DoseStore.lastPumpEventsReconciliation` and is set **unconditionally** at the top of
`addPumpEvents` — *before* the empty-events guard — so **every** call updates it,
including calls with `events: []`.

This is why you must **call the delegate on every sync, even when there are no new
doses.** The date advancing is itself the signal that delivery is trustworthy up to that
point. Concretely, `lastReconciliation` does three things inside `DoseStore`:

1. **Gates persistence to the InsulinDeliveryStore.**
   `getPumpEventDoseEntriesForSavingToInsulinDeliveryStore` returns *nothing* if
   `lastPumpEventsReconciliation` is `nil`, and uses it as the end of the range over
   which the basal schedule is overlaid. If you never set it, **no pump-event doses ever
   reach the delivery store / HealthKit.**

2. **Arbitrates reservoir vs. event data.** In `getNormalizedDoseEntries`,
   reservoir-derived doses are used only if reservoir data is continuous *and* the last
   reservoir reading is newer than `lastPumpEventsReconciliation`. Past the reconciliation
   point, reconciled event history wins; after it, reservoir data may supplement IOB.

3. **Bounds the dose timeline.** Doses are trusted up to this date.

### Two archetypes

The correct value depends on what kind of pump you have:

- **Loop-only pump (no independent UI, e.g. Omnipod, Medtrum patch):** there are no
  externally-initiated doses to miss, so `lastReconciliation` is simply **the last time
  you received telemetry/status from the pump**. OmnipodKit returns
  `podState.lastInsulinMeasurements?.validTime`; MedtrumKit returns `state.lastSync`.

- **Pump with its own UI and dosing history (e.g. Medtronic):** the user can bolus and
  set temp basals on the pump directly. Here `lastReconciliation` must reflect **the last
  time you fully read and reconciled pump history**, so that any external doses are
  accounted for — *not* merely the last status ping. MinimedKit sets
  `state.lastReconciliation = dateGenerator()` at the moment
  `reconcilePendingDosesWith(...)` completes a full history read.

> **Safety pitfall for UI-capable pumps:** advancing `lastReconciliation` past a point you
> haven't actually reconciled tells Loop to trust delivery it hasn't seen. If the user
> bolused on the pump in that window, Loop will under-count IOB and may over-deliver.
> Only move the boundary forward as far as you've genuinely accounted for delivery.

---

## 7. Accounting for doses the user made on the pump (`wasProgrammedByPumpUI`)

For UI-capable pumps, mark doses that originated on the pump (not from Loop) with
`DoseEntry.wasProgrammedByPumpUI = true`. MinimedKit derives this from the pump event's
`wasRemotelyTriggered` flag (`wasProgrammedByPumpUI: !event.wasRemotelyTriggered`) and
reconciles its own pending (Loop-commanded) doses against history within a 1-minute
matching window, updating each pending dose with the actual delivered values once it
appears in history. Loop-only pumps can leave this `false`.

---

## 8. What `DoseStore` does with what you send (so consequences are predictable)

A quick mental model of the pipeline, so the rules above make sense:

1. `addPumpEvents` sets `lastPumpEventsReconciliation` (always), optionally purges mutable
   events (`replacePendingEvents`), purges events older than the cache window, then
   inserts your batch as `PumpEvent` rows.
2. `pumpEventQueryAfterDate` — the cursor used by upload/critical-event-log consumers —
   advances **only when you send finalized (immutable) events**, and is pulled back to
   the earliest mutable date if a mutable event predates the newest final one. It will
   not advance past unfinalized data, so nothing mutable is ever reported upstream as
   final.
3. `syncPumpEventsToInsulinDeliveryStore(resolveMutable: true)` runs at the end of every
   `addPumpEvents` (including empty-events calls), reconciling mutable doses into the
   InsulinDeliveryStore and soft-deleting any mutable dose you stopped sending.
4. Immutable, non-fault doses get written to HealthKit for long-term persistence.

Two consequences worth internalizing:

- An **empty** `addPumpEvents([])` call updates `lastReconciliation` and re-resolves the
  InsulinDeliveryStore, but does **not** run the `replacePendingEvents` purge at the
  PumpEvent tier. It means "nothing new, but trust delivery up to now." Send these.
- De-duplication is by a unique constraint on `raw` at the PumpEvent tier and by
  `syncIdentifier` at the InsulinDeliveryStore tier — both derived from your `raw`. Stable
  `raw` (§4) is what keeps update-vs-insert correct.

---

## 9. Conformance checklist

- [ ] I call `hasNewPumpEvents` on **every** sync with the pump, even when there are no
      new doses (so `lastReconciliation` advances).
- [ ] I always pass a current, correct `lastReconciliation` (status time for Loop-only
      pumps; full-history-read time for UI-capable pumps).
- [ ] Each dose has a `raw`/`syncIdentifier` that is **constant for the entire life of
      that dose**, including while in-progress and through cancellation.
- [ ] In-progress doses are reported with `isMutable: true` and **re-reported on every
      sync** until they finalize.
- [ ] Finalized doses are reported with `isMutable: false`, a real `endDate`, and the
      actual `deliveredUnits`.
- [ ] I use `replacePendingEvents: true` when a batch represents my complete current set
      of pending delivery; `false` only when appending an event that must not disturb a
      live mutable dose.
- [ ] `value` carries the **programmed** amount; `deliveredUnits` carries the **actual**
      amount, rounded to the pump's supported increment.
- [ ] (UI-capable pumps) I set `wasProgrammedByPumpUI` for user-initiated doses and
      reconcile them from pump history.
- [ ] I thread `decisionId` from `enactBolus`/`enactTempBasal` through to the `DoseEntry`.
- [ ] I emit suspend/resume, prime, alarm, and pump-replacement events with appropriate
      types.

---

## 10. Lessons learned — real pitfalls from driver development

These are drawn from issues encountered building MedtrumKit (see
`pump-dev-bugs.md` for the full index of GitHub issues/PRs). They cluster around exactly
the mechanisms above, which is why this guide exists.

### Temp basal finalization and overwrite (MedtrumKit #77, PR #118, #112)
Temp basals are the most error-prone dose type because they evolve continuously and Loop
re-issues them frequently (≈ every 5 min for Medtrum). Observed failures:
- A running TBR being **overwritten** by a later report instead of updated → lost delivery
  history. Root cause traced to identity/finalization handling.
- A TBR being **discarded after a BLE reconnect** instead of being correctly finalized.
- `deliveredUnits` and plotting wrong due to **rounding** not matching the pump's 0.05 U
  increment.
- **Takeaway:** keep the TBR's `syncIdentifier` stable across every 5-minute update;
  finalize (not drop) it on reconnect; round `deliveredUnits` to the pump increment.

### Bolus during BLE loss (MedtrumKit #92, PR #93)
A bolus reported as **interrupted** because the app lost the BLE link mid-delivery, even
though the pump kept delivering. Lessons from the thread:
- **Register the bolus up front** as a mutable dose *before* you lose contact, so IOB
  isn't lost if the link drops.
- **Persist the in-progress (`UnfinalizedDose`) state** — don't keep it only in memory.
- On reconnect, **sync from the pump's own history** to recover the true delivered amount,
  then finalize. The pump is the source of truth, not the app's last guess.

### Suspend / resume events (MedtrumKit #29, PR #31, #89, #127, PR #129)
- A **resume** dose missing its scheduled basal rate caused incorrect basal display and
  accounting → resume events must carry the basal context needed downstream.
- **Suspend missing duration** and a **missing suspend event on force-remove** left Loop
  believing insulin was still being delivered while it wasn't.
- **Takeaway:** model suspend/resume as real dose events with correct timing; emit a
  suspend whenever delivery actually stops (including teardown), and a resume that
  restores the basal picture.

### Faults, alarms, and pump replacement (MedtrumKit #142, #114)
- Surface pump faults via `NewPumpEvent` with `type: .alarm` / `alarmType`.
- Emit `.replaceComponent` on patch/pump replacement (note: the *consumer* AID app must
  handle that event type — #114 turned out to be a Trio-side gap, not a driver bug).

The through-line: **every one of these is a dose-accounting correctness bug**, and each
maps to a rule in §3–§7. Treat in-progress delivery, reconnect recovery, and
finalization as first-class, test them deliberately, and reconcile against the pump's own
history whenever the pump can tell you what it actually did.

---

## 11. Testing recommendations

- **Interrupt everything.** Kill BLE mid-bolus and mid-temp-basal; verify the dose is
  recovered and finalized with the *pump's* delivered amount on reconnect, not dropped or
  duplicated.
- **Cancel everything.** Cancel a bolus and a temp basal at various points; verify the
  finalized dose shows the partial delivered amount and the `syncIdentifier` never
  changed.
- **Idempotency.** Re-report the same in-progress dose many times; confirm it stays a
  single dose in the InsulinDeliveryStore (no duplicates) and IOB doesn't drift.
- **Empty syncs.** Confirm a sync with no new doses still advances `lastReconciliation`.
- **Rounding.** Verify `value` and `deliveredUnits` are rounded to the pump's supported
  increment.
- **(UI pumps) External doses.** Bolus on the pump directly; confirm Loop picks it up from
  history with `wasProgrammedByPumpUI = true` and accounts for it in IOB.
- Diff your reported timeline against the pump's own delivery history and against expected
  IOB — small persistent discrepancies are how dosing errors hide.

---

## References

- `LoopKit/InsulinKit/DoseStore.swift` — `addPumpEvents`, `getNormalizedDoseEntries`,
  `syncPumpEventsToInsulinDeliveryStore`
- `LoopKit/InsulinKit/InsulinDeliveryStore.swift` — `addDoseEntries(resolveMutable:)`
- `LoopKit/InsulinKit/NewPumpEvent.swift`, `DoseEntry.swift`
- `LoopKit/DeviceManager/PumpManager.swift` — the delegate contract and its doc comments
- In-tree reference drivers: OmnipodKit (Loop-only), MinimedKit (UI + history), MedtrumKit
  (Loop-only patch, modern patterns)
- `pump-dev-bugs.md` — curated index of real dose-accounting issues and their fixes
