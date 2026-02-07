![Ranvire Sand Castle](https://avatars.githubusercontent.com/u/259600333?s=200&v=4)
# Ranvire

Ranvire is a maintenance-focused fork of the [RanvierMUD](https://github.com/RanvierMUD) engine.

The purpose of this project is to keep Ranvier buildable, testable, and usable on modern platforms, especially modern versions of Node.js and npm, while preserving existing behavior and architecture as much as possible.

This is a stewardship effort, not a redesign.

## Goals

- Maintain compatibility with current Node.js runtimes and tooling
- Keep the project buildable and testable with contemporary npm behavior
- Establish and maintain reliable CI
- Apply the smallest viable changes needed for long-term health

## Non-Goals

- Introducing new features
- Refactoring or modernizing code for stylistic reasons
- Rewriting subsystems or altering core architecture
- Changing gameplay behavior except where required for correctness

## Approach

Changes in Ranvire are:
- Minimal and targeted
- Motivated by concrete failures or incompatibilities
- Justified by evidence (tests, CI failures, runtime behavior)
- Kept as small and isolated as possible

A green build is not considered sufficient unless the reason for the fix is understood.

## Relationship to RanvierMUD

Ranvire is derived directly from RanvierMUD and preserves its lineage. All credit for the original design and implementation belongs to the RanvierMUD project and its contributors.

This fork exists to ensure continuity and maintainability over time. Ranvire values correctness, continuity, and understanding over novelty or velocity.

---

The Ranvire organization logo is [_sand castle_](https://thenounproject.com/icon/sand-castle-4361630/) by [Asep Yopie Hardi Noer](https://thenounproject.com/creator/sepihan/) from [Noun Project](https://thenounproject.com/browse/icons/term/sand-castle/) (CC BY 3.0)
