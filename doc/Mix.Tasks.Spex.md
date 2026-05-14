# `mix spex`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/mix/tasks/spex.ex#L1)

Mix task that checks saved implementation models for bisimilarity.

This is the offline verification entry point for `.spex` model files.

# `run`

Runs Spex bisimilarity checks for all loaded implementation models.

Accepts either no arguments (uses configured `:impl_models_dir`) or one path
argument to a directory or file containing `.spex` models.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
