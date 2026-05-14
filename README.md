# Spex

Spex is an Elixir library for checking whether a system behaves like its specification.

It lets you describe expected behaviour as a labelled transition system, observe
real transitions at runtime or during tests, derive an implementation model from
those observations, and compare the result against the specification in terms of
behavioural equivalence. In this sense, Spex brings a portion of formal verification
theory to Elixir practice and can help you detect whether your implementation 
deviates from a given specification of a workflow or protocol.

## What Spex Does

Spex combines a few pieces into one workflow:

1. A DSL for defining specifications as labelled transition systems.
2. Runtime APIs for tracking instance lifecycles and observed transitions.
3. Persistent implementation model storage in `.spex` files.
4. Offline verification with `mix spex`.

This makes it possible to use Spex in two complementary ways:

- online, while your application is running,
- offline, by deriving models from tests and checking them afterwards.

## Typical Workflow

### 1. Define a specification

```elixir
defmodule MyApp.OrderSpec do
  use Spex.Specification,
    transition_timeout: 30_000,
    prune_timeout: %Duration{hour: 1},
    prunable_states: :terminal

  def_transition :new, :pay, :paid
  def_transition :paid, :ship, :shipped
  def_transition :paid, :cancel, :cancelled
end
```

### 2. Start Spex

You can either let Spex run as its own OTP application, or add it explicitly to
your supervision tree.

If you want explicit control, you can supervise:

- `Spex`
- `Spex.InstanceManager.SimpleInstanceManager`
- `Spex.InstanceManager.DistributedInstanceManager`

Example:

```elixir
children = [
  {Spex.InstanceManager.SimpleInstanceManager,
   impl_models_dir: "./spex_impl_models",
   dets_dir: "./spex_dets"}
]
```

If you choose to supervise Spex this way, you should configure the dependency 
with `runtime: false`.

### 3. Observe real behaviour

```elixir
Spex.init_instance!(MyApp.OrderSpec, :order_123)
Spex.transition!(:order_123, :pay, :paid)
Spex.transition!(:order_123, :ship, :shipped)
```

Spex records the observed transitions, updates the implementation model, and can
report deviations or timeouts through the specification error handler.

### 4. Check derived models offline

Spex can export implementation models as `.spex` files and verify them with the
Mix task:

```sh
mix spex
```

or:

```sh
mix spex path/to/impl_models
```

This is especially useful in CI or after a test suite has produced derived
models.

## Deriving ImplModels From Tests

One of the main use cases for Spex is deriving implementation models from test
execution and then validating them afterwards.

Use `Spex.Testing.prepare_for_test_suite/1` in your test setup:

```elixir
# test/test_helper.exs
Spex.Testing.prepare_for_test_suite(
  impl_models_dir: "./test_meta/impl_models/live"
)
```

Then run your tests as normal. After the suite finishes, Spex exports the
derived models. From there, `mix spex` becomes the verification step that tells
you whether the observed behaviour is still bisimilar to the specification.

## Why Branching Bisimilarity?

Spex does not just compare raw transition lists.

It uses branching bisimilarity, which is useful when implementations contain
internal transitions that should not count as observable deviations. This lets
you distinguish between:

- harmless internal implementation detail,
- genuine behavioural change.

That is the key idea behind the library: treat specifications as executable,
checkable behavioural contracts instead of static documentation.

## Theoretical Background

Spex is motivated by ideas from concurrency theory and behavioural semantics.

At a high level, the library treats a system as a labelled transition system
(LTS): a set of states connected by observable actions and, optionally,
internal steps. From there, the natural question is not just whether two
systems have the same implementation, but whether they exhibit the same
observable behaviour.

That is where behavioural equivalence comes in. In Spex, the main notion is
bisimilarity, and more specifically branching bisimilarity. This matters because
real systems often contain internal transitions that should not count as user-
visible deviations. Two implementations may differ operationally while still
being behaviourally equivalent.

You can also think of Spex as living near refinement checking:

- the specification defines allowed behaviour,
- the derived implementation model captures observed behaviour,
- the checker asks whether the implementation still refines the intent of the
  specification under the chosen equivalence notion.

Spex does not aim to be a full model checker or a theorem prover. The goal is
more pragmatic: bring a useful slice of formal behavioural reasoning into an
ordinary Elixir workflow.

If those topics are new to you, the most relevant search terms are:

- concurrency theory
- labelled transition systems
- behavioural equivalence
- bisimilarity
- branching bisimilarity
- refinement checking

## Documentation

The main documentation lives in the moduledocs and is intended to be published
with ExDoc.

The most important entry points are:

- `Spex` for high-level usage and integration
- `Spex.Specification` for defining specifications
- `Spex.InstanceManager` for manager behaviour and callbacks
- `Spex.InstanceManager.SimpleInstanceManager` for the single-node runtime
- `Spex.InstanceManager.DistributedInstanceManager` for the sharded runtime
- `Spex.Testing` for test integration
- `Mix.Tasks.Spex` for offline verification

Note that Spex is in its early stages. This documentation will be expanded and possibly rewritten in the near future, as it is in large parts AI-generated as of now, which I'm not a huge fan of, to be honest, but judged to be good enough for a first release.

## Installation

Add `spex` to your dependencies:

```elixir
def deps do
  [
    {:spex, "~> 0.1.0", hex: :lts_spex}
  ]
end
```

Note the `hex: :lts_spex`. The package name `:spex` itself was [already taken](https://hex.pm/packages/spex) (which I realised only after becoming attached to the name). However, since that package is unmaintained and not widely used, I decided to keep the namespace simply as `Spex`. The _lts_ prefix stands for _labelled transition system_.

If you plan to supervise Spex yourself, you can also choose a `runtime: false`
integration style and add `Spex` or one of the instance managers to your own
supervision tree explicitly.

## Credits

Spex uses a NIF written in Rust to perform the bisimilarity check. Concretely, the crate [`merc_reduction`](https://docs.rs/merc_reduction/1.0.0/merc_reduction/) is used. I want to thank [Maurice Laveaux](https://github.com/mlaveaux) for implementing this efficient tool and making it available!
