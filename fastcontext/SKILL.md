---
name: fastcontext
description: fastcontext is your default code-exploration subagent — it greps, globs, and reads a repository for you and returns file:line citations, keeping that exploration out of your own context. Invoke it via bash before answering, editing, reviewing, or debugging code you are not already certain about, and whenever the answer needs more than one file or tracing logic across modules. When in doubt, run fastcontext first.
allowed-tools: Bash(fastcontext *), Bash(command -v fastcontext:*), Bash(echo:*)
compatibility: Requires the fastcontext CLI on PATH — install and configure it from https://github.com/T0mSIlver/fastcontext#installation
---

# fastcontext

!`command -v fastcontext >/dev/null 2>&1 || echo '> ⚠️ **fastcontext CLI not found on PATH.** Install and configure it before using this skill: https://github.com/T0mSIlver/fastcontext#installation'`

A read-only repository-exploration subagent. It searches and reads files in a **separate process**, then returns a compact `<final_answer>` block of `path:line` citations. Delegating to it keeps broad exploration out of your context window — you get the evidence, not the file dumps. It never edits; you act on what it finds.

## When to use

Run it **before** you answer/edit/review/debug code you're not already sure about:

- Understand or explain how something works
- Locate where a symbol or behavior is defined or used ("where is X?", "what calls Z?")
- Trace logic across files or layers (request → handler → service → DB)
- Assess blast radius ("what breaks if I change X?")

Prefer it over manual grep/glob/read chains whenever the answer spans more than one file.

## When NOT to use

- You already read the exact file this session
- A single obvious grep in one known file
- A pure write/generate task needing no exploration

## Usage

```bash
# Machine-readable: prints ONLY the <final_answer> citation block to stdout
fastcontext -q "<specific, detailed question>" --citation

# Large exploration (architecture, multi-module trace): give it more turns
fastcontext -q "<complex question>" --citation --max-turns 16

# Drop --citation to also get a prose explanation (more context, some noise)
fastcontext -q "<question>"
```

Output on **stdout**:

```
<final_answer>
src/app/router.py:42-58 (request validation)
src/app/service.py:10-33 (handler that calls it)
</final_answer>
```

Parse the `path:line-range` entries and **read only those spans** — that's the point.

## Notes

- **stdout = answer, stderr = diagnostics.** Read stdout; ignore stderr.
- Tuning belongs in your fastcontext config, not in each call. The only flag worth reaching for per-run is `--max-turns 16` on a large exploration.
- Treat cited ranges as **candidate evidence, not ground truth.** Ranges the model never opened are dropped, but it can still cite a real file at the wrong lines — open each span and confirm it actually answers your question before relying on it.
- **Negative claims are unreliable.** Positive citations are safe to open directly, but any "X does not exist / is not referenced" conclusion needs a direct grep before you act on it — fastcontext has reported a pattern absent from a file whose literal first entry was that pattern.
- **An empty `<final_answer>` block with exit `0` is a failed run, not a clean "nothing found".** It happens when citation validation drops every citation (e.g. the model cited paths with a bogus prefix) or the model answered in prose only. Re-ask with a rephrased or narrower question, or drop `--citation` to see the prose; treat "nothing found" as unproven until a direct grep agrees.
- The answer holds at most ~25 citations (a safety cap); ask a narrower question if you need more.
- **A nonzero exit code means the run failed** (e.g. the endpoint was unreachable); the error is on stderr and stdout stays empty. Exit `0` with a non-empty `<final_answer>` block is a good run — retry or fall back to manual exploration on a nonzero exit or an empty block.
- Ask specific questions; run several queries for a multi-part investigation.
