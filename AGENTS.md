# Agent instructions

## Load order

1. This file: scope and evidence boundaries.
2. `README.md` and `docs/experiment.md`.
3. For Rust/Cargo work, `.agents/skills/rust-strict/SKILL.md` and the references
   it routes for the actual change.
4. Package, toolchain, formatter, lint, and CI configuration when present.

Read the canonical skill rather than copying its policies into this file.
Claude and Grok may use the equivalent `.claude/skills/rust-strict/SKILL.md`
symlink. The submodule is pinned to upstream `v1.4.0`, commit
`76440cef74521b81d66b24d558167f58548c5ea0`.

## Current repository state

This is a documentation bootstrap. There is no Cargo package, Rust MSRV,
Mojo environment lock, kernel, benchmark executable, or CI matrix yet.
Do not invent commands or describe planned behavior as implemented.

Before adding the first Rust utility, define its smallest useful interface,
one package, edition, declared MSRV, and execution toolchain. A Cargo package
is not needed merely to make the repository look like a Rust project.

## Experiment contract

`docs/experiment.md` owns the experimental protocol. Keep the README summary
consistent with it whenever the protocol changes.

- Preserve equal inputs, equal numerical work, and logical output order.
- Include packing and synchronization in the packed variant's operation cost.
- Validate output before accepting performance evidence.
- Keep raw observations separate from conclusions.
- Record exact environment and timing boundaries; host success does not
  establish Spark GPU execution or compatibility.
- Respect the finite project budget and terminal condition in the README.
  A negative result is enough; extension requires a new bounded decision.

## Scope discipline

Keep Rust tooling small and Mojo kernels focused. Use the Rust skill for
Rust/Cargo changes; use relevant numerical, compiler, and runtime checks for
Mojo and Python. Rust-specific lint and toolchain rules do not apply to those
languages.

Do not build a general benchmark runner, agent orchestrator, direct Rust/Mojo
FFI layer, full model runtime, or distributed system as part of bring-up.
Do not reopen other research repositories or modify the upstream skill to
encode this project's domain rules.

Keep local machine access details, credentials, personal notes, environment
files, large datasets, and incidental logs out of Git. Only commit intentional
experiment artifacts with documented provenance.

## Verification

For this documentation bootstrap, review changed content, relative links,
skill pin and symlink resolution, and `git diff --check`. Cargo, rustdoc, and
GPU execution checks are not applicable until their corresponding code exists.
Do not introduce CI solely to claim a passing badge.

Once Rust code exists, follow the skill's task classification and scoped
verification. When experimental code changes, add the numerical and timing
checks that can invalidate the affected claim. State what was actually run
and leave untested hardware or agent-UI discovery explicitly unclaimed.
