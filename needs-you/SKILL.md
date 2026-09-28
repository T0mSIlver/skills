---
name: needs-you
description: "Put the decisions a long-running session needs from its owner on a private artifact page the owner keeps open, instead of burying them in chat: publish the page once, add each question as one database write with options, a recommendation and a default, and act when the owner saves an answer, which wakes the session. Use when the owner says questions get lost in the output, asks for a decision page, or when an orchestrator or other long-running session will need many owner decisions."
compatibility: Claude Code with the Artifact and ArtifactData tools and artifact runtime capabilities (db, comments).
---

# Needs You page

A long-running session's output buries the questions the owner must answer. The
Needs You page is a private artifact the owner keeps open: each decision is
a card with options, a recommendation and a default, and the owner answers
in place.

## Set up once per owner

Publish `assets/needs-you.html` (in this skill) with
`capabilities: {db: {}, comments: {}}`, and record its URL in the project
memory. The full `comments` grant is what lets **Save and tell Claude** wake
the session; `composer_only` only opens a composer the owner has to type
into. The first press asks the owner to allow comments once.

Never republish the page to change questions. Every change is one
`ArtifactData` write.

## Questions

One doc per question in collection `q`:

| Field | Meaning |
|---|---|
| `created` | real UTC from `date -u +%FT%TZ`; the page orders by it |
| `status` | `open`, or `answered` |
| `text` | the question |
| `context` | optional; URLs become links |
| `options` | optional list; with none, the owner writes an answer |
| `recommended` | must equal one option |
| `default` | what you do if the owner doesn't answer |

The page writes `answer`, `note` and `answeredAt` and sets `status:
answered`. It then sends one comment to Claude in a reused thread (its id is
in `meta/thread`), which wakes the session.

## Reading answers

On that wake-up, and at every other wake-up: `ArtifactData query` on `q`
where `status == "answered"`. Act on each answer, reply in the thread and
resolve it, then delete the handled docs or leave them as history. To
withdraw a stale question, delete it. In chat, write one line ("2 new
questions in Needs You"), not the questions.

`reference/evidence.md` holds the incident behind each rule.
