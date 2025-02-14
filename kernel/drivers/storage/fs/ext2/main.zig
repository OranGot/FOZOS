const nvme = @import("../../NVMe/nvme.zig");
pub const ext2Superblock = extern struct {
    n_inode: u32,
    fs_b: u32,
    su_b: u32,
    un_b: u32,
    un_inode: u32,
    sb_block: u32,
    block_size: u32,
    frag_size: u32,
    block_in_b_group: u32,
    frag_in_b_group: u32,
    inodes_in_b_group: u32,
    last_mnt_time: u32,
    last_write_time: u32,
    no_mounts_since_last_ccheck: u16,
    no_mounts_before_ccheck: u16,
    signature: u16,
    fsstate: u16,
    errordt: u16,
    minor_version: u16,
    last_ccheck_time: u32,
    interval_ccheck: u32,
    osid: u32,
    major_v: u32,
    reserved_block_uid: u16,
    reserved_block_gid: u16,
    //ext
    first_nr_inode: u32,
    inode_size: u16,
    superblock_block_group: u16,
    optional_features: u32,
    required_features: u32,
    FS_ID: [16]u8,
    vname: [16:0]u8,
    last_mnt_path: [64:0]u8,
    compression_algo_used: u32,
    no_prealloc_block_pf: u8,
    no_prealloc_blocks_pd: u8,
    unused: u16,
    j_id: [16]u8,
    j_inode: u32,
    orphan_list: u32,
};
const std = @import("std");
const dbg = @import("../../../dbg/dbg.zig");

pub const Ext2 = struct {
    sb: *ext2Superblock,
    partoffset: u64,
    pub fn read_superlock(self: *Ext2, partoffset: u64) ?ext2Superblock {
        const result = nvme.lnvme.read(2, 2, true) catch return null;
        const sb: ext2Superblock = std.mem.bytesToValue(ext2Superblock, (result));
        if (sb.signature != 0xef53) {
            dbg.printf("sb: {any}\n", .{sb});
            dbg.printf("result: {s}\n", .{result});
            return null;
        }
        self.partoffset = partoffset;
        return sb;
    }
    pub fn init(low: u64, high: u64) ?*Ext2 {}
};
