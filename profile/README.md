![Rantamuta Sand Castle](https://avatars.githubusercontent.com/u/259600333?s=200&v=4)

# Rantamuta

Rantamuta is a maintenance-focused fork of the RanvierMUD engine.

The goal of this project is to keep Ranvier buildable, testable, and usable on modern platforms, particularly current versions of Node.js and npm, while preserving existing behavior and architecture as closely as possible.

This is a stewardship effort, not a redesign.

## Documents

- [RantaMutaUserManual.md](../docs/RantamutaUserManual.md)

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

Changes in Rantamuta are:

- Minimal and targeted
- Driven by concrete failures or incompatibilities
- Justified by evidence (tests, CI failures, runtime behavior)
- Kept as small and isolated as possible

This fork exists to preserve continuity and maintainability over time. Rantamuta prioritizes correctness, stability, and understanding over novelty or velocity.

## Relationship to RanvierMUD

This project is a direct fork of RanvierMUD and remains faithful to its original design and architecture. There is no personal or social continuity between the projects, but full credit for the original work belongs to the RanvierMUD project and its contributors.

Upstream maintainers are welcome to pull changes from this fork. Assistance is available if helpful.

## Audience

Rantamuta is primarily for:

- Developers who want a maintained RanvierMUD codebase
- People comfortable reading code and making their own modifications
- Users who value stability over novelty

It is not positioned as a general-purpose community hub. This is a personal maintenance fork, kept public for practical reasons.

## Getting Started

Rantamuta doesn’t introduce a new setup or workflow of its own. If you’ve used RanvierMUD before, things should feel familiar.

To get up and running, follow the Rantamuta MUD engine README here:

[https://github.com/Rantamuta/ranviermud](https://github.com/Rantamuta/ranviermud?tab=readme-ov-file#Rantamuta-mud-engine)

That document covers installation, basic configuration, and how to start a server. Any differences from upstream RanvierMUD are intentional and focused on compatibility and long-term maintainability.

---

The Rantamuta organization logo is [_sand castle_](https://thenounproject.com/icon/sand-castle-4361630/) by [Asep Yopie Hardi Noer](https://thenounproject.com/creator/sepihan/) from [Noun Project](https://thenounproject.com/browse/icons/term/sand-castle/) (CC BY 3.0)
