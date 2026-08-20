#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["skills-ref==0.1.1"]
# ///
"""Validate skill directories against the Agent Skills spec, with Claude Code's
frontmatter extensions accepted.

skills-ref (the official Anthropic validator, github.com/anthropics/agentskills)
rejects any frontmatter key outside the spec. Claude Code defines extra keys
that skills legitimately use — and that vendored skills use verbatim — so this
wrapper adds them to the validator's allowlist before running it. Everything
else the validator checks (name, description, lengths, directory match) still
applies unchanged.

Usage: scripts/validate-skills.py [DIR ...]
With no DIR, every top-level directory containing a SKILL.md is validated.
Exit 1 if any skill fails or no skill was found.
"""

import sys
from pathlib import Path

from skills_ref import validate
from skills_ref import validator

# Frontmatter keys Claude Code reads from SKILL.md beyond the Agent Skills
# spec: https://code.claude.com/docs/en/skills#frontmatter-reference
# Only the key is accepted; the values of these fields are not validated.
CLAUDE_CODE_FIELDS = {
    "agent",
    "argument-hint",
    "arguments",
    "background",
    "context",
    "disable-model-invocation",
    "disallowed-tools",
    "effort",
    "hooks",
    "model",
    "paths",
    "shell",
    "user-invocable",
    "when_to_use",
}

validator.ALLOWED_FIELDS |= CLAUDE_CODE_FIELDS


def main(argv: list[str]) -> int:
    repo = Path(__file__).resolve().parent.parent
    if argv:
        dirs = [Path(a) for a in argv]
    else:
        dirs = sorted(p.parent for p in repo.glob("*/SKILL.md"))
    if not dirs:
        print("No SKILL.md found in any top-level directory", file=sys.stderr)
        return 1

    failed = 0
    for skill_dir in dirs:
        errors = validate(skill_dir)
        if errors:
            failed += 1
            print(f"Validation failed for {skill_dir.name}:")
            for err in errors:
                print(f"  - {err}")
        else:
            print(f"Valid skill: {skill_dir.name}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
