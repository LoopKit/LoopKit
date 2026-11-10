# Calling a device manager's delegate

How a `PumpManager` or `CGMManager` calls its delegate (`PumpManagerDelegate`, `CGMManagerDelegate`
and the `DeviceManagerDelegate`, `AlertIssuer` and `PersistedAlertStore` they inherit), and what the
delegate may assume.

There is no delegate queue. Managers used to call their delegate on a `delegateQueue` the app set,
and delegates relied on being called there. Now the delegate decides where its own work runs, and the
manager doesn't need to know.

## What the delegate may assume

- **Any context.** A call can arrive from any thread or actor. A delegate that keeps its state on
  the main actor declares its methods `@MainActor` (or the whole type), and Swift moves each call
  there; it doesn't check which queue it is on.
- **In order.** A manager awaits each async call before it makes the next one, so the delegate
  sees events in the order they happened: an alert before the pump event that records it, the
  reservoir value before the pump events from the same read.
- **Done means done.** When an async call returns, the delegate has finished with it. When
  `hasNewPumpEvents` returns the events are stored, and when it throws they are not.

## What the manager must do

- **Await delegate calls, one at a time.** Don't start a separate `Task` for each call: two
  unrelated tasks can run in either order. A manager using `WeakSynchronizedDelegate` gets this
  from `notify`, which runs each block after the ones passed before it:

  ```swift
  pumpDelegate.notify { delegate in
      await delegate?.issueAlert(alert)
      try? await delegate?.pumpManager(self, hasNewPumpEvents: events, lastReconciliation: lastSync, replacePendingEvents: false)
  }
  ```

  Await the task `notify` returns when the manager needs to wait for the block, for example to
  learn whether the events were stored.
- **Protect its own state.** Without a delegate queue nothing serializes the manager's own work
  for it. Whatever its code touches after an `await` must be safe from wherever that code resumes:
  keep state behind a lock, or isolate the manager (or the methods that touch it) to an actor.
  `delete()` is a common case: declared `async`, it runs off the main actor unless the manager
  says otherwise.
- **Ask questions with `call`.** `WeakSynchronizedDelegate.call` runs its block right away rather
  than after earlier notifications, so a manager can ask its delegate something (for example
  `startDateToFilterNewData`) from inside a `notify` block without waiting on itself.

## Calls that aren't async

A few delegate members stay synchronous because they are sinks or fixed answers. The delegate must
answer these from any thread:

| Member | Why it is synchronous |
|---|---|
| `deviceManager(_:logEventForDeviceIdentifier:type:message:completion:)` | Logging from anywhere, including code that can't await. The delegate keeps entries in the order it receives them. |
| `deviceManager(_:recordAnalyticsEvent:properties:)` | Fire and forget. |
| `credentialStoragePrefix(for:)`, `supportsWatchDirectRead(for:)` | Fixed answers. |
| `PumpManagerDelegate.detectedSystemTimeOffset` | A stored value. |
| `pumpManager(_:didUpdate:oldStatus:)`, `cgmManager(_:didUpdate:)` | Shared with status observers, which still choose their queue in `addStatusObserver(_:queue:)`. When the delegate receives them, they come from any context, like the async calls. |

`automaticDosingEnabled` and `automatedTreatmentState` are `@MainActor`: they are read by the
manager's own UI.

## Status observers

Status observers aren't delegates. `addStatusObserver(_:queue:)` still takes the queue the observer
wants, and the manager calls the observer there.
