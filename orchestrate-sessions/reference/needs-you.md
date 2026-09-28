# Needs You page

A scheduler's long output buries the questions the owner must answer. The
Needs You page is a private artifact the owner keeps open: each decision is
a card with options, a recommendation and a default, and the owner answers
in place.

## Set up once per owner

Publish `assets/needs-you.html` with
`capabilities: {db: {}, comments: {}}`, and record its URL in the project
memory. The full `comments` grant is what lets **Save and tell Claude** wake
the scheduler; `composer_only` only opens a composer the owner has to type
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
in `meta/thread`), which wakes the scheduler.

## Reading answers

On that wake-up, and at every other wake-up: `ArtifactData query` on `q`
where `status == "answered"`. Act on each answer, reply in the thread and
resolve it, then delete the handled docs or leave them as history. To
withdraw a stale question, delete it. In chat, write one line ("2 new
questions in Needs You"), not the questions.

## Evidence

localvoxtral, 2026-09-28 22:02 UTC. The owner: "since you handle a lot of
agents, you produce a lot of output … sometimes your questions get buried in
the flow and I don't see them." The first version opened a comment composer
where the owner had to type "done"; the owner disliked it, and the page now sends
the comment itself. One question was stored with Paris time marked `Z` and
sorted wrong; hence `date -u`.
