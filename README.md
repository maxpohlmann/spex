# Spex

[![Elixir CI](https://github.com/maxpohlmann/spex/actions/workflows/elixir.yml/badge.svg)](https://github.com/maxpohlmann/spex/actions/workflows/elixir.yml)

[\[Read this on hexdocs\]](https://hexdocs.pm/lts_spex)

Spex is a tool to check the correctness of implementations against specifications. Concretely, it provides ways to (1) define specifications, (2) derive implementation models, and (3) check these against each other w.r.t. behavioural equivalence.

In this way, it is an attempt to bring a practical slice of formal verification theory into Elixir practice, allowing you to be more confident in the correctness of your implementations and helping you catch bugs and prevent unintended behaviours, especially in complex, multi-step workflows and protocols, possibly with asynchronous steps and concurrency. 
You can think of it similar to a type system (or a layer above that), in that the annotations Spex requires you to provide can help you both to make your code more easily readable as well as to catch bugs early on; but instead of checking for type correctness, Spex checks for behavioural correctness.

The three primary concepts of Spex are specifications, instances, and implementation models: you define specifications, initialise instances of these specifications and record their state transitions, and from this the Spex engine derives an implementation model for the given specification.

More details on the formal concepts follow in the [Theoretical background](#theoretical-background) section below.

## How to use Spex (Quick start)

This section is a shortened version of the moduledoc of `Spex`. See there for details.

### Install, configure, and start Spex

Add Spex to your dependencies:

```elixir
def deps do
  [
    {:spex, "~> 0.1.1", hex: :lts_spex}
  ]
end
```

Please note the `hex: :lts_spex`.[^1] 
[^1]: The package name `:spex` itself was [already taken](https://hex.pm/packages/spex) (which I realised only after becoming attached to the name). However, since that package is unmaintained and not widely used, I decided to keep the namespace simply as `Spex`. The _lts_ prefix stands for _labelled transition system_ (see the [Theoretical background](#theoretical-background) section).

Optionally, add `:spex` to your [`.formatter.exs` file under `:import_deps`](https://hexdocs.pm/mix/main/Mix.Tasks.Format.html#module-importing-dependencies-configuration).

#### Configuration

The derived implementation models are stored in a custom format in a given folder. Ideally, this should be within the priv directory of your application (`:code.priv_dir(:your_app)`).

```elixir
config :spex, impl_models_dir: Path.join(:code.priv_dir(:your_app), "spex_impl_models")
```

### Define specifications

Specifications represent protocols or workflows and are modelled as graphs / state machines. The focus lies on the transitions (edges) rather than the states (nodes): when we compare an implementation model against its specification, their states can be entirely distinct, since behavioural equivalence is judged entirely based on their transition behaviours (basically: action sequences).

In the simplest case, you can create a specification as follows:

```elixir
defmodule YourApp.Specifications.Tree do
  @moduledoc """
  A specification that forms a small, simple tree structure:

               s0
              /  |
            a/    |a
            /      |
          s1       s2
          / |
        b/   |c
        /     |
      s3      s4

  """
  use Spex.Specification

  def_transition :s0, :a, :s1
  def_transition :s0, :a, :s2

  def_transition :s1, :b, :s3
  def_transition :s1, :c, :s4
end
```

Each _transition_ consists of a _from\_state_, an _action_, and a _to\_state_.

Specifications can have custom error handlers, to which any reported errors are passed for processing, e.g. logging and deciding which errors are okay.

### Observe transitions in your implementation

In your actual implementation code, you need to initialise instances of your specification and record transitions.

As a useless toy example, say we manage a pine forest where each pine has a number. We offer a function for planting a seedling:

```elixir
alias YourApp.Specifications.Tree

def plant_seedling(pine_id) do
  specification = Tree
  instance_identifier = {Tree, pine_id}
  meta = %{planting_datetime: DateTime.utc_now()}
  initial_state = :seedling

  Spex.init_instance(specification, instance_identifier, meta, initial_state)
end
```

Note that the instance identifier is an arbitrary term that uniquely identifies the instance across all specifications (hence it can make sense to include the specification module). The meta can optionally be added to make possible error reports regarding the instance more useful. The initial state is also optional and defaults to the specification's initial state.

After an instance is initialised, we can record its transitions with `Spex.transition(instance_identifier, action, new_state)`:

```elixir
def pour_onto(pine_id, :water), do: Spex.transition({Tree, pine_id}, :a, :sapling)
def pour_onto(pine_id, :oil), do: Spex.transition({Tree, pine_id}, :a, :withered)
def observe_growth(pine_id), do: Spex.transition({Tree, pine_id}, :__internal__, :mature_tree)
def cut_down(pine_id), do: Spex.transition({Tree, pine_id}, :b, :lumber)
def burn(pine_id), do: Spex.transition({Tree, pine_id}, :c, :ash)
```

As mentioned above, the states do not have to match the specification states. The actions, however, do need to match, as these are what the behavioural equivalence is judged on. 

An exception to this and a useful addition is the `__internal__` action, which can be used to record internal state transitions that are not part of the specification but that you still want to be recorded in the implementation model. These are ignored (or rather: treated specially) for the behavioural equivalence checks.

### Derive implementation models: in tests

Your tests should cover all possible transitions of your implementation, so we can use them to derive an implementation model. To do this, add the following to your `test_helper.exs`:

```elixir
Spex.Testing.prepare_for_test_suite()
```

This prepares the Spex engine to record all transitions from tests and write derived implementation models in the directory configured above.

In unit tests, we often construct our parameters to be in a certain state. When using `Spex.init_instance/4`, though, the given initial state is added as an initial state of the implementation model, which we don't want in these cases. To construct an instance in a certain state without affecting the implementation model, there is `Spex.Testing.mock_instance!/4`. In a test for our pine forest above, you might do something like this:

```elixir
alias YourApp.Specifications.Tree

Spex.Testing.mock_instance!(Tree, {Tree, 1}, :mature_tree)

assert YourApp.Pine.cut_down(1) == :ok
```

Since `cut_down/1` calls `Spex.transition({Tree, pine_id}, :b, :lumber)`, this test would add a transition from state `:mature_tree` with action `:b` to state `:lumber` to the implementation model.

### Check behavioural equivalence: offline

After implementation models have been derived and stored, you can run `mix spex` (see `Mix.Tasks.Spex`) to check whether they are behaviourally equivalent. Currently, the output only tells you _if_ an implementation model is not behaviourally equivalent to its specification and you are required to analyse the model to understand why.

### Check behavioural equivalence: online

Once you have derived implementation models that were deemed behaviourally equivalent to their specification, you are ready to use Spex in production. Every time you initialise and instance or record a transition, it is checked whether the initialisation or transition is part of the implementation model. If it is, all is well. If it isn't, a behavioural equivalence check on the resultant model against the specification is run. In any case, an `%Spex.Errors.InstanceError{}` is reported, either with `:reason` being `:deviation_still_equivalent` or `:deviation_not_equivalent`. It is up to your specification's error handler to handle these cases accordingly (e.g. log the occurrence but still return `:ok` in the `:deviation_still_equivalent` case; this is what the default error handler does). The reason is that even deviations that don't break the equivalence hint at scenarios your tests don't cover. You can then fix these reports in the future by adding a test that covers the transition or by adding the transition manually to your implementation model. 

## Theoretical background

Spex is motivated by ideas from concurrency theory and behavioural semantics. It is intended to be a light form of a refinement checker that does not require complex, static code analysis or manual proofs.

The primary theoretical model in Spex is that of _labelled transitions systems_ (LTSs): an LTS consists of a set of states and a set of transitions between those states, each transition being labelled by an action. The possible sequences of actions an LTS allows describe the behaviour of the system it models, roughly speaking. The idea behind Spex is that both specifications as well as implementation models can be described through LTSs. 

_Bisimilarity_ is a way to compare two LTSs and to deem them behaviourally equivalent based on these action sequences. The concrete definition of behavioural equivalence used by Spex is called _branching bisimilarity_. This is a relation between two LTSs that considers them equivalent if they can simulate each other's behaviour, while allowing for some flexibility in terms of internal transitions. The idea is that two systems are considered equivalent if they can perform the same sequences of observable (i.e. non-internal) actions, even if they may differ in their internal workings or states.

To learn more about the theory, you might start by going to the Wikipedia page for any of the terms above. You might also read the sections 2.1 and 2.2 of my [Bachelor's thesis](https://maxpohlmann.github.io/Reducing-Reactive-to-Strong-Bisimilarity/thesis.pdf) (skipping the _Isabelle_ sections, which formalise the notions in the Isabelle theorem prover). (The main part of the thesis is not related to Spex.)

The particular form of bisimilarity used by Spex is branching bisimilarity. To learn more about it, you can read e.g. the following paper:

> Van Glabbeek, R.J., Weijland, W.P.: Branching time and abstraction in bisimulation semantics. JACM 43(3), 555–600 (1996). https://doi.org/10.1145/233551.233556

Here is the paper describing the algorithm Spex uses under the hood for determining branching bisimilarity:

> Martens, J., Laveaux, M. (2026). Faster Signature Refinement for Branching Bisimilarity Minimization. In: Junges, S., Katz, G. (eds) Tools and Algorithms for the Construction and Analysis of Systems. TACAS 2026. Lecture Notes in Computer Science, vol 16505. Springer, Cham. https://doi.org/10.1007/978-3-032-22752-2_23

The algorithm was implemented in Rust in the crate [`merc_reduction`](https://docs.rs/merc_reduction/1.0.0/merc_reduction/) and used in Spex through a NIF. I want to thank [Maurice Laveaux](https://github.com/mlaveaux) for implementing this tool and making it available!

---

This readme file has been written without the use of AI. The code and other documentation were written partially AI-assisted.