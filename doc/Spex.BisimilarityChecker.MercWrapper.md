# `Spex.BisimilarityChecker.MercWrapper`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/bisimilarity_checker.ex#L6)

Rust NIF wrapper used to execute bisimilarity checks.

# `compare_bisimilarity`

```elixir
@spec compare_bisimilarity(impl_data, spec_data) :: boolean()
when impl_data: {[Spex.transition()], Spex.state()},
     spec_data:
       {[Spex.state()], [Spex.action()], [Spex.transition()], Spex.state()}
```

Compares implementation and specification LTS data for branching bisimilarity.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
