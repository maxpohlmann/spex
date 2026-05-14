# spex v0.1.0 - API Reference

## Modules

- [Spex](Spex.md): Entry point for Spex runtime APIs and high-level integration.
- [Spex.Application](Spex.Application.md): Application entrypoint for starting the Spex supervision tree.

- [Spex.BisimilarityChecker](Spex.BisimilarityChecker.md): Compares implementation models against specifications via branching bisimilarity.

- [Spex.BisimilarityChecker.MercWrapper](Spex.BisimilarityChecker.MercWrapper.md): Rust NIF wrapper used to execute bisimilarity checks.

- [Spex.Errors](Spex.Errors.md): Error types used across Spex runtime and persistence boundaries.

- [Spex.Errors.FileError](Spex.Errors.FileError.md): Alias type wrapper for file-system errors represented by `File.Error`.

- [Spex.Errors.Template](Spex.Errors.Template.md): Macro for defining Spex exception modules with typed reasons and context.

- [Spex.ImplModel](Spex.ImplModel.md): Represents the observed implementation model built from runtime transitions.

- [Spex.ImplModelStore](Spex.ImplModelStore.md): Loads and persists implementation models in `.spex` file format.

- [Spex.InstanceManager](Spex.InstanceManager.md): Behaviour contract plus shared helpers for Spex instance managers.

- [Spex.InstanceManager.DistributedInstanceManager](Spex.InstanceManager.DistributedInstanceManager.md): Instance manager that shards instances across multiple
`Spex.InstanceManager.Server` processes.
- [Spex.InstanceManager.DistributedInstanceManager.DistributionFactorState](Spex.InstanceManager.DistributedInstanceManager.DistributionFactorState.md): Agent storing the configured distribution factor.

- [Spex.InstanceManager.Instance](Spex.InstanceManager.Instance.md): Runtime representation of a specification instance and its observed history.

- [Spex.InstanceManager.InstanceStore](Spex.InstanceManager.InstanceStore.md): Abstraction layer for instance storage using DETS.

- [Spex.InstanceManager.Server](Spex.InstanceManager.Server.md): Core GenServer that manages instances and implementation-model observation.
- [Spex.InstanceManager.SimpleInstanceManager](Spex.InstanceManager.SimpleInstanceManager.md): Single-node instance manager backed by one `Spex.InstanceManager.Server` process.
- [Spex.Specification](Spex.Specification.md): Behaviour and DSL for defining specifications through labelled transition systems (LTSs).
- [Spex.Testing](Spex.Testing.md): Test helpers for preparing and manipulating Spex runtime state.

- Exceptions
  - [Spex.Errors.DetsError](Spex.Errors.DetsError.md): DETS backend operation errors.

  - [Spex.Errors.ImplModelError](Spex.Errors.ImplModelError.md): ImplModel loading and lookup errors.

  - [Spex.Errors.InstanceError](Spex.Errors.InstanceError.md): Instance lifecycle errors such as duplicate or missing identifiers.

  - [Spex.Errors.TransitionError](Spex.Errors.TransitionError.md): Transition-level error used for deviations and timeout conditions.

## Mix Tasks

- [mix spex](Mix.Tasks.Spex.md): Mix task that checks saved implementation models for bisimilarity.

