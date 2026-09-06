# Experiment: direct versus packed tensor-block access

This document specifies a planned experiment. No performance measurements or
target-runtime validation have been completed.

## Hypothesis

Packing selected blocks adds work, allocation pressure, and synchronization.
It may still reduce the subsequent GPU computation cost for some shapes or
access patterns. The benefit must be measured for the complete operation.

Direct access winning every tested case is a valid outcome. Packing is not
an optimization we must make succeed.

## Inputs and equal work

- A deterministically generated FP32 source corpus organized into blocks.
- A selection list of block identifiers, preserving duplicates and order.
- A versioned manifest recording the seed, generation algorithm, dimensions,
  selected fraction, source footprint, and input fingerprints.

Each variant computes one sum of squares per selected block. The result must
have the same logical ordering, including repeated selections. Use finite,
bounded test inputs so the numerical contract is explicit.

The generator must be sufficient to recreate the corpus. Keep large generated
data outside Git; small intentional fixtures may be committed.

## Variants

**A — direct access.** A GPU kernel reads the selected blocks in the original
source allocation and computes their reductions.

**B — explicit packing.** Gather the same selected blocks into a contiguous
allocation, then run the GPU reduction. Include the gather and required
synchronization in the total operation time. Account for the extra buffer.
Start with one supported packing method, preferably on the GPU. CPU packing
would be a separately declared variant.

**C — numerical reference.** Use an independent CPU implementation, with
higher-precision accumulation where practical. It is a correctness reference,
not a basis for claiming an inference speedup from a CPU/GPU timing ratio.

Both GPU variants perform the declared reduction once. Reusing packed data
across multiple operations is a separate hypothesis, not a hidden advantage
granted only to variant B.

## Bounded matrix

Start with one small case. After bring-up and correctness, choose and freeze
at most three block sizes and three selection patterns:

- sequential;
- clustered;
- scattered.

Record selected fraction and source footprint rather than changing them
implicitly between variants. Choose exact dimensions after the initial
environment check, before collecting the campaign. Keep all allocations
comfortably within available memory. Reserve one additional dimension for
confirmation after tuning.

## Numerical acceptance

- Declare absolute and relative error tolerances before optimizing, taking
  FP32 reduction error and block length into account.
- Verify outputs against the independent reference.
- Exercise repeated identifiers and dimensions that do not align with ideal
  kernel launch shapes.
- Reject invalid indices and inconsistent manifests before GPU work.
- Do not retain fast-but-incorrect rows as accepted performance evidence.

## Timing boundary

The measured operation starts after source data is loaded and ready. Corpus
generation, file I/O, compilation, process startup, and one-time setup are
outside that interval and must be documented separately.

For reusable allocations, record initial allocation cost separately and use
the same declared reuse policy across cases. Variant B's per-operation
packing remains inside its total time.

Distinguish host elapsed time from GPU event timing. Ensure completion is
observed correctly: asynchronous kernel submission alone is not execution
latency. Report the host-visible complete operation and the GPU stages
separately. Avoid accidentally double-counting overlapping intervals.

Warm up, alternate variant order, use repeated measurements, and preserve
the raw observations and their dispersion. The repetition count is fixed in
the campaign manifest before measurement.

## Evidence to retain

- Exact code revision and toolchain/environment versions.
- OS, driver, GPU target, and observed allocation APIs.
- Relevant background load and observable clock/power conditions.
- Corpus regeneration instructions and input identity.
- Total operation time, packing time, and reduction time.
- Useful bytes, explicit copies, and peak allocations owned by the program.
- Correctness results and raw timing repetitions.

Program-owned allocations are not total process or system memory usage.
Theoretical bandwidth is not measured traffic. Time divided by block count
is not a distribution of individual block latencies.

## Interpretation and completion

Explain the main differences using measurements and profiling. A synthetic
memory-access result is not a real-model or token-generation result, and the
Spark's shared-memory result does not automatically transfer to discrete GPUs.

The initial experiment ends with two correct variants, a reproducible bounded
comparison, a small report, and explicit limits. A speedup is not required.
Record incomplete results honestly if the eight-day budget is exhausted.

Only then consider one new bounded experiment, such as an operation from a
real layer or a separate storage-to-compute measurement. These are choices
for later, not an automatic roadmap.
