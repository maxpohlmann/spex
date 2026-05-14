use merc_lts::{LabelIndex, LabelledTransitionSystem, StateIndex};
use merc_reduction::{compare_lts, Equivalence};
use merc_utilities::Timing;
use rustler::{Atom, Env, NifResult};
use std::collections::HashMap;

mod atoms {
    rustler::atoms! {
        __internal__
    }
}

// Rust representations of the Elixir data structures
#[derive(Debug)]
struct LtsData {
    states: Vec<Atom>,
    actions: Vec<Atom>,
    transitions: Vec<(Atom, Atom, Atom)>, // (from_state, action, to_state)
    initial_state: Atom,
}

// Use DirtyCpu scheduler, because bisimilarity checking can be CPU intensive and we don't want to block the scheduler.
#[rustler::nif(schedule = "DirtyCpu")]
fn compare_bisimilarity(
    env: Env,
    impl_data: (Vec<(Atom, Atom, Atom)>, Atom), // (transitions, initial_state)
    spec_data: (Vec<Atom>, Vec<Atom>, Vec<(Atom, Atom, Atom)>, Atom), // (states, actions, transitions, initial_state)
) -> NifResult<bool> {
    let (spec_states, spec_actions, spec_transitions, spec_initial_state) = spec_data;

    // Build LTS for specification
    let spec_lts = build_lts_from_data(
        env,
        LtsData {
            states: spec_states,
            actions: spec_actions,
            transitions: spec_transitions,
            initial_state: spec_initial_state,
        },
    );

    let (impl_transitions, impl_initial_state) = impl_data;

    // Build LTS for implementation model
    // Extract states and actions from impl transitions
    let mut impl_states = std::collections::HashSet::<Atom>::new();
    let mut impl_actions = std::collections::HashSet::<Atom>::new();

    for (from, action, to) in &impl_transitions {
        impl_states.insert(*from);
        impl_states.insert(*to);
        impl_actions.insert(*action);
    }

    let impl_lts = build_lts_from_data(
        env,
        LtsData {
            states: impl_states.into_iter().collect(),
            actions: impl_actions.into_iter().collect(),
            transitions: impl_transitions,
            initial_state: impl_initial_state,
        },
    );

    // println!("spec_lts = {:?}", spec_lts);

    // Compare the two LTS using branching bisimulation
    let mut timing = Timing::new();
    let result = compare_lts(
        Equivalence::BranchingBisim,
        spec_lts,
        impl_lts,
        false,
        &mut timing,
    );

    Ok(result)
}

fn build_lts_from_data(env: Env, data: LtsData) -> LabelledTransitionSystem<String> {
    let LtsData {
        states,
        actions,
        transitions,
        initial_state,
    } = data;

    // Ensure __internal__ is always first and appears exactly once
    let mut actions = actions;
    actions.retain(|atom| *atom != atoms::__internal__());
    actions.insert(0, atoms::__internal__());

    // Create mappings from atoms to indices
    let state_to_index: HashMap<Atom, StateIndex> = states
        .iter()
        .enumerate()
        .map(|(i, state)| (*state, StateIndex::new(i)))
        .collect();

    let action_to_index: HashMap<Atom, LabelIndex> = actions
        .iter()
        .enumerate()
        .map(|(i, action)| (*action, LabelIndex::new(i)))
        .collect();

    // Convert actions to strings for the labels parameter
    let action_labels: Vec<String> = actions
        .iter()
        .map(|atom| action_atom_to_label_string(env, atom))
        .collect();

    // Find initial state index
    let initial_state_index = state_to_index
        .get(&initial_state)
        .copied()
        .unwrap_or(StateIndex::new(0));

    // Convert transitions to indexed form
    let indexed_transitions: Vec<(StateIndex, LabelIndex, StateIndex)> = transitions
        .into_iter()
        .filter_map(|(from, action, to)| {
            let from_idx = state_to_index.get(&from)?;
            let action_idx = action_to_index.get(&action)?;
            let to_idx = state_to_index.get(&to)?;
            Some((*from_idx, *action_idx, *to_idx))
        })
        .collect();

    // Create a closure that returns an iterator over transitions
    let transitions_data = indexed_transitions.clone();
    let transition_iterator = move || transitions_data.clone().into_iter();

    // Build the LabelledTransitionSystem
    let lts = LabelledTransitionSystem::new(
        initial_state_index,
        Some(states.len()),
        transition_iterator,
        action_labels,
    );

    lts
}

fn action_atom_to_label_string(env: Env, atom: &Atom) -> String {
    if *atom == atoms::__internal__() {
        "i".to_owned()
    } else {
        atom.to_term(env).atom_to_string().unwrap()
    }
}

rustler::init!("Elixir.Spex.BisimilarityChecker.MercWrapper");
