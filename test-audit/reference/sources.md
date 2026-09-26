# Sources

This skill merges and adapts rules from these skills. Where they disagree on
TDD process (superpowers refactors inside the red/green loop, Pocock keeps
refactoring for review), this skill takes no side: it covers what a test must
prove, not when to write it.

| Source | Taken from it |
|--------|---------------|
| [openclaw/openclaw `.agents/skills/test-audit`](https://github.com/openclaw/openclaw/tree/5f3781df412caf60e3258428cf0bb7e406f19a76/.agents/skills/test-audit) | The gate's owner and seam questions, junk patterns, retention bar, candidate evidence, audit workflow, campaign |
| [obra/superpowers `test-driven-development/writing-good-tests.md`](https://github.com/obra/superpowers/blob/main/skills/test-driven-development/writing-good-tests.md) | Bug-or-decision question, change detectors, framework and trivial-code rules, mock rules, mutation check |
| [mattpocock/skills `engineering/tdd`](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md) | Tautological expected values, refactor-survival as the test for implementation coupling |
| [docling-project/docling `AGENTS.md`](https://github.com/docling-project/docling/blob/main/AGENTS.md) | Tests that only validate the agent's own new helper |

## Licenses

All four are MIT. The notices of the two sources this skill copies
substantial text from:

- Copyright (c) 2026 OpenClaw Foundation
- Copyright (c) 2025 Jesse Vincent

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to
> deal in the Software without restriction, including without limitation the
> rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
> sell copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
> FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
> DEALINGS IN THE SOFTWARE.
