# Pi Calm mode

Calm is a Pi-only conversation presentation toggle.
It is off by default, and the last `/calm` choice persists for the effective Firstmate home across Pi session starts and resumes.

While Calm is active and an agent run is under way, Calm hides Pi's built-in `Working...` row and shows a small two-row animated boat in its place, and no separate Calm status row is added.
The default `classic` animation is the original directional ASCII boat, with a `<|` or `|>` sail over a `\\__/` hull and a short blue repeating ripple.
Set the home-local `config/calm-animation` preference to `swell` and reload Pi to select the newer animation.
The `swell` animation fills the usable width with low one-cell Unicode bars, all in standard ANSI blue, so the swell shows through bar height alone.
Its asymmetric three-cell `◿│◣` sail is centered over the five-cell `╲▁▁▁╱` hull, and the whole boat, both sail halves, mast, and hull, is one standard ANSI yellow, with the hull's zero-height interior keeping the swell continuous beneath the boat.
Both animations move the boat one column every 880ms while animating their water every 220ms.
The newer animation's deterministically varied half-waves stay between nine and thirteen cells, and the boat remains phase-locked inside a broad zero-height trough through movement and edge reversals.
Every resize reflows the selected sprite without wrapping, and it disappears when the run settles, aborts, or fails.
Within one Pi session and Calm extension lifetime, the next working period resumes the boat from its last rendered column and travel direction rather than restarting at the left edge.
Hidden elapsed time does not advance the animation, and a resize while hidden clamps the frozen boat to the new width without changing its valid travel direction.
A fresh Pi session or new Calm extension lifetime starts at the normal initial position.
Very narrow terminals fall back to a smaller deterministic sprite.
While Calm is off, Pi's stock working row is left exactly as Pi renders it.
Calm hides assistant reasoning, the shells for the Pi built-in tool names Calm owns, the `fm_watch_arm_pi` and `fm_branch_outcomes` tool shells, and canonically classified Firstmate operational user rows.
Calm keeps mid-turn assistant working notes visible: they are the narration a model emits alongside its tool calls, and the captain relies on that narration to see what an agent is actually doing.
A mid-turn working note is assistant text in a message the model did not end its response with, identified by that message's own `stopReason` of `toolUse`, or of `length` with tool calls present.
The genuine reply that ends a response also stays visible, exactly like a working note.
Calm guarantees reasoning is not displayed while it is on: it removes every thinking block from the live transcript presentation whatever Pi's own `hideThinkingBlock` setting says.
Calm manages that setting's effect itself rather than depending on the captain having set it, and never writes the setting, so turning Calm off, including after a restart or reload with Calm on, restores exactly the value the captain had.
Pi's thinking toggle still changes and saves the captain's own setting while Calm is on, but it cannot reveal reasoning, and its confirmation reports the new state as applying once Calm is off, for example `Thinking blocks: visible once Calm is off; Calm keeps reasoning hidden`.
The guarantee is implemented by presentation, so it depends on Calm's collapsed-thinking patch point in Pi remaining available; if Pi removes that seam, Calm logs a diagnostic and skips only that adapter, as described under [Pi compatibility](#pi-compatibility).
The reasoning remains in the message, model context, session storage, and `/export` artifacts.
The operational inputs Calm classifies remain ordinary user-role messages, while Pi's transcript layout renders their complete rows at zero height.
The session-start nudge remains on its existing non-displayed custom-message path.

Outside Pi's same-name built-in override collision described below, Calm changes presentation only.
Calm's built-in wrappers preserve Pi's execution behavior, and input delivery, ordering, model context, session storage, diagnostics, and `/export` and `/share` operation remain unchanged.
Every hidden Firstmate input remains available to the model and in serialized session data and exported artifacts.
Legacy operational custom messages remain in session data and Pi's sidebar tree, although the main HTML transcript may omit them.
Toggling Calm off restores ordinary rendering, and `Ctrl+O` expansion state is preserved.

Pi's supported presentation API does not expose a global transcript filter.
Built-in tool images, user-bash rows, skill and summary rows, generic status notices, and other arbitrary custom-tool or extension rows remain visible.
These are supported-API boundaries rather than hidden-content failures.

## Pi compatibility

Calm has no numeric Pi version minimum or maximum and never refuses Pi solely because its version is newer than a previously verified version.
The collapsed-thinking, thinking-toggle, and operational-user-row presentation adapters probe the exact Pi API seam they patch when Calm loads.
If Pi removes one of those seams, Calm logs a diagnostic naming the unavailable adapter and skips only that adapter; `/calm`, the other adapters, and unrelated Pi extensions remain available.

Calm's built-in tool presentation (`bash`, `read`, `edit`, `write`, `grep`, `find`, `ls`) shares Pi's single, unmerged override slot per name with any other extension that overrides the same tool.
While the persisted Calm preference is off, Calm registers none of those overrides and therefore contests no built-in tool name.
The first time Calm turns on in a session that started off, it claims every built-in name no other extension already owns, leaves every contested tool intact and callable, and displays a prominent warning naming the tools it skipped.
Tool-call rows already on screen before that first toggle do not retroactively collapse; later rows for the names Calm claimed use Calm presentation.
When a session starts or reloads with Calm already on, Calm must instead register all seven overrides synchronously so Pi can render restored rows with them.
Pi provides no ownership check early enough for that load-time path, and the first registrant wins the complete tool definition.
If the other extension wins, a session-start console diagnostic names the tool and winning extension; if Calm wins, Pi does not expose the losing registration, so the other extension's override is unavailable and cannot be named.

[`calm-mode-feasibility.md`](calm-mode-feasibility.md) owns the version-scoped renderer taxonomy, built-in override constraints, and empirical evidence.
[`configuration.md`](configuration.md#pi-calm-preference-configcalm) owns the persisted preference file and resolution rules.
`.pi/extensions/lib/fm-calm-visibility.ts` owns the visibility policy, `.pi/extensions/lib/fm-calm-operational-user-layout.ts` owns the zero-height operational-user row adapter, and `.pi/extensions/lib/fm-calm-working-ship.ts` owns the animated working presentation.

Regression entry points:

```sh
tests/fm-calm-pi-extension.test.sh
tests/fm-pi-branch-extension.test.sh
tests/fm-pi-primary-types.test.sh
FM_PI_LIVE_E2E=1 tests/fm-pi-primary-live-e2e.test.sh
```
