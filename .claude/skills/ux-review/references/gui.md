# GUI and Web Checklist

Read after Step 2 of the core workflow, when the medium is gui.

These are defaults for a surface with mixed drivers. When Step 0 named a single expert driver, an item here can be the wrong trade; name the item you are overriding and why, rather than skipping it silently.

For a screen, the invocation from Step 1 is the click path: every action the user must take, in order, to finish the task. Count the steps and count the decisions. Both are costs.

## Task flow

- The primary action on any screen is identifiable in one second, without reading everything.
- The number of steps matches the difficulty of the task. An easy task behind five screens is a finding.
- Nothing is required of the user that the system already knows.
- Options hardcoded in the front end for data the backend owns will disagree with the backend eventually, and the user meets that disagreement as a failed submit.
- The user can leave and come back without losing work.
- Every dead end offers a way forward, not just an explanation of the wall.

## State coverage

Check all five. Missing states are the most common defect in shipped UI, because development happens against populated happy-path data.

| State | Check |
|---|---|
| Loading | Is there feedback within a few hundred milliseconds, and does layout stay stable when data arrives? |
| Empty | Does a first-time user see guidance, or a blank rectangle? |
| Partial | Does one failed section leave the rest usable? |
| Error | Does the message say what to do next, and can the user retry in place? |
| Success | Does the user know it worked, and what to do now? |

Also check the edge content: longest realistic string, zero items, one item, thousands of items. Test with real content. Lorem ipsum hides information architecture problems.

## Feedback and interaction

- Every action acknowledges within about 100ms, even if the result takes longer.
- Destructive actions are confirmable or undoable. Undo beats confirm where it is feasible.
- Nothing moves or resizes under the pointer between the user deciding to click and clicking.
- Transitions serve orientation and stay under roughly 300ms. Animation the user waits on is a cost, not delight.
- Forms validate at a moment the user can act on, and never discard input on failure.

## Accessibility minimum

These five are in scope by default because each one blocks real users and each one is cheap to check. A full WCAG 2.1 AA audit is a separate, explicit request; do not attempt one here.

1. Every input has a programmatic label, not just adjacent placeholder text.
2. Everything actionable is reachable and operable by keyboard alone. Tab through the whole flow once.
3. Focus is always visible and its order matches the visual order. Focus is never trapped, and modals return focus on close.
4. Text and meaningful UI elements meet 4.5:1 contrast. Never carry meaning by color alone.
5. Touch targets are large enough to hit on a phone, with spacing between adjacent ones.

Icon-only controls need an accessible name, and the decorative part must be hidden from assistive tech:

```html
<button aria-label="Close dialog" aria-describedby="close-hint">
  <svg aria-hidden="true"><!-- icon --></svg>
</button>
<span id="close-hint" class="sr-only">Press Escape to close</span>
```

## Common findings to look for

| Symptom | Usual fix |
|---|---|
| Users ask "did it save?" | Add explicit success feedback |
| Blank screen on first use | Design the empty state as onboarding |
| Layout jumps as data loads | Reserve space, use skeletons |
| Error tells the user to contact support | Say what failed and offer a retry |
| Mouse-only affordance such as hover-reveal | Give it a keyboard and touch path |
| Placeholder used as the only label | Add a real label |
