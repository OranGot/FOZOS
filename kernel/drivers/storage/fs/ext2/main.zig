pub const BlockGroupDescriptor = extern struct {
    block_bitmap_addr: u32,
    inode_bitmap_addr: u32,
    inode_table_start: u32,
    unallocated_blocks: u16,
    unallocated_inodes: u16,
    no_dirs: u16,
    unused: [18]u8,
};
pub const Inode = extern struct {
    type_and_perms: u16,
    uid: u16,
    size_low: u32,
    last_access_time: u32,
    creation_time: u32,
    mod_time: u32,
    del_time: u32,
    guid: u16,
    hard_link_count: u16,
    disk_sectors_used: u32,
    flags: u32,
    OS_specific: u32,
    db_ptr: [12]u32,
    singly_indirect_bptr: u32,
    doubly_indirect_bptr: u32,
    triply_indirect_bptr: u32,
    frag_b_addr: u32,
    OS_specific2: u32,
};
const DirEntryType = enum(u8) {
    UNKNOWN = 0,
    REGULAR_FILE = 1,
    DIRECTORY = 2,
    CHARACTER_DEVICE = 3,
    BLOCK_DEVICE = 4,
    FIFO = 5,
    SOCKET = 6,
    SYMBOLIC_LINK = 7,
};
pub const DirEntry = extern struct {
    inode: u32,
    tot_size: u16,
    name_lenth: u8,
    t_id: u8, //only if the feature bit for directory entries have file type byte is set, else this is the most-significant 8 bits of the Name Length
};
pub const FullDirEntry = struct {
    e: DirEntry,
    name: []u8,
};
pub const ext2Superblock = extern struct {
    n_inode: u32,
    n_blocks: u32,
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
const vmm = @import("../../../../HAL/mem/vmm.zig");
const std = @import("std");
const dbg = @import("../../../dbg/dbg.zig");
const dtree = @import("../../../../HAL/storage/dtree.zig");
const alloc = @import("../../../../HAL/mem/alloc.zig");
const pmm = @import("../../../../HAL/mem/pmm.zig");
pub var gl_ext2: *Ext2 = undefined;
pub const Ext2 = struct {
    sb: ext2Superblock,
    partoffset: u64,
    parthigh: u64,
    lbase: u64,
    dev: u16,
    drv: u16,
    block_group_no: u32,
    block_group_descriptors: [*]BlockGroupDescriptor,
    pub fn read_superlock(self: *Ext2) ?ext2Superblock {
        const result: [*]u8 = @ptrFromInt(vmm.home_freelist.alloc_pages(1, true, vmm.RW | vmm.PRESENT | vmm.CACHE_DISABLE) orelse return null);
        defer vmm.home_freelist.free_pages(@intFromPtr(result), 1);
        const dev: dtree.DriveEntry = dtree.gdtree.devices.items[self.dev].drives.items[self.drv];
        dtree.gdtree.read_min(self.dev, self.drv, self.partoffset + 1024 / dev.lba_size, 1024 / dev.lba_size, result, &vmm.home_freelist) catch return null;
        const sb: ext2Superblock = std.mem.bytesToValue(ext2Superblock, (result[0..1024]));
        if (sb.signature != 0xef53) {
            dbg.printf("Incorrect ext2 signature: {any}\n", .{sb});
            return null;
        }
        dbg.printf("Ext2 filesystem successfully validated: {any}\n", .{sb});
        dbg.printf("vname: {s}\n", .{sb.vname});
        if (@as(u64, @intCast(1024)) << @truncate(sb.block_size) != 0x1000) {
            dbg.printf("block size incorrect\n", .{});
            return null;
        }
        @import("../../../../arch/x64/paging/pageframe.zig").dump_stack_values();
        dbg.printf("block size\n", .{});
        return sb;
    }
    fn get_inode(self: *Ext2, inode_no: u32, buf: *Inode) anyerror!void {
        const block_group = (inode_no - 1) / self.sb.inodes_in_b_group;
        // dbg.printf("inode number: {}\n", .{inode_no});
        const base = self.block_group_descriptors[block_group].inode_table_start + self.lbase;
        var b: [*]u8 = @ptrFromInt(vmm.home_freelist.alloc_pages(1, true, vmm.RW | vmm.PRESENT) orelse return error.AllocFail);
        // dbg.printf("base: 0x{x}\n", .{base});
        const index = (inode_no - 1) % self.sb.inodes_in_b_group;
        const block = index * self.sb.inode_size / dtree.COMMON_BLOCK_SIZE;
        // dbg.printf("block offset: {}\n", .{block});
        // dbg.printf("reading block: {}\n", .{self});
        try dtree.gdtree.read_block(self.dev, self.drv, base + block, 1, b, &vmm.home_freelist);
        // dbg.printf("reading block done\n", .{});
        // dbg.printf("inode {s} \n", .{b[0..pmm.BASE_PAGE_SIZE]});
        buf.* = std.mem.bytesToValue(Inode, b[index * self.sb.inode_size % dtree.COMMON_BLOCK_SIZE .. index * self.sb.inode_size % dtree.COMMON_BLOCK_SIZE + @sizeOf(Inode)]);
    }
    fn get_inode_contents(self: *Ext2, inode: *Inode, buf: [*]u8, vmm_ctx: *vmm.VmmFreeList) anyerror!void {
        const bsize = try std.math.divCeil(u32, inode.size_low, pmm.BASE_PAGE_SIZE);
        dbg.printf("inode: {any}\n", .{inode});
        if (bsize > 12) {
            dbg.printf("reading singly indirect block pointers\n", .{});
            const tmp: [*]u32 = @ptrFromInt(vmm.home_freelist.alloc_pages(1, true, vmm.PRESENT | vmm.XD) orelse return error.AllocFail);
            try dtree.gdtree.read_block(self.dev, self.drv, self.lbase + inode.singly_indirect_bptr, 1, @ptrCast(tmp), &vmm.home_freelist);
            defer vmm.home_freelist.free_pages(@intFromPtr(tmp), 1);
            for (0..dtree.COMMON_BLOCK_SIZE / 4) |i| {
                if (tmp[i] != 0) {
                    try dtree.gdtree.read_block(self.dev, self.drv, tmp[i], 1, buf[(12 + i) * pmm.BASE_PAGE_SIZE .. (13 + i) * pmm.BASE_PAGE_SIZE].ptr, &vmm.home_freelist);
                } else break;
            }
        }
        for (0..bsize) |i| {
            // dbg.printf("reading block: 0x{x}\n", .{self.lbase + inode.db_ptr[i]});
            try dtree.gdtree.read_block(self.dev, self.drv, self.lbase + inode.db_ptr[i], 1, buf[i * pmm.BASE_PAGE_SIZE .. (i + 1) * pmm.BASE_PAGE_SIZE].ptr, vmm_ctx);
            dbg.printf("read block: {s}\n", .{buf[i * pmm.BASE_PAGE_SIZE .. (i + 1) * pmm.BASE_PAGE_SIZE]});
        }
    }
    fn print_root(self: *Ext2) anyerror!void {
        // dbg.printf("dev: {}, drv: {}\n", .{ self.dev, self.drv });
        const root_indode: *Inode = try alloc.gl_alloc.create(Inode);
        // dbg.printf("root inode addr: {*} self base: {*}, self top: 0x{X}\n", .{ root_indode, self, @intFromPtr(self) + @sizeOf(Ext2) });
        // dbg.printf("getting root inode\n", .{});
        try self.get_inode(2, root_indode);
        // dbg.printf("got inode {any}\n", .{root_indode});
        const root_buf: [*]u8 = @ptrFromInt(vmm.home_freelist.alloc_pages(try std.math.divCeil(u32, root_indode.size_low, pmm.BASE_PAGE_SIZE), true, vmm.PRESENT) orelse return error.alloc_fail);
        try self.get_inode_contents(root_indode, root_buf, &vmm.home_freelist);
        var byte: usize = 0;
        while (byte < root_indode.size_low) {
            const entry: DirEntry = std.mem.bytesToValue(DirEntry, root_buf[byte .. byte + @sizeOf(DirEntry)]);
            const name: []u8 = std.mem.bytesAsSlice(u8, root_buf[byte + @sizeOf(DirEntry) .. entry.tot_size + byte]);
            dbg.printf("found root directory entry: {s}\nentry: {any}\n", .{ name, entry });
            byte += entry.tot_size;
        }
    }
    pub fn read_file(self: *Ext2, path: []const u8, ctx: *vmm.VmmFreeList) anyerror![]u8 {
        dbg.printf("STARTING READ FILE\n", .{});
        // var inode: Inode = std.mem.zeroes(Inode);
        // try self.get_inode(2, &inode);
        var cwd: []FullDirEntry = try self.read_dir(2, ctx);
        var sq = std.mem.tokenizeSequence(u8, path, "/");
        // dbg.printf("sequence tokenized: {any}", .{sq});
        // dbg.printf("cwd: {any}\n", .{cwd.items});
        while (true) {
            if (sq.next()) |t| {
                // dbg.printf("next: {s}\n", .{t});
                for (cwd) |e| {
                    // dbg.printf("ptr: {any} item: {s}\n", .{ e.name.ptr, e.name });
                    if (std.mem.eql(u8, e.name, t) == true) {
                        if (e.e.t_id == 2) {
                            // dbg.printf("opening directory: {s}\n", .{t});
                            cwd = try self.read_dir(e.e.inode, ctx);
                        } else {
                            if (sq.peek() != null) {
                                return error.PathNotFull;
                            }
                            // dbg.printf("opening file: {s}\n", .{t});
                            var f_inode: Inode = std.mem.zeroes(Inode);
                            try self.get_inode(e.e.inode, &f_inode);
                            dbg.printf("got inode: {}\n", .{e.e.inode});
                            const buf: [*]u8 = @ptrFromInt(ctx.alloc_pages(try std.math.divCeil(u32, f_inode.size_low, pmm.BASE_PAGE_SIZE), true, vmm.RW | vmm.PRESENT) orelse return error.AllocFail);
                            try self.get_inode_contents(&f_inode, buf, ctx);
                            // dbg.printf("buf: {s}\n", .{buf[0..f_inode.size_low]});
                            return buf[0..f_inode.size_low];
                        }
                    } //else dbg.printf("entry is not equal\n", .{});
                }
            }
        }
    }
    pub fn read_dir(self: *Ext2, no_inode: u32, ctx: *vmm.VmmFreeList) anyerror![]FullDirEntry {
        var inode: Inode = std.mem.zeroes(Inode);
        try self.get_inode(no_inode, &inode);
        const val: [*]u8 = @ptrFromInt(ctx.alloc_pages(inode.size_low / pmm.BASE_PAGE_SIZE, true, vmm.PRESENT | vmm.RW | vmm.XD) orelse return error.AllocFail);
        // vmm.home_freelist.free_pages(@intFromPtr(val), inode.size_low / pmm.BASE_PAGE_SIZE);
        try self.get_inode_contents(&inode, val, ctx);
        var byte: usize = 0;
        var ectr: usize = 0;
        var r = std.ArrayList(FullDirEntry).init(alloc.gl_alloc);
        while (byte < inode.size_low) {
            const entry: DirEntry = std.mem.bytesToValue(DirEntry, val[byte .. byte + @sizeOf(DirEntry)]);
            const name: []u8 = std.mem.bytesAsSlice(u8, val[byte + @sizeOf(DirEntry) .. entry.name_lenth + byte + @sizeOf(DirEntry)]);
            // dbg.printf("appending name: {s}, {any}, {}\n", .{ name, name.ptr, name.len });

            try r.append(FullDirEntry{
                .e = entry,
                .name = name,
            });
            // dbg.printf("1\n", .{});
            // dbg.printf("found directory entry: {s}\nentry: {any}\n", .{ name, entry });
            byte += entry.tot_size;
            ectr += 1;
        }

        return r.items;
    }
    pub fn write_file(self: *Ext2, path: []const u8, buf: [*]u8, bytes: u64, ctx: *vmm.VmmFreeList) anyerror!void {
        dbg.printf("STARTING WRITE FILE\n", .{});
        // var inode: Inode = std.mem.zeroes(Inode);
        // try self.get_inode(2, &inode);
        var cwd: []FullDirEntry = try self.read_dir(2, ctx);
        var sq = std.mem.tokenizeSequence(u8, path, "/");
        // dbg.printf("sequence tokenized: {any}", .{sq});
        // dbg.printf("cwd: {any}\n", .{cwd.items});
        while (true) {
            if (sq.next()) |t| {
                // dbg.printf("next: {s}\n", .{t});
                for (cwd) |e| {
                    // dbg.printf("ptr: {any} item: {s}\n", .{ e.name.ptr, e.name });
                    if (std.mem.eql(u8, e.name, t) == true) {
                        if (e.e.t_id == 2) {
                            // dbg.printf("opening directory: {s}\n", .{t});
                            cwd = try self.read_dir(e.e.inode, ctx);
                        } else {
                            if (sq.peek() != null) {
                                return error.PathNotFull;
                            }
                            // dbg.printf("opening file: {s}\n", .{t});
                            var f_inode: Inode = std.mem.zeroes(Inode);
                            try self.get_inode(e.e.inode, &f_inode);
                            try self.write_to_inode(buf, bytes, &f_inode);
                            return;
                        }
                    } else dbg.printf("entry is not equal\n", .{});
                }
            }
        }
    }
    ///Fully overwrites the contents of the inode.
    pub fn write_to_inode(self: *Ext2, buf: [*]u8, bytes: u64, inode: *Inode) anyerror!void {
        if (bytes > pmm.BASE_PAGE_SIZE * 12) {
            @panic("TODO! support bigger inodes\n");
        }
        // dbg.printf("writing to inode: {}\n", .{bytes});
        const blocks = try std.math.divCeil(u64, bytes, dtree.COMMON_BLOCK_SIZE);
        for (0..blocks) |i| {
            // dbg.printf("writing values from 0x{x}, ptr: 0x{X}, buf: {s}\n", .{ i * pmm.BASE_PAGE_SIZE, inode.db_ptr[i], buf[i * pmm.BASE_PAGE_SIZE .. (i + 1) * pmm.BASE_PAGE_SIZE] });
            // dbg.printf("buf ptr: {any}\n", .{buf});
            try dtree.gdtree.write_block(self.dev, self.drv, self.lbase + inode.db_ptr[i], 1, buf[i * pmm.BASE_PAGE_SIZE .. (i + 1) * pmm.BASE_PAGE_SIZE].ptr, &vmm.home_freelist);
            // dbg.printf("end2\n", .{});
            // if (bytes < pmm.BASE_PAGE_SIZE * i) return;
        }
        // dbg.printf("inode write done\n", .{});
    }
    pub fn mkdir(self: *Ext2, path: []const u8, ctx: *vmm.VmmFreeList) anyerror!void {
        var cwd: []FullDirEntry = try self.read_dir(2, ctx);
        var cwinode = 2;
        var sq = std.mem.tokenizeSequence(u8, path, "/");
        // dbg.printf("sequence tokenized: {any}", .{sq});
        // dbg.printf("cwd: {any}\n", .{cwd.items});
        var t = sq.next();
        while (t != null) : (t = sq.next()) {
            // dbg.printf("next: {s}\n", .{t});
            for (cwd) |e| {
                // dbg.printf("ptr: {any} item: {s}\n", .{ e.name.ptr, e.name });
                if (std.mem.eql(u8, e.name, t) == true) {
                    // dbg.printf("opening directory: {s}\n", .{t});
                    cwd = try self.read_dir(e.e.inode, ctx);
                    cwinode = e.e.inode;
                }
            }
        }
        var f_inode: Inode = std.mem.zeroes(Inode);
        try self.get_inode(2, &f_inode);
        const buf: [*]u8 = @ptrFromInt(ctx.alloc_pages(std.math.divCeil(u32, f_inode.size_low, pmm.BASE_PAGE_SIZE), true, vmm.RW | vmm.PRESENT) orelse return error.AllocFail);
        try self.get_inode_contents(&f_inode, buf, ctx);
        var byte = 0;
        var entry: DirEntry = undefined;
        while (byte < f_inode.size_low) {
            entry = std.mem.bytesToValue(DirEntry, buf[byte .. byte + @sizeOf(DirEntry)]);
            byte += entry.tot_size;
        }
    }
    // pub fn touch(self: *Ext2, path: []const u8) anyerror!void {}
    pub fn init(low: u64, high: u64, dev: u16, drv: u16) ?*Ext2 {
        const lext2 = alloc.gl_alloc.create(Ext2) catch return null;
        lext2.partoffset = low;
        // dbg.printf("paroffset in 512 byte sectors: {}\n", .{lext2.partoffset});
        lext2.parthigh = high;
        lext2.dev = dev;
        lext2.drv = drv;
        lext2.sb = lext2.read_superlock() orelse return null;

        dbg.printf("read superblock\n", .{});
        lext2.lbase = low / (dtree.COMMON_BLOCK_SIZE / dtree.gdtree.devices.items[dev].drives.items[drv].lba_size);
        dbg.printf("lbase: {}\n", .{lext2.lbase});

        lext2.block_group_no = std.math.divCeil(u32, lext2.sb.n_blocks, lext2.sb.block_in_b_group) catch return null;

        const pageno: u16 = @truncate(std.math.divCeil(u32, @sizeOf(BlockGroupDescriptor) * lext2.block_group_no, pmm.BASE_PAGE_SIZE) catch return null);
        // dbg.printf("pageno: {}", .{pageno});
        lext2.block_group_descriptors = @ptrFromInt(vmm.home_freelist.alloc_pages(pageno, true, vmm.PRESENT) orelse return null);
        // dbg.printf("finding descriptors2\n", .{});
        // defer vmm.home_freelist.free_pages(@intFromPtr(lext2.block_group_descriptors), 1);
        dtree.gdtree.read_block(dev, drv, lext2.lbase + 1, pageno, @ptrCast(lext2.block_group_descriptors), &vmm.home_freelist) catch return null;
        // dbg.printf("finding descriptors3\n", .{});
        for (0..lext2.block_group_no) |i| {
            dbg.printf("block bitmap address: 0x{x}, inode bitmap address: 0x{x}, inode table start: 0x{x}, unallocated blocks: {}, unallocated inodes: {}, dirs: {}\n", .{ lext2.block_group_descriptors[i].block_bitmap_addr, lext2.block_group_descriptors[i].inode_bitmap_addr, lext2.block_group_descriptors[i].inode_table_start, lext2.block_group_descriptors[i].unallocated_blocks, lext2.block_group_descriptors[i].unallocated_inodes, lext2.block_group_descriptors[i].no_dirs });
        }
        lext2.print_root() catch return null;
        // const file = lext2.read_file("/syscfg/test.txt/", &vmm.home_freelist) catch return null;
        // defer alloc.gl_alloc.free(file);
        // dbg.printf("read the test file: {s}\n", .{file});
        // dbg.printf("write to the test file\n", .{});
        // lext2.write_file("/syscfg/test.txt/", file.ptr, file.len, &vmm.home_freelist) catch return null;
        // dbg.printf("read the test file: {s}\n", .{lext2.read_file("/syscfg/test.txt/", &vmm.home_freelist) catch |e| {
        // dbg.printf("error: {}\n", .{e});
        // return null;
        // }});
        return lext2;
    }
};
