---
name: blast-radius
description: "Before a PR is ready, write what the change could break beyond its diff, visually and functionally, on each platform the repo ships, the one fact it is safe because of, and the cheapest proof for each risk with how far that proof got. The output is the PR body's Blast radius section, which the verifier and reviewers check; a surface it misses is a finding. Use when finishing any change to an app, server, shared package, wire format or data, for 'blast radius', 'what could this break', and when reviewing a PR's blast radius."
---

# Blast radius

Listing callers is not the job; grep does that in a second. The job is the
breakage grep won't show. A writeup that sounds right reads the same whether
or not it's true, so the one fact the change's safety rests on gets proved
by running code, not by prose.

## How far a proof got

Take each fact as far down this ladder as is cheap, and say where it stopped:

1. **Said so.** Worth nothing on its own.
2. **Pointed at the line.** A real `file:line`, or the library's source at
   the pinned version.
3. **Walked the failure.** Step by step, the bad case doesn't reach.
4. **Ran it.** A script or test that calls the real code and fails loud if
   you're wrong.
5. **Reproduced it in the app.** Driven like a user would (the repo's
   `verify-<app>` skill).

## Steps

1. **What it does.** The diff, the symbols it adds, changes and deletes,
   and what now behaves differently that the diff doesn't spell out: a
   default, an order, a value now stored, a string every client shows.
2. **Platforms.** Name each one the change reaches, from the repo's
   AGENTS.md (Android, iOS, web, desktop, CLI, server…). A shared package,
   design token, strings file or protocol type reaches every platform that
   imports it. "All" is not an answer: the verifier drives each by name.
3. **Visual risks,** per platform: anything that renders. Copy, layout,
   styles, assets and icons, locale (dates, times, plurals, long
   translations), themes, screen sizes and font scaling, and the element's
   peers on the same screen.
4. **Functional risks:** behaviour, data, wire format, timing. Follow what a
   symbol search misses: the JSON an API returns, a DB column, stored data
   from older versions, another language reading the same bytes, a feature
   flag, teardown and lifecycle order, code three hops downstream, the
   library's own source at its pinned version and any local patch.
5. **The one fact it's safe because of.** Most risky-looking changes are
   safe because of one fact ("this call only drops cache entries that are
   already dead"). Find it; if it holds, most risks clear at once. Prove it
   to rung 4 when you can: usually one small script that imports what the
   app ships and calls the exact function in question.
6. **Each risk gets its cheapest proof:** a type check or existing test, a
   new script against real code, the CI screenshot diff or e2e suite (they
   run on every PR touching an app or the server; name the job), and the
   real app only when nothing cheaper would catch it.
7. **Clear what you checked.** A search that finds nothing is an answer;
   cite it.

## The PR body section

```markdown
## Blast radius

**Does:** <one or two lines, including what the diff doesn't spell out>
**Safe because:** <the one fact>. <rung>: <run link, test, or file:line>

| Risk | Platforms | Kind | Proof | Got to |
|---|---|---|---|---|
| <how it breaks> | Android, web | layout | CI screenshot diff, <job link> | ran it |

**Cleared:** <surface>: <why it's fine, file:line>
**Not checked:** <what, and why>
```

Kind is one of the charter's words: copy, layout, style, asset, locale,
behaviour, data, wire format, timing. `verify` tallies verdicts by it.

## Reviewing a blast radius

List the surfaces the diff reaches; each one the section doesn't name is a
finding, as is a risk whose proof stops at "said so". Put the section in
the `cross-review` brief so the reviewer checks it too.

## Gotchas

- **Non-UI changes break visuals:** a renamed string key, a token, a font
  or icon library bump, a date format, the version shown in About. These
  are the surfaces authors miss most.
- **Hypotheticals with no path** ("what if null") bury the real risks.
  Keep only risks with a way to happen; trace the caller before listing one.
- **A proof that passes on main too** proves nothing about the change. For
  a bug fix, show it failing on main first.
- **Public PR body:** write it through `unslop`, and strip machine names,
  paths and tokens.
