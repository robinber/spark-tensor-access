# Spark Tensor Access

A bounded experiment in selective tensor access on the NVIDIA DGX Spark,
using Mojo for GPU kernels and Rust for small data and validation tools.

**Status: experiment specification only.** No kernels, Cargo package,
performance results, or validated Spark environment are included yet.

## The question

> When does packing selected tensor blocks into a contiguous buffer improve
> GPU operation latency enough to pay for the packing itself?

The experiment will compare two implementations of the same operation:

- **Direct:** read selected source blocks and reduce them on the GPU.
- **Packed:** gather those blocks into a contiguous buffer, then reduce them
  on the GPU, including the packing cost in the comparison.

A separate CPU implementation will check numerical correctness. The first
operation is a sum of squares per selected FP32 block, preserving selection
order. Inputs are synthetic and reproducible.

This is a GPU memory-access experiment. It does not establish a model-inference
speedup, expert-cache effectiveness, or token-generation performance.

## Why the Spark

The Spark CPU and GPU share physical system memory. This makes it a useful
target for examining actual allocation, layout, copy, and synchronization
costs. It must not be modeled as independent host RAM and discrete GPU VRAM
pools. See NVIDIA's [system overview][spark] and [CUDA porting notes][cuda].

Mojo lists the Spark as a known-compatible target. The first implementation
step is to validate the current toolchain on the actual machine; documentation
support is not a completed local compatibility test. See the
[Mojo requirements][mojo].

## What we will build

| Tool | Intended role |
| --- | --- |
| Rust | Deterministic corpus generation, input validation, and small experiment/result utilities |
| Mojo | GPU kernels and their immediate execution and timing code |
| Python, where useful | Independent numerical reference and a few plots |

Start with separate executables and a small manifest/file interface. A single
Cargo package can be added when the first Rust utility is needed. Direct
Rust/Mojo FFI and a general benchmark framework are outside the initial scope.

The full comparison and measurement contract are in
[docs/experiment.md](docs/experiment.md).

## A short, finite project

The initial experiment has an approximately **eight-lab-day budget**, normally
four weeks at two lab days per week. Shorten familiar steps.

| Stage | Evidence |
| --- | --- |
| Bring-up, at most two sessions | One independently checked GPU example and a recorded environment; otherwise document the blocker and reconsider the environment |
| First comparison, by the end of week two | Two correct variants with packing included and one provisional measurement |
| Bounded campaign | A fixed, small matrix, raw repeated observations, and profiling of the important differences |
| Conclusion | A reproducible report, explicit limits, and an explanation of what changed in our understanding |

**Stop when the comparison is correct, reproducible, and explained.** A
negative result is sufficient. If time runs out, report incomplete evidence
instead of silently extending the project. Any extension requires a new
bounded decision.

## What this project will not become by default

- A full model or MoE runtime, attention implementation, or KV-cache project.
- A training, fine-tuning, serving, or deployment platform.
- An initial NVMe, memory-oversubscription, multi-GPU, or multi-node experiment.
- A language benchmark that compares different numerical work.
- A shared orchestration platform for other research repositories.

## Working with coding agents

Read [AGENTS.md](AGENTS.md) for the project contract. The portable
[rust-strict skill][skill] is pinned as a Git submodule at
`.agents/skills/rust-strict`. It applies to Rust/Cargo work; Mojo and Python
changes use their relevant correctness and measurement checks.

Clone the repository and its pinned skill:

```sh
git clone --recurse-submodules https://github.com/robinber/spark-tensor-access.git
cd spark-tensor-access
```

For an existing checkout:

```sh
git submodule update --init --recursive
```

There is one canonical skill checkout. The Claude skill path is a relative
symlink to it; Grok can reuse that Claude path, as documented upstream.

## License

Project files are [MIT licensed](LICENSE). The skill submodule retains its own
license and history.

[spark]: https://docs.nvidia.com/dgx/dgx-spark-porting-guide/overview.html
[cuda]: https://docs.nvidia.com/dgx/dgx-spark-porting-guide/porting/cuda.html
[mojo]: https://mojolang.org/docs/requirements/
[skill]: https://github.com/robinber/agent-skills-rust
