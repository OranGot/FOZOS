const std = @import("std");
const int = @import("../interrupts/handle.zig");
const syscall_regs = extern struct {
    r15: u64 = 0,
    r14: u64 = 0,
    r13: u64 = 0,
    r12: u64 = 0,
    r11: u64 = 0,
    r10: u64 = 0,
    r9: u64 = 0,
    r8: u64 = 0,
    // rbp: u64 = 0,
    rdi: u64 = 0,
    rsi: u64 = 0,
    rdx: u64 = 0,
    rcx: u64 = 0,
    rbx: u64 = 0,
    rax: u64 = 0,
};
const dbg = @import("../../../drivers/dbg/dbg.zig");
const tty = @import("../../../drivers/tty/tty.zig");
extern fn syscall_handle() void;

///keeps info about kernel stack on swapgs instruction
pub const GSSwapValue = extern struct {
    kernel_rbp: u64 = 0,
    kernel_rsp: u64 = 0,
    user_rsp: u64 = 0,
    user_rbp: u64 = 0,
};
pub export var gs_inst = GSSwapValue{};
const msr = @import("../../../util/msr.zig");
pub export fn handle_syscall(args: *syscall_regs) callconv(.C) u64 {
    dbg.printf("syscall handler enter: {any}\n", .{args});
    return switch (args.rax) {
        1 => write(0, args.rsi, args.rdx, 0, 0, 0),
        60 => exit(args.rdi, 0, 0, 0, 0, 0),
        else => exit(1, 0, 0, 0, 0, 0),
    };
    // if (args.rax > syscall_lookup_t.len or syscall_lookup_t[args.rax] == null) {
    //     dbg.printf("syscall fail, no entry at: {}\n", .{args.rax});
    //     _ = exit(1, 0, 0, 0, 0, 0);
    // }
    // return syscall_lookup_t[args.rax].?(args.rdi, args.rsi, args.rdx, args.r10, args.r8, args.r9);
}
// fn read(fd: u32, buf: [*]u8, count: usize) callconv(.C) u64 {}
fn write(_: u64, buf_ptr: u64, count: u64, _: u64, _: u64, _: u64) u64 {
    dbg.printf("write: 0x{x}, {}\n", .{ buf_ptr, count });
    tty.printf("{s}", .{@as([*]u8, @ptrFromInt(buf_ptr))[0..count]});
    return count;
}
const proc = @import("../../../proc/sched.zig");
fn exit(errcode: u64, _: u64, _: u64, _: u64, _: u64, _: u64) u64 {
    dbg.printf("exit called with ecode: {}\n", .{errcode});
    proc.gl_sched.cw_proc.terminate();
    return 0;
}
// pub fn stub() void {}
