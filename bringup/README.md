# GPU bring-up on the DGX Spark

This directory is one pixi workspace with two small Mojo programs that run on
the Spark GPU and check themselves on the CPU:

| Task | Program | Purpose |
| --- | --- | --- |
| `pixi run square` | `square.mojo` | Element-wise square: index mapping, bounds guard, launch, synchronization |
| `pixi run direct-sum` | `direct_sum.mojo` | Variant A baseline: one sum of squares per selected block, read directly from the source |

Both share the install procedure and environment record below. Neither
measures anything.

## Element-wise square

`square.mojo` is the first program executed on the Spark GPU for this project.
It computes `output[i] = input[i] * input[i]` with one GPU thread per element
and checks every result on the CPU. It exists to validate the toolchain and to
make the thread-index, bounds-guard, launch, and synchronization steps
reviewable in one small file. It measures nothing.

## What the program does

- Input storage is eight FP32 values, `[-3, -2, -1, 0, 1, 2, 3, 4]`, whose
  squares are exactly representable.
- Each case launches one block of eight threads. Thread `i` computes its
  global index as `block_idx.x * block_dim.x + thread_idx.x`.
- Both the input read and the output write sit inside the `i < N` guard, so
  surplus threads perform no memory access.
- Case `N = 8` expects `[9, 4, 1, 0, 1, 4, 9, 16]`.
- Case `N = 6` starts from an eight-element output filled with `-1` and
  expects `[9, 4, 1, 0, 1, 4, -1, -1]`, which shows that threads 6 and 7
  touched nothing.
- The output buffer is reset to `-1` on the host and copied to the device
  before each case.
- After the kernel is enqueued, the device output is copied back to a host
  buffer and `ctx.synchronize()` blocks the CPU until every queued operation
  has completed. Only then does the CPU compare the results.
- Any mismatch is printed and the process exits with status 1. If no GPU is
  available at compile time, it exits with status 2.

Comparison uses exact numerical equality. That is appropriate for these
deliberately small exact cases only and does not define the tolerance policy
of the later reduction experiment.

## Direct sum of squares per selected block

`direct_sum.mojo` is the first correctness baseline for variant A in
[docs/experiment.md](../docs/experiment.md). It assigns one GPU thread to each
position of a selection list, and that thread reads its block straight from
the shared source allocation. Nothing is packed.

- The source is one read-only allocation of three contiguous blocks of three
  FP32 values: `[1, 2, 3]`, `[-1, 0, 2]`, `[2, 3, 4]`. Element `j` of block
  `b` lives at offset `b * 3 + j`.
- Each case launches one block of eight threads for a three-entry selection.
  Thread `i` guards `i < selection_count` before touching the selection or
  the output, reads its block ID, starts a private FP32 accumulator at zero,
  walks the block's three elements adding each square, and writes the total
  at position `i`. Threads never share an accumulator, so there is no
  cooperative reduction or atomic.
- Selection `[0, 1, 2]` expects `[14, 5, 29]`; selection `[2, 0, 2]` expects
  `[29, 14, 29]`, preserving order and the duplicate.
- The eight-element output is reset to `-1` before each case and positions
  3 through 7 are checked to remain `-1`.
- The host recomputes every selected total with FP64 accumulation and
  compares it both against the fixed expectation and against the GPU value,
  after the device-to-host copy and `ctx.synchronize()`.
- Block IDs are validated on the host before any GPU work. The program feeds
  itself `[0, -1, 2]` and `[3, 1, 0]` and requires both to be rejected; a
  validator that accepts them makes the run fail.
- Any problem exits with status 1. Without an accelerator it exits with 2.

Exact equality is declared for this fixture because every intermediate sum
is a small integer, exactly representable in FP32. It is not the tolerance
policy for larger or arbitrary-valued inputs.

## Install and run on the Spark

The environment is a [pixi](https://pixi.sh) workspace pinned by `pixi.lock`
for `linux-aarch64`. Run these commands on the Spark:

```sh
curl -fsSL https://pixi.sh/install.sh | sh
git clone --recurse-submodules https://github.com/robinber/spark-tensor-access.git
cd spark-tensor-access/bringup
pixi install --locked
pixi run square
```

`pixi run square` and `pixi run direct-sum` each compile and run their
program inside the locked environment. A successful run prints the
runtime-selected device, the inputs, each case's output, and `PASS`, and exits
with status 0.

`pixi install --locked` fails instead of re-solving if `pixi.toml` and
`pixi.lock` disagree. Regenerate the lock with `pixi install` only as a
deliberate environment change and record the new versions here.

Two notes on the toolchain as installed:

- `DeviceContext`, `DeviceBuffer`, and `HostBuffer` come from `max.gpu.host`,
  which is provided by the `max` package, not by `mojo` alone. Without `max`
  the compiler reports that it cannot locate module `max`.
- The published GPU manual uses a `.float32` shorthand for `DType.float32`;
  Mojo 1.0.0 rejects that spelling, so the program writes `DType.float32`.

## Environment record

Recorded on the Spark on 2026-09-08. Connection details are intentionally
omitted.

| Item | Value |
| --- | --- |
| Machine | NVIDIA DGX Spark, `aarch64` |
| OS | Ubuntu 24.04.4 LTS, kernel `6.17.0-1032-nvidia` |
| GPU | NVIDIA GB10, compute capability 12.1 |
| NVIDIA driver | 580.173.02, reporting CUDA 13.0 |
| System CUDA toolkit | `/usr/local/cuda-13.0` present; not used by the pixi environment and `MODULAR_NVPTX_COMPILER_PATH` unset |
| pixi | 0.80.0 |
| `mojo` / `mojo-compiler` / `mojo-python` | 1.0.0 (`release`, channel `https://conda.modular.com/max`) |
| `max` / `max-core` | 26.5.0 (`3.12release` / `release`, same channel) |
| Python in environment | 3.12.14 from conda-forge |
| Selected device at runtime | `NVIDIA GB10`, API `cuda` |

## Validation evidence: square

The transcript below was recorded on the Spark on 2026-09-08 from a fresh
clone of revision `8a179a54c03c047fd107c1fc64c3eff1031e8866` with a clean
working tree, using exactly the commands above. Nothing here was run on a
CPU-only host.

```text
$ pixi install --locked
✔ The default environment has been installed.
$ pixi run square
✨ Pixi task (square): mojo run square.mojo
device: NVIDIA GB10 api: cuda
input HostBuffer([-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0])
N = 8 output HostBuffer([9.0, 4.0, 1.0, 0.0, 1.0, 4.0, 9.0, 16.0]) failures 0
N = 6 output HostBuffer([9.0, 4.0, 1.0, 0.0, 1.0, 4.0, -1.0, -1.0]) failures 0
PASS
$ echo $?
0
```

The failure path was exercised at the same revision by running a temporary
copy of `square.mojo` whose CPU expectation was shifted by one. That copy
printed one mismatch line per affected element, reported `FAIL`, and exited
with status 1. The copy was not committed.

## Validation evidence: direct-sum

The transcript below was recorded on the Spark on 2026-09-10 from a fresh
clone of revision `c67f206e0ef4f71365ef8a1c765ee981e5e0d020` with a clean
working tree, using exactly the commands above. The environment matched the
record above: NVIDIA GB10, driver 580.173.02, mojo 1.0.0, max 26.5.0.
`pixi run square` still passed in the same clone.

```text
$ pixi install --locked
✔ The default environment has been installed.
$ pixi run direct-sum
✨ Pixi task (direct-sum): mojo run direct_sum.mojo
device: NVIDIA GB10 api: cuda
source HostBuffer([1.0, 2.0, 3.0, -1.0, 0.0, 2.0, 2.0, 3.0, 4.0])
selection [0, 1, 2] output HostBuffer([14.0, 5.0, 29.0, -1.0, -1.0, -1.0, -1.0, -1.0]) failures 0
selection [2, 0, 2] output HostBuffer([29.0, 14.0, 29.0, -1.0, -1.0, -1.0, -1.0, -1.0]) failures 0
selection [0, -1, 2] rejected before GPU work
selection [3, 1, 0] rejected before GPU work
PASS
$ echo $?
0
```

Two failure paths were exercised at the same revision on temporary,
uncommitted copies of `direct_sum.mojo`. Shifting the GPU expectation by one
reported a mismatch for every element and exited with status 1. Making the
validator accept every ID reported both invalid selections as wrongly
accepted and exited with status 1.

## What this does and does not establish

The square run establishes that the pinned Mojo 1.0.0 and MAX 26.5.0
packages compile a kernel for the GB10, launch it through the CUDA API, and
return correct results to the CPU. The direct-sum run establishes that a
per-thread serial reduction over blocks read in place from a shared source
allocation is correct for the fixture above, including duplicate selections
and host-side rejection of invalid IDs.

Neither establishes performance, packing behavior, the numerical tolerance
of larger reductions, parallel reduction within a block, or compatibility of
any other Mojo or MAX version. Those remain for the experiment in
[docs/experiment.md](../docs/experiment.md).
