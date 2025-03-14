const vmm = @import("../HAL/mem/vmm.zig");
const int = @import("../arch/x64/interrupts/handle.zig");
const std = @import("std");
const pmm = @import("../HAL/mem/pmm.zig");
const alloc = @import("../HAL/mem/alloc.zig");
const ProcType = enum(u8) {
    USER = 0,
    KERNEL = 1,
};
pub const FullRegs = extern struct {
    cr3: u64 = 0,
    r15: u64 = 0,
    r14: u64 = 0,
    r13: u64 = 0,
    r12: u64 = 0,
    r11: u64 = 0,
    r10: u64 = 0,
    r9: u64 = 0,
    r8: u64 = 0,
    rbp: u64 = 0,
    rdi: u64 = 0,
    rsi: u64 = 0,
    rdx: u64 = 0,
    rcx: u64 = 0,
    rbx: u64 = 0,
    rax: u64 = 0,
    rip: u64 = 0,
    rflags: u64 = 0,
    rsp: u64 = 0,
};
pub const Process = struct {
    ctx: *vmm.VmmFreeList,
    regs: FullRegs,
    t: ProcType,
    cquant: u32,
    nquant: u32,
    pub fn terminate(self: *Process) void {
        if (gl_sched.procs.items.len == 1) {
            self.ctx.free_all(true);
        } else {
            dbg.printf("removing ALL\n", .{});
            self.ctx.free_all(false);
        }
        _ = gl_sched.procs.swapRemove(gl_sched.cw_proc_no);
        gl_sched.sched_next();
    }
};
const dbg = @import("../drivers/dbg/dbg.zig");
pub const Scheduler = struct {
    procs: std.ArrayList(*Process),
    cw_proc: *Process,
    cw_proc_no: u32,
    pub fn init(self: *Scheduler) anyerror!void {
        self.procs = std.ArrayList(*Process).init(alloc.gl_alloc);
        const np = try alloc.gl_alloc.create(Process);
        dbg.printf("set idle process\n", .{});
        np.* = .{ //idle
            .ctx = &vmm.home_freelist,
            .t = .KERNEL,
            .cquant = 1,
            .nquant = 1,
            .regs = std.mem.zeroes(FullRegs),
        };
        np.regs.cr3 = vmm.home_freelist.cr3;
        const main = @import("../main.zig");
        dbg.printf("setting rip: 0x{X}\n", .{@intFromPtr(&main.done)});
        np.regs.rip = @intFromPtr(&@import("../main.zig").done);
        dbg.printf("set rip\n", .{});
        try self.procs.append(np);
        self.cw_proc = self.procs.items[0];
        int.bind_vector(handle, 32) orelse return error.Vector0Reserved;
        // gl_sched.sched_next();
    }

    fn convert_regs(int_regs: *int.int_regs, cr3: u64) FullRegs {
        return FullRegs{
            .r9 = int_regs.r9,
            .r8 = int_regs.r8,
            .cr3 = cr3,
            .r15 = int_regs.r15,
            .r14 = int_regs.r14,
            .r13 = int_regs.r13,
            .r12 = int_regs.r12,
            .r11 = int_regs.r11,
            .r10 = int_regs.r10,
            .rbp = int_regs.rbp,
            .rdi = int_regs.rdi,
            .rsi = int_regs.rsi,
            .rdx = int_regs.rdx,
            .rcx = int_regs.rcx,
            .rbx = int_regs.rbx,
            .rax = int_regs.rax,
            .rip = int_regs.rip,
            .rflags = int_regs.rflags,
            .rsp = int_regs.rsp,
        };
    }
    pub fn handle(int_regs: *int.int_regs) void {
        dbg.printf("handle is being called\n", .{});
        const self = &gl_sched;
        if (self.cw_proc.cquant - 1 != 0) {
            self.cw_proc.cquant -= 1;
            return;
        }
        const curr_full_regs = convert_regs(int_regs, self.cw_proc.ctx.cr3);
        self.cw_proc.regs = curr_full_regs;
        self.cw_proc.cquant = self.cw_proc.nquant;
        if (self.cw_proc_no == self.procs.items.len) {
            if (self.procs.items.len == 1) {
                self.cw_proc = self.procs.items[0]; //IDLE
                self.cw_proc_no = 0;
            } else {
                self.cw_proc = self.procs.items[1]; //idk init or something
                self.cw_proc_no = 1;
            }
        } else {
            self.cw_proc_no += 1;
            self.cw_proc = self.procs.items[self.cw_proc_no];
        }
        dbg.printf("running soft switch: {any}\n", .{self.cw_proc.regs});
        if (self.cw_proc.t == .KERNEL) {
            kernel_soft_switch(&self.cw_proc.regs);
        } else {
            soft_switch(&self.cw_proc.regs);
        }
    }
    pub fn execve_elf(self: *Scheduler, path: []const u8) anyerror!void {
        dbg.printf("executing elf\n", .{});
        const ctx = try alloc.gl_alloc.create(vmm.VmmFreeList);
        ctx.cr3 = pmm.request_pages(1) orelse return error.CR3Fail;

        const vcr3 = self.cw_proc.ctx.alloc_vaddr(1, ctx.cr3, true, vmm.GLOBAL | vmm.RW | vmm.PRESENT) orelse return error.VCR3Fail;
        const proc = try @import("../drivers/elf/main.zig").load_elf(path, self.cw_proc.ctx);

        @import("pstart.zig").setup_stack(proc, 128) orelse return error.StackSetupFail;
        dbg.printf("mapping kernel\n", .{});
        @import("pstart.zig").map_kernel(proc, vcr3) orelse return error.KernelMappingFail;
        // dbg.printf("mapped kernel\n", .{});
        try self.procs.append(proc);
    }
    pub fn sched_next(self: *Scheduler) void {
        if (self.procs.items.len == 1 or self.cw_proc_no == self.procs.items.len - 1) self.cw_proc = self.procs.items[0] else {
            self.cw_proc_no += 1;
            self.cw_proc = self.procs.items[self.cw_proc_no];
        }
        self.cw_proc.cquant = self.cw_proc.nquant;
        dbg.printf("scheduling next\n", .{});
        if (self.cw_proc.t == .KERNEL) {
            kernel_soft_switch(&self.cw_proc.regs);
        }
        soft_switch(&self.cw_proc.regs);
    }
};
extern fn kernel_soft_switch(*FullRegs) void;
extern fn soft_switch(*FullRegs) void;
pub var gl_sched: Scheduler = undefined;
