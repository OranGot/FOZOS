//!pre start of file after elf load
const sched = @import("sched.zig");
const vmm = @import("../HAL/mem/vmm.zig");
const pmm = @import("../HAL/mem/pmm.zig");
const std = @import("std");
const dbg = @import("../drivers/dbg/dbg.zig");
const x64_pmm = @import("../arch/x64/paging/pageframe.zig");
pub inline fn setup_stack(self: *sched.Process, pageno: u64) ?void {
    self.regs.rbp = pageno * pmm.BASE_PAGE_SIZE + (self.ctx.alloc_pages(pageno, false, vmm.RW | vmm.XD | vmm.PRESENT | vmm.US) orelse return null);
    self.regs.rsp = self.regs.rbp;
}
pub inline fn map_kernel(self: *sched.Process, vcr3: usize) ?void {
    const home_pml4: [*]x64_pmm.PML4_entry = @ptrFromInt(vmm.home_freelist.paddr_to_vaddr(vmm.home_freelist.cr3) orelse return null);
    const target_pml4: [*]x64_pmm.PML4_entry = @ptrFromInt(vcr3);
    const exp_kstart: x64_pmm.virtual_address = @bitCast(@as(usize, @intCast(pmm.KERNEL_VIRT_BASE)));
    for (exp_kstart.pml4..512) |i| {
        target_pml4[i] = home_pml4[i];
    }
    var cw_entry = &vmm.home_freelist.first.t[0];
    while (true) {
        if (cw_entry.vbase == pmm.KERNEL_VIRT_BASE) {
            var t_entry = &self.ctx.first.t[0];
            il: while (true) {
                if (t_entry.next) |n| {
                    t_entry = n;
                } else break :il;
            }
            t_entry.next = cw_entry;
            return;
        }
        if (cw_entry.next) |n| {
            cw_entry = n;
        } else return null;
    }
}
