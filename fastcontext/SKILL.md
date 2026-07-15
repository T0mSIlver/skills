---
name: fastcontext
description: fastcontext is your default code-exploration subagent — it greps, globs, and reads a repository for you and returns file:line citations, keeping that exploration out of your own context. Invoke it via bash before answering, editing, reviewing, or debugging code you are not already certain about, and whenever the answer needs more than one file or tracing logic across modules. When in doubt, run fastcontext first.
allowed-tools: Bash(fastcontext *), Bash(command -v fastcontext:*), Bash(echo:*)
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

# Harder traces / architecture: allow more exploration turns (default 4)
fastcontext -q "<complex question>" --citation --max-turns 8

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
- Cited ranges are validated — line ranges the model never actually opened are dropped, so what you get is safe to open directly.
- **Exit code is 0 even on failure.** If stdout contains `LLM API call failed`, the run failed — retry or fall back to manual exploration.
- Ask specific questions; run several queries for a multi-part investigation.
