---
name: intent-card
description: "Ask the owner before code, on one card, when a change needs their call: a new feature or a change in what one does, UX (layout, flow, motion, look, icons), architecture (a new component, dependency, protocol or data model, anything hard to undo), copy on the landing page, README or store listing. Covers one question, two shapes and a pick, the lightest medium that shows them (mockups, a video of the motion, a tappable prototype only when flow or data needs it), architecture as two sketched shapes designed in from the start, and what to do when Starbridge is unavailable. Use before writing code for any of those, and when a debt review proposes a redesign."
---

# Intent card

The `owner-charter` list decides whether a change needs a card; everything
below it, decide yourself and say so after. A question you can settle by
checking (a fact, a measurement, a quick prototype) is never a card.

## Happy path

1. **Check what's open.** `starbridge decisions --open`, and the issue's
   comments. If the owner already answered or is being asked, use that.
2. **Ground it.** Read the code, spec and screens the change touches, whole.
   Write down the constraints both options must meet: callers you can't
   break, data already stored, the look of the screen's neighbours.
3. **Find the one question.** Two related choices become one question whose
   options combine them. A second, independent question is a second card.
4. **Make two shapes, then pick.** Two structurally different answers, not
   one answer with a different parameter: where state lives, which component
   owns it, which screen hosts it, what the user does first. Design each as
   if the requirement had been there from the start: what would you build
   from scratch knowing it? Name what each costs (lines, new dependencies,
   taps, what it leaves behind) and pick one.
5. **Show it in the lightest medium:**
   - Copy: the text itself, before and after.
   - A static UI change: one mockup per option, same frame, same data, real
     size, built from the app's own screen or components.
   - Motion: a short video per option, plus 3–4 frames as images so the
     card shows it without opening the link.
   - A flow, or data the owner has to try: a tappable prototype (a claude.ai
     artifact), only then.
   - Architecture: per shape, the caller's usage first, then types and
     signatures with `not implemented` bodies
     ([reference/sketch.md](reference/sketch.md)). Screen both against
     [reference/design-red-flags.md](reference/design-red-flags.md).
6. **Look at every image and video yourself** before attaching it. Say on the
   card what differs between them, in numbers ("9 rows per screen instead
   of 6").
7. **Post it** with the `starbridge` skill: the two shapes as options, your
   pick `--recommended`, one image per option in option order, the sketch or
   video by `--link`.
8. **Don't wait.** Build what both shapes share. Never write code that only
   one shape needs before the answer.
9. **Record the answer** where the repo keeps decisions (its spec, decision
   records, or the issue), with the card id. The PR links it; `verify` and
   `merge-queue` check the change against it.

## When Starbridge is unavailable

`starbridge` missing, unpaired or failing (common in a cloud session): put
the same card (question, options with costs, your pick, images, links) in a
comment on the issue, ask in chat pointing at it, and say that Starbridge
failed and why. Carry on with step 8.

## Gotchas

- **The bolt-on looks cheaper.** Reusing the current shape skips work today
  and leaves a special case, a flag or a second way. Cost both shapes with
  what each leaves behind; the from-scratch shape shows what it deletes.
- **Mockups drawn from nothing drift** from the app's spacing, type and
  icons, and the owner judges the drift instead of the change. Start from a
  screenshot or the real components. Use the same crop for both options,
  and both themes when the change touches colour.
- **Cards show images small on a phone.** Crop to the changed region and
  enough of its neighbours to judge alignment.
- **Motion in stills hides the timing.** Frames go on the card; the video
  link is what the owner judges.
- **A prototype for a static change** costs hours and the owner's time to
  open it. Mockups first.
- **Free-text answers** may describe a third shape. Build that one; ask again
  only if it leaves the choice open.

## Not possible

- Video on a card: Starbridge takes PNG or JPEG only. Put the video in a
  claude.ai artifact or on a branch of the repo and link it.
