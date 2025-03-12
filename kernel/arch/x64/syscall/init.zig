const msr = @import("../../../util/msr.zig");
const handle = @import("handler.zig");
const gdt = @import("../gdt/gdt.zig");
const dbg = @import("../../../drivers/dbg/dbg.zig");
extern fn sys_handle_generic() void;
pub fn init() void {
    //enable syscalls
    msr.wrmsr(0xC0000080, msr.rdmsr(0xC0000080) | 1);
    msr.wrmsr(0xC0000082, @intFromPtr(&sys_handle_generic));
    msr.wrmsr(0xC0000081, 0xB << 48 | 0x8 << 32);
    msr.wrmsr(0xC0000102, @intFromPtr(&handle.gs_inst));
    // handle.stub();

    gdt.tss.RSP0 = (asm ("movq %rsp, %[o]"
        : [o] "=r" (-> usize),
    ));
    dbg.printf("flushing tss\n", .{});
    gdt.flush_tss();
}
