# `mix spex`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/mix/tasks/spex.ex#L1)

Mix task that checks saved implementation models for behavioural equivalence.

This is the offline verification entry point for `.spex` model files.

# `run`

Runs Spex behavioural equivalence checks for all loaded implementation models.

Accepts either no arguments (uses configured `:impl_models_dir`) or one path argument to a
directory or file containing `.spex` models.

If an implementation model is found to be not behaviourally equivalent to its specification, a
warning is logged and the task exits with status code 1. Currently, it is not possible to give
information about _why_ they are not equivalent. It is up to the developer to analyse the
implementation model and compare it to its specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
