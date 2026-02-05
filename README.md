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

## Relationship to Ranvier

Ranvire is derived directly from Ranvier and preserves its lineage.  
All credit for the original design and implementation belongs to the Ranvier project and its contributors.

This fork exists to ensure continuity and maintainability over time.

---

## Forking RanvierMUD Repositories

To establish the Ranvire organization, all RanvierMUD repositories need to be forked while preserving their complete history.

**Documentation:**
- [FORKING_INSTRUCTIONS.md](./FORKING_INSTRUCTIONS.md) - Comprehensive forking guide for all 30 repositories
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Quick start guide and command reference
- [FORKING_CHECKLIST.md](./FORKING_CHECKLIST.md) - Progress tracking checklist
- [SUMMARY.md](./SUMMARY.md) - Implementation overview

**Quick Start:**
```bash
# Automated forking (requires GitHub CLI)
./fork-repositories.sh
```

---

Ranvire values correctness, continuity, and understanding over novelty or velocity.
