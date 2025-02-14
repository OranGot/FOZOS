const nvme = @import("NVMe/nvme.zig");
const vmm = @import("../../HAL/mem/vmm.zig");
const dtree = @import("../../HAL/storage/dtree.zig");
pub const GPT_PTH = packed struct {
    signature: u64,
    rev: u32,
    hsize: u32,
    checksum: u32,
    r: u32,
    lba: u64,
    alt_lba: u64,
    first_usable_block: u64,
    last_usable_block: u64,
    guid: u128,
    guid_arr_lba: u64,
    no_entries: u32,
    part_e_size: u32,
    part_array_checksm: u32,
};
const part_e = extern struct {
    part_t_guid: [16]u8,
    unique_guid: [16]u8,
    starting_lba: u64,
    ending_lba: u64,
    attr: u64,
};
const SupportedFS = enum {
    ext2,
};
const std = @import("std");
const dbg = @import("../dbg/dbg.zig");
const tty = @import("../tty/tty.zig");
const alloc = @import("../../HAL/mem/alloc.zig");
const pmm = @import("../../HAL/mem/pmm.zig");
pub fn load_partitions() ?void {
    dbg.printf("allocating b\n", .{});
    const b: [*]u8 = @ptrFromInt(vmm.home_freelist.alloc_pages(1, true, vmm.RW | vmm.PRESENT) orelse return null);
    defer {
        dbg.printf("freeing b\n", .{});
        vmm.home_freelist.free_pages(@intFromPtr(b), 1);
    }
    dbg.printf("reading\n", .{});
    dtree.gdtree.read_min(0, 0, 1, 1, b, &vmm.home_freelist) catch return null;
    dbg.printf("read min\n", .{});
    dbg.printf("b as str: {s}\n", .{b[0..512]});
    const header: GPT_PTH = std.mem.bytesToValue(GPT_PTH, b[0..512]);
    if (std.mem.eql(u8, &std.mem.toBytes(header.signature), "EFI PART") == false) {
        tty.printf("GPT signature verify fail\n", .{});
        return null;
    }
    dbg.printf("header: {any}\n", .{header});
    dbg.printf("header part entry size {}\n", .{header.part_e_size});
    // const part_e_size = 128 * (@as(u64, @intCast(1)) << @truncate(header.part_e_size));
    const blockno: u16 = @truncate((header.no_entries * header.part_e_size) / 512);
    // dbg.printf("Reading {} blocks\n", .{blockno});
    const pages = blockno / (dtree.COMMON_BLOCK_SIZE / dtree.gdtree.devices.items[0].drives.items[0].lba_size);
    dbg.printf("pages: {}, lbas per block: {}\n", .{ pages, dtree.COMMON_BLOCK_SIZE / dtree.gdtree.devices.items[0].drives.items[0].lba_size });
    const parr = pmm.request_pages(pages) orelse return null;
    const arr: [*]u8 = @ptrFromInt(vmm.home_freelist.alloc_vaddr(pages, parr, true, vmm.PRESENT | vmm.RW | vmm.CACHE_DISABLE) orelse return null);
    // const arr: [*]u8 = @ptrFromInt(vmm.home_freelist.alloc_pages(blockno / nvme.lnvme.lbas_per_block, true, vmm.PRESENT | vmm.XD | vmm.RW) orelse return null);
    // dbg.printf("allocated arr\n", .{});
    defer vmm.home_freelist.free_pages(@intFromPtr(arr), pages);

    dtree.gdtree.read_min(0, 0, header.guid_arr_lba, blockno, arr, &vmm.home_freelist) catch return null;
    var i: usize = 0;
    // dbg.printf("partition entry size: 0x{X}\n", .{part_e_size});
    // dbg.printf("arr: {any}", .{arr[0 .. blockno * 512]});
    while (i < header.no_entries * header.part_e_size) : (i += header.part_e_size) {
        const pe: part_e = std.mem.bytesToValue(part_e, arr[i .. i + 15]);
        // dbg.printf("tguid: 0x{x}\n", .{pe.part_t_guid});

        if (pe.part_t_guid[0] == 0 and pe.part_t_guid[1] == 0 and pe.part_t_guid[2] == 0 and pe.part_t_guid[3] == 0) return;
        // if (pe.part_t_guid[0] == ) {
        // dbg.printf("linux fs found\n", .{});
        // }
        // dbg.printf("pe: part t guid {any}, uguid: {any}\ns: 0x{x}, e: 0x{x}\npart t guid offset: 0x{x}: 0x{x}\n", .{ pe.part_t_guid, pe.unique_guid, pe.starting_lba, pe.ending_lba, @bitOffsetOf(part_e, "part_t_guid"), @bitOffsetOf(part_e, "unique_guid") });
        dbg.printf("base: {}, high: {}\n", .{ i + 0x38, i + header.part_e_size - 0x38 });
        const name: []align(1) u16 = std.mem.bytesAsSlice(u16, arr[i + 0x38 .. i + header.part_e_size - 0x38]);
        // dbg.printf("name {any}\n", .{name});
        const ascii_name = alloc.gl_alloc.alloc(u8, name.len) catch return null;
        defer alloc.gl_alloc.free(name);
        var e: u8 = 0;
        for (name) |en| {
            ascii_name[e] = @truncate(en);
            e += 1;
        }
        dbg.printf("Found a GPT partition entry: {s}\n", .{ascii_name});
        tty.printf("Found a GPT partition entry: {s}\n", .{ascii_name});

        //TODO: make another way to distinguish between filesystems as this way is suboptimal
        if (ascii_name[0] == 'F') {
            switch (std.meta.stringToEnum(SupportedFS, ascii_name[1..4]) orelse {
                dbg.printf("unsupported fs detected: {s}\n", .{ascii_name[1..5]});
                continue;
            }) {
                .ext2 => {
                    dbg.printf("ext2 found!\n", .{});
                },
            }
        }
        //currently: first character must be F for initalisable filesystem otherwise fs will be ignored
        //then 4 charactrers the name of the filesystem. other characters are name.
        //if F is not the first character then the whole name is name. F is a way to distinguish between user and system partitions

    }
}
