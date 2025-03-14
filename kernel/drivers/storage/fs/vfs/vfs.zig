//!VFS - abstraction over filesystems.
//!It is very simple for now
const std = @import("std");
// const FnodeType = enum(u8) {
//     UD = 0,
//     DIRECTORY = 1,
//     FILE = 2,
//     FIFO = 3,
//     DEVICE = 4,
//     MOUNT_POINT = 5,
//
// };
// pub const Fnode = struct {
//     t: FnodeType,
//     name: []const u8,
//     cr_t: u32,
//     mod_t: u32,
//     read_t: u32,
//     ref_ctr: u16,
//
// };

pub const Mount = struct {
    path: []const u8,
    did: u16,
    drvid: u16,
    b_addr: u64,
    h_addr: u64,
    cr_t: u64,
    ctx: *anyopaque,
    pub fn open_file(rel_path: []u8) void {}
};
pub const VFS = struct {
    mnt_arr: std.ArrayList(Mount),
    pub fn mount(mount: *Mount, path: []const u8) anyerror!void {}
    pub fn init() void {}
};
