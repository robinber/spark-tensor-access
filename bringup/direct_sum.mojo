from std.gpu import block_dim, block_idx, thread_idx
from std.sys import exit, has_accelerator
from max.gpu.host import DeviceBuffer, DeviceContext, HostBuffer

comptime BLOCK_LEN = 3
comptime BLOCK_COUNT = 3
comptime SOURCE_LEN = BLOCK_LEN * BLOCK_COUNT
comptime SELECTION_LEN = 3
comptime OUTPUT_LEN = 8
comptime PADDING_SENTINEL = Float32(-1)


def direct_sum_kernel(
    source: Pointer[Float32, ImmutAnyOrigin],
    selection: Pointer[Int32, ImmutAnyOrigin],
    output: Pointer[Float32, MutAnyOrigin],
    selection_count: Int32,
    block_len: Int32,
):
    var i = block_idx.x * block_dim.x + thread_idx.x
    if i < Int(selection_count):
        var base = Int(selection[unsafe_offset=i]) * Int(block_len)
        var acc = Float32(0)
        for j in range(Int(block_len)):
            var x = source[unsafe_offset=base + j]
            acc += x * x
        output[unsafe_offset=i] = acc


def selection_is_valid(selection: List[Int32]) -> Bool:
    for id in selection:
        if id < 0 or id >= BLOCK_COUNT:
            return False
    return True


def cpu_reference(source: HostBuffer[DType.float32], block_id: Int32) -> Float32:
    var acc = Float64(0)
    for j in range(BLOCK_LEN):
        var x = Float64(source[Int(block_id) * BLOCK_LEN + j])
        acc += x * x
    return Float32(acc)


def run_case(
    ctx: DeviceContext,
    selection: List[Int32],
    expected: List[Float32],
    host_source: HostBuffer[DType.float32],
    device_source: DeviceBuffer[DType.float32],
) raises -> Int:
    var failures = 0
    if not selection_is_valid(selection):
        print("selection", selection, "rejected on the host before launch")
        return 1

    var host_selection = ctx.enqueue_create_host_buffer[DType.int32](SELECTION_LEN)
    var host_output = ctx.enqueue_create_host_buffer[DType.float32](OUTPUT_LEN)
    var device_selection = ctx.enqueue_create_buffer[DType.int32](SELECTION_LEN)
    var device_output = ctx.enqueue_create_buffer[DType.float32](OUTPUT_LEN)
    ctx.synchronize()
    for i in range(SELECTION_LEN):
        host_selection[i] = selection[i]
    for i in range(OUTPUT_LEN):
        host_output[i] = PADDING_SENTINEL
    ctx.enqueue_copy(src_buf=host_selection, dst_buf=device_selection)
    ctx.enqueue_copy(src_buf=host_output, dst_buf=device_output)

    ctx.enqueue_function[direct_sum_kernel](
        device_source,
        device_selection,
        device_output,
        Int32(SELECTION_LEN),
        Int32(BLOCK_LEN),
        grid_dim=1,
        block_dim=OUTPUT_LEN,
    )

    ctx.enqueue_copy(src_buf=device_output, dst_buf=host_output)
    ctx.synchronize()

    for i in range(OUTPUT_LEN):
        var want = PADDING_SENTINEL
        if i < SELECTION_LEN:
            want = cpu_reference(host_source, selection[i])
            if want != expected[i]:
                failures += 1
                print("  reference mismatch at", i, "cpu", want, "fixture", expected[i])
        if host_output[i] != want:
            failures += 1
            print("  gpu mismatch at", i, "expected", want, "got", host_output[i])
    print("selection", selection, "output", host_output, "failures", failures)
    return failures


def run_invalid_case(selection: List[Int32]) -> Int:
    if selection_is_valid(selection):
        print("selection", selection, "was accepted but must be rejected")
        return 1
    print("selection", selection, "rejected before GPU work")
    return 0


def main() raises:
    comptime if not has_accelerator():
        print("No GPU accelerator available; this program requires the Spark GPU")
        exit(2)

    var ctx = DeviceContext()
    print("device:", ctx.name(), "api:", ctx.api())

    var host_source = ctx.enqueue_create_host_buffer[DType.float32](SOURCE_LEN)
    ctx.synchronize()
    var source_values: List[Float32] = [1, 2, 3, -1, 0, 2, 2, 3, 4]
    for i in range(SOURCE_LEN):
        host_source[i] = source_values[i]
    var device_source = ctx.enqueue_create_buffer[DType.float32](SOURCE_LEN)
    ctx.enqueue_copy(src_buf=host_source, dst_buf=device_source)
    print("source", host_source)

    var failures = 0
    failures += run_case(ctx, [0, 1, 2], [14, 5, 29], host_source, device_source)
    failures += run_case(ctx, [2, 0, 2], [29, 14, 29], host_source, device_source)
    failures += run_invalid_case([0, -1, 2])
    failures += run_invalid_case([3, 1, 0])

    if failures != 0:
        print("FAIL:", failures, "problems")
        exit(1)
    print("PASS")
