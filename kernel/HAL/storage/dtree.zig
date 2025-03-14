//!System for keeping track of all existing storage devices and abstracting them
//!should be pretty fast since it's a look up table
//!I am not designing it to house many drives since the os is made for being run on desktop
const std = @import("std");
const alloc = @import("../mem/alloc.zig");
const pmm = @import("../mem/pmm.zig");
const dbg = @import("../../drivers/dbg/dbg.zig");
pub const COMMON_BLOCK_SIZE = pmm.BASE_PAGE_SIZE;
const Dtype = enum {
    NVMe,
    AHCI,
    ETC,
    UD,
};
const vmm = @import("../mem/vmm.zig");
pub const DriveEntry = struct {
    lba_size: u16,
    readb: *const fn (*anyopaque, lba: u64, block_no: u16, buf: [*]u8, vmm_ctx: *vmm.VmmFreeList) anyerror!void,
    readmin: *const fn (self: *anyopaque, lba: u64, block_no: u16, buf: [*]u8, vmm_ctx: *vmm.VmmFreeList) anyerror!void,
    writeb: *const fn (*anyopaque, lba: u64, block_no: u16, buf: [*]u8, vmm_ctx: *vmm.VmmFreeList) anyerror!void,
    writemin: *const fn (self: *anyopaque, lba: u64, block_no: u16, buf: [*]u8, vmm_ctx: *vmm.VmmFreeList) anyerror!void,
};
pub const Dentry = struct {
    t: Dtype,
    self: *anyopaque,
    deinit: ?*const fn (*anyopaque) void,
    drives: std.ArrayList(DriveEntry),
};
pub const Dtree = struct {
    devices: std.ArrayList(Dentry),
    pub fn deinit_all(self: *Dtree) void {
        for (self.devices.items) |n| {
            n.deinit(n.self);
        }
        self.devices.deinit();
    }
    pub fn read_block(self: *Dtree, did: u16, drvid: u16, lba: u64, blockno: u16, buf: [*]u8, vmm_ctx: *vmm.VmmFreeList) anyerror!void {
        if (did > self.devices.items.len) return error.InvalidDevID;
        if (drvid > self.devices.items[did].drives.items.len) return error.InvalidDrvID;
        const dev: DriveEntry = self.devices.items[did].drives.items[drvid];
        return dev.readb(self.devices.items[did].self, lba, blockno, buf, vmm_ctx);
    }
    pub fn write_block(self: *Dtree, did: u16, drvid: u16, lba: u64, blockno: u16, buf: [*]u8, vmm_ctx: *vmm.VmmFreeList) anyerror!void {
        const dev: DriveEntry = self.devices.items[did].drives.items[drvid];
        return dev.writeb(self.devices.items[did].self, lba, blockno, buf, vmm_ctx);
    }
    pub fn read_min(self: *Dtree, did: u16, drvid: u16, lba: u64, blockno: u16, buf: [*]u8, vmm_ctx: *vmm.VmmFreeList) anyerror!void {
        const dev = self.devices.items[did].drives.items[drvid];
        // dbg.printf("readmin called. drv: {any}\n", .{dev});
        // dbg.printf("dev: {any}, {any}\n", .{ self.devices.items[did].self, self.devices.items[did] });
        // var ctr: usize = 0;
        // for (self.devices.items) |i| {
        //     dbg.printf("ctr: {}, i:{}\n", .{ ctr, i });
        //     for (i.drives.items) |j| {
        //         dbg.printf("\tj: {any}\n", .{j});
        //     }
        //     ctr += 1;
        // }

        return dev.readmin(self.devices.items[did].self, lba, blockno, buf, vmm_ctx);
    }
    pub fn write_min(self: *Dtree, did: u16, drvid: u16, lba: u64, blockno: u16, buf: [*]u8, vmm_ctx: *vmm.VmmFreeList) anyerror!void {
        const dev: DriveEntry = self.devices.items[did].drives.items[drvid];
        return dev.writemin(self.devices.items[did].self, lba, blockno, buf, vmm_ctx);
    }
    ///pretty much useless but looks prettier
    pub inline fn attach_device(self: *Dtree, dev: Dentry) ?void {
        self.devices.append(dev) catch return null;
    }
};
pub var gdtree: Dtree = undefined;
pub fn init() void {
    const arr = std.ArrayList(Dentry).init(alloc.gl_alloc);
    gdtree.devices = arr;
}
