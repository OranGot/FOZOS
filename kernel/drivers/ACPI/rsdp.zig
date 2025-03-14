const limine = @import("limine");
pub export var RSDP_r = limine.RsdpRequest{};
const HHDM_OFFSET = @import("../../arch/x64/paging/pageframe.zig").HHDM_OFFSET;
pub const RSDP = extern struct {
    sign: [8]u8,
    checksum: u8,
    OEMID: [6]u8,
    rev: u8,
    rsdt_addr: u32,
};
pub const ext_RSDP = extern struct {
    sign: [8]u8,
    checksum: u8,
    OEMID: [6]u8,
    rev: u8,
    rsdt_addr: u32,

    len: u32,
    xsdt_addr: u64,
    ext_checksum: u8,
    r: [3]u8,
};
var is_ext: bool = false;
const std = @import("std");
const vmm = @import("../../HAL/mem/vmm.zig");
const dbg = @import("../dbg/dbg.zig");
pub fn init() ?void {
    if (RSDP_r.response) |r| {
        const paddr = @intFromPtr(r.address) - HHDM_OFFSET;
        dbg.printf("RSDP at paddr of : 0x{X}\n", .{paddr});
        const ptr: [*]u8 = @ptrFromInt(vmm.home_freelist.alloc_vaddr(1, paddr, true, vmm.RW | vmm.PRESENT | vmm.XD) orelse return null);
        const lrsdp: ext_RSDP = std.mem.bytesToValue(ext_RSDP, ptr[0..@sizeOf(ext_RSDP)]);
        if (lrsdp.rev == 2) {
            is_ext = true;
        }
        if (std.mem.eql(u8, lrsdp.sign, "RSD PTR ") == false) {
            dbg.printf("ACPI signature invalid\n", .{});
            return null;
        }
    } else return null;
}
