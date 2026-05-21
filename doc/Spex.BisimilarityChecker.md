# `Spex.BisimilarityChecker`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/bisimilarity_checker.ex#L1)

Compares implementation models against specifications via branching bisimilarity.

# `bisimilar_to_specification?`

```elixir
@spec bisimilar_to_specification?(Spex.ImplModel.t()) :: boolean()
```

Compares an ImplModel against its Specification using bisimilarity checking.

Returns `true` if the implementation model is bisimilar to the specification, `false` otherwise.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
