const writer = @import("std").io.Writer;
const drvcmn = @import("../drvlib/drvcmn.zig");
const fmt = @import("std").fmt;
const dbg_writer = writer(void, error{}, dbg_callback){ .context = {} };
const QEMU_DBG_PORT = 0xE9;
fn dbg_callback(_: void, string: []const u8) error{}!usize {
    for (0..string.len) |d| {
        drvcmn.outb(QEMU_DBG_PORT, string[d]);
    }
    return string.len;
}
pub fn printf(comptime format: []const u8, args: anytype) void {
    fmt.format(dbg_writer, format, args) catch unreachable;
}
