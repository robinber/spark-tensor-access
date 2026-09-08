# GPU bring-up: element-wise square on the DGX Spark

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

`pixi run square` compiles and runs `square.mojo` inside the locked
environment. A successful run prints the runtime-selected device, the input,
both case outputs, and `PASS`, and exits with status 0.

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

## Validation evidence

See the run transcript below, recorded from the documented command on the
Spark at the stated revision. Nothing here was run on a CPU-only host.

_Pending: filled in by the evidence commit after the code commit is pushed._

## What this does and does not establish

It establishes that the pinned Mojo 1.0.0 and MAX 26.5.0 packages compile a
kernel for the GB10, launch it through the CUDA API, and return correct
results to the CPU for the two cases above.

It does not establish performance, packing behavior, reduction accuracy, or
compatibility of any other Mojo or MAX version. Those remain for the
experiment in [docs/experiment.md](../docs/experiment.md).
