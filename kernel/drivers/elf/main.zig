const std = @import("std");
const ObjectFiletype = enum(u16) {
    UNKNOWN = 0,
    RELOC_FILE = 1,
    EXEC_FILE = 2,
    SHARED_OBJ = 3,
    CORE_FILE = 4,
};
const TargetISA = enum(u16) {
    NO_SPEC = 0,
    SPARC = 2,
    X86 = 3,
    MIPS = 8,
    POWER_PC = 0x14,
    ARM = 0x28,
    SuperH = 0x2A,
    IA_64 = 0x32,
    X86_64 = 0x3E,
    AARCH_64 = 0xB7,
    RISC_V = 0xF3,
};
pub const Header = extern struct {
    sign: [4]u8,
    bit_size: u8,
    endianiness: u8,
    v: u8,
    ABI: u8,
    further_ABI: u8,
    pad: [7]u8,
    obj_ftype: ObjectFiletype,
    target_ISA: TargetISA,
    version: u32 = 1,
    prog_entry_offset: u64,
    prog_header_t_offset: u64,
    sec_header_t_offset: u64,
    flags: u32,
    header_size: u16,
    prog_header_table_esize: u16,
    prog_header_table_entry_no: u16,
    sec_header_table_esize: u16,
    sec_header_table_entry_no: u16,
    sec_header_string_table_index: u16,
};
pub const ProgHeader32 = extern struct {
    seg_t: u32,
    data_offset: u32,
    vaddr_offset: u32,
    seg_paddr: u32,
    size_in_file: u32,
    size_in_mem: u32,
    flags: u32,
    alignement: u32,
};
pub const ProgHeader64 = extern struct {
    seg_t: u32,
    flags: u32,
    data_offset: u64,
    vaddr_offset: u64,
    paddr_offset: u64,
    size_in_file: u64,
    size_in_mem: u64,
    alignement: u64,
};
const EXEC: u32 = 1;
const WRITE: u32 = 2;
const READ: u32 = 4;
const ext2 = @import("../storage/fs/ext2/main.zig");
const vmm = @import("../../HAL/mem/vmm.zig");
const alloc = @import("../../HAL/mem/alloc.zig");
const dbg = @import("../dbg/dbg.zig");
const pmm = @import("../../HAL/mem/pmm.zig");
const proc = @import("../../proc/sched.zig");
pub fn load_elf(path: []const u8, ctx: *vmm.VmmFreeList) anyerror!*proc.Process {
    dbg.printf("LOAD ELF START\n", .{});
    const file = try ext2.gl_ext2.read_file(path, &vmm.home_freelist);
    // dbg.printf("file: {s}\n", .{file});
    defer vmm.home_freelist.free_pages(@intFromPtr(file.ptr), file.len / pmm.BASE_PAGE_SIZE);
    const header: Header = std.mem.bytesToValue(Header, file[0..@sizeOf(Header)]);
    dbg.printf("aquiring header: {any}\n", .{header});
    if (std.mem.eql(u8, &header.sign, &[_]u8{ 0x7f, 'E', 'L', 'F' }) == false or header.bit_size != 2) return error.InvalidSignature;
    dbg.printf("0x{x}, 0x{x}, hsize: {}\n", .{ header.prog_header_table_esize, header.prog_header_table_entry_no, @sizeOf(ProgHeader64) });
    const prog_headers: []align(1) ProgHeader64 = std.mem.bytesAsSlice(ProgHeader64, file[header.prog_header_t_offset .. header.prog_header_table_entry_no * header.prog_header_table_esize + header.prog_header_t_offset]);
    for (prog_headers) |h| {
        dbg.printf("HEADER INFO: {any}\n", .{h});
        if (h.seg_t == 1) {
            const pages = try std.math.divCeil(u64, h.size_in_mem, pmm.BASE_PAGE_SIZE);
            dbg.printf("pages: {}\n", .{pages});
            ctx.map_paddr_to_vaddr(h.paddr_offset, h.vaddr_offset, pages, vmm.PRESENT | vmm.RW | vmm.US) orelse return error.ReserveFail;
            dbg.printf("memset\n", .{});
            @memset(@as([*]u8, @ptrFromInt(h.vaddr_offset & 0xFFFFFFFFFFFFF000))[0 .. pages * pmm.BASE_PAGE_SIZE], 0);
            dbg.printf("memcpy: 0x{x}\n", .{h.vaddr_offset});
            @memcpy(@as([*]u8, @ptrFromInt(h.vaddr_offset)), file[h.data_offset .. h.data_offset + h.size_in_file]);
        }
    }
    dbg.printf("done with headers: prog entry offset: 0x{x}\n", .{header.prog_entry_offset});
    const process: *proc.Process = try alloc.gl_alloc.create(proc.Process);
    process.* = .{
        .ctx = ctx,
        .regs = std.mem.zeroes(proc.FullRegs),
        .cquant = 1,
        .nquant = 1,
        .t = .USER,
    };
    process.regs.cr3 = ctx.cr3;
    process.regs.rip = header.prog_entry_offset;
    return process;
}
