const rsdp = @import("rsdp.zig");
pub const CommonACPISDTHeader = extern struct {
    sign: [4]u8,
    len: u32,
    rev: u8,
    checksum: u8,
    oemid: [6]u8,
    oem_table_id: [8]u8,
    oem_rev: u32,
    creator_id: u32,
    creator_rev: u32,
};
pub fn checksum(h: *CommonACPISDTHeader) bool {
    var sum: u8 = 0;
    for (0..h.len) |i| {
        sum +%= @as([*]u8, @ptrCast(h))[i];
    }
    return sum == 0;
}
pub const ptrs_ret_type = union(enum) {
    ext: []u64,
    normal: []u32,
};
const std = @import("std");
const vmm = @import("../../HAL/mem/vmm.zig");
const dbg = @import("../dbg/dbg.zig");
pub var GL_RSDT: RSDT = std.mem.zeroes(RSDT);
pub const RSDT = extern struct {
    header: *CommonACPISDTHeader,
    ptrs: ptrs_ret_type,

    pub fn get_ptrs(self: *RSDT) ptrs_ret_type {
        if (rsdp.is_ext == true) {
            return ptrs_ret_type{
                .ext = @as([*]u64, (@intFromPtr(self.header) + @sizeOf(CommonACPISDTHeader)))[0 .. (self.header.len - @sizeOf(CommonACPISDTHeader)) / 8],
            };
        } else {
            return ptrs_ret_type{
                .normal = @as([*]u32, (@intFromPtr(self.header) + @sizeOf(CommonACPISDTHeader)))[0 .. (self.header.len - @sizeOf(CommonACPISDTHeader)) / 4],
            };
        }
    }
    pub fn init(ptr: rsdp.ext_RSDP) ?void {
        if (rsdp.is_ext == true) {
            const vaddr = vmm.home_freelist.alloc_vaddr(1, ptr.xsdt_addr, true, vmm.RW | vmm.PRESENT) orelse return null;
            GL_RSDT.header = @ptrFromInt(vaddr);
            GL_RSDT.ptrs = GL_RSDT.get_ptrs();
        }
    }
    pub fn seek(self: *RSDT, signature: [4]u8) ?u64 {
        if (self.ptrs == .normal) {
            for (self.ptrs.normal) |p| {
                const ptr: *CommonACPISDTHeader = @ptrFromInt(vmm.home_freelist.alloc_vaddr(1, p, true, vmm.PRESENT) orelse return null);
                defer vmm.home_freelist.free_vaddr(@intFromPtr(ptr), 1);
                if (std.mem.eql(u8, signature, ptr.sign) == true) return p;
                dbg.printf("wrong signature", .{ptr.sign});
            }
        }
    }
};
