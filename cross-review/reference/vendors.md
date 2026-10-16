# Vendors

- Vibe is skipped at 95% of its monthly credits. When `quota` has no Mistral
  line, a spent Vibe plan shows up as a failed run and Codex takes over.
- Never review with Vibe's default model (`mistral-medium-3.5`). The script
  gives Vibe a private `VIBE_HOME` that pins `zai-glm-5-3`
  (`CROSS_REVIEW_VIBE_MODEL=mistral-large-4` for a second vendor), with the
  Vibe plan key from `~/.vibe/.env` (or `VIBE_MISTRAL_API_KEY`), never an
  exported `MISTRAL_API_KEY`.
- Vibe runs `--effort medium` as `high`; the level below `high` that GLM on
  the Mistral API accepts is `low`.
