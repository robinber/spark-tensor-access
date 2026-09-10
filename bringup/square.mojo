from std.gpu import block_dim, block_idx, thread_idx
from std.sys import exit, has_accelerator
from max.gpu.host import DeviceBuffer, DeviceContext, HostBuffer

comptime STORAGE_LEN = 8
comptime PADDING_SENTINEL = Float32(-1)


def square_kernel(
    input: Pointer[Float32, ImmutAnyOrigin],
    output: Pointer[Float32, MutAnyOrigin],
    n: Int32,
):
    var i = block_idx.x * block_dim.x + thread_idx.x
    if i < Int(n):
        var x = input[unsafe_offset=i]
        output[unsafe_offset=i] = x * x


def run_case(
    ctx: DeviceContext,
    n: Int,
    host_input: HostBuffer[DType.float32],
    device_input: DeviceBuffer[DType.float32],
    device_output: DeviceBuffer[DType.float32],
) raises -> Int:
    var host_output = ctx.enqueue_create_host_buffer[DType.float32](STORAGE_LEN)
    ctx.synchronize()
    for i in range(STORAGE_LEN):
        host_output[i] = PADDING_SENTINEL
    ctx.enqueue_copy(src_buf=host_output, dst_buf=device_output)

    ctx.enqueue_function[square_kernel](
        device_input,
        device_output,
        Int32(n),
        grid_dim=1,
        block_dim=STORAGE_LEN,
    )

    ctx.enqueue_copy(src_buf=device_output, dst_buf=host_output)
    ctx.synchronize()

    var failures = 0
    for i in range(STORAGE_LEN):
        var expected = host_input[i] * host_input[i] if i < n else PADDING_SENTINEL
        if host_output[i] != expected:
            failures += 1
            print("  mismatch at", i, "expected", expected, "got", host_output[i])
    print("N =", n, "output", host_output, "failures", failures)
    return failures


def main() raises:
    comptime if not has_accelerator():
        print("No GPU accelerator available; this program requires the Spark GPU")
        exit(2)

    var ctx = DeviceContext()
    print("device:", ctx.name(), "api:", ctx.api())

    var host_input = ctx.enqueue_create_host_buffer[DType.float32](STORAGE_LEN)
    ctx.synchronize()
    for i in range(STORAGE_LEN):
        host_input[i] = Float32(i - 3)

    var device_input = ctx.enqueue_create_buffer[DType.float32](STORAGE_LEN)
    var device_output = ctx.enqueue_create_buffer[DType.float32](STORAGE_LEN)
    ctx.enqueue_copy(src_buf=host_input, dst_buf=device_input)
    print("input", host_input)

    var failures = 0
    failures += run_case(ctx, 8, host_input, device_input, device_output)
    failures += run_case(ctx, 6, host_input, device_input, device_output)

    if failures != 0:
        print("FAIL:", failures, "mismatches")
        exit(1)
    print("PASS")
