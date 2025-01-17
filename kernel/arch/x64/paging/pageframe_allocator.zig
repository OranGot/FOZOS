const limine = @import("limine");
const pageframe = @import("pageframe.zig");
const dbg = @import("../../../drivers/dbg/dbg.zig");
const vmm = @import("vmm.zig");
pub const list_entry_type = enum(u8) {
    FREE = 0,
    RESERVED = 1,
    NO_FREE_RESERVED = 2,
    OCCUPIED = 3,
    UNDEFINED = 4,
};
pub const list_entry = extern struct {
    base: u64,
    high: u64,
    type: list_entry_type = .UNDEFINED,
    next: ?*list_entry,
};
pub const header_page = extern struct {
    next: ?*header_page,
    table: [127]list_entry,
    avl: [21]u8,
};
fn insert_entry(e: list_entry) ?void {
    var cwnode: *list_entry = &home_pageframe_page.table[0];
    var pnode: ?*list_entry = null;
    while (cwnode.high < e.base) {
        if (cwnode.next) |n| {
            pnode = cwnode;
            cwnode = n;
        } else break;
    }

    if (cwnode.base == e.base and cwnode.high == e.high and cwnode.type == e.type) return null;
    if (cwnode.base == e.base and cwnode.high == e.high) { // |*****|
        dbg.printf("c1\n", .{});
        cwnode.type = e.type;
        return;
    }
    if (cwnode.base == e.base and cwnode.high > e.high) { // |******---|
        dbg.printf("c2\n", .{});
        const e1 = allocate_list_entry() orelse return null;
        e1.* = e;
        e1.next = cwnode;
        cwnode.base = e.high;
        return;
    }
    if (cwnode.high == e.high) { //|---*******|
        dbg.printf("c3\n", .{});
        const e1 = allocate_list_entry() orelse return null;
        e1.* = e;
        e1.next = cwnode.next;
        cwnode.next = e1;
        return;
    }
    //                                                          e1   e2
    if (cwnode.base < e.base and cwnode.high > e.high) { // |---*****---|
        dbg.printf("c4\n", .{});
        const e1 = allocate_list_entry() orelse return null;
        const e2 = allocate_list_entry() orelse return null;
        e1.* = e;
        e2.* = cwnode.*;
        cwnode.high = e.base;
        e2.next = cwnode.next;
        e2.base = e.high;
        cwnode.next = e1;
        e1.next = e2;
        return;
    }
    // in case such virtual address isn't yet mapped
    dbg.printf("c5\n", .{});
    const e1 = allocate_list_entry() orelse return null;
    e1.* = e;
    if (pnode) |p| {
        p.next = e1;
    }
    e1.next = cwnode;
    // @panic("TODO! ");
}
const tty = @import("../../../drivers/tty/tty.zig");
var home_pageframe_page: header_page = undefined;
pub export var mmap_request: limine.MemoryMapRequest = .{};
pub fn print_mem() void {
    if (mmap_request.response) |r| {
        for (r.entries()) |e| {
            tty.printf("base: 0x{x} length: 0x{x}, type: {s}\n", .{ e.base, e.length, @tagName(e.kind) });
        }
    }
}
var fbase: usize = 0;
var flen: usize = 0;
pub inline fn setup() void {
    var ctr: usize = 0;
    var kbase: usize = 0;
    var klen: usize = 0;
    if (mmap_request.response) |r| {
        for (r.entries()) |i| {
            home_pageframe_page.table[ctr] = list_entry{
                .next = null,
                .base = i.base,
                .high = i.base + i.length,
                .type = switch (i.kind) {
                    .usable => list_entry_type.FREE,
                    .acpi_reclaimable => list_entry_type.FREE,
                    .bootloader_reclaimable => list_entry_type.FREE,
                    .kernel_and_modules => d: {
                        klen = i.length;
                        kbase = i.base;
                        break :d list_entry_type.NO_FREE_RESERVED;
                    },
                    .framebuffer => e: {
                        flen = i.length;
                        fbase = i.base;
                        break :e list_entry_type.NO_FREE_RESERVED;
                    },
                    else => list_entry_type.NO_FREE_RESERVED,
                },
            };
            if (ctr != 0) {
                home_pageframe_page.table[ctr - 1].next = &home_pageframe_page.table[ctr];
            }
            ctr += 1;
        }
    }
    for (ctr..127) |a| {
        home_pageframe_page.table[a].type = .UNDEFINED;
        home_pageframe_page.table[a].next = null;
    }
    vmm.setup(kbase, klen);
    dbg.printf("setting up paging kernel length: 0x{x}\nframebuffer base: 0x{X}, framebuffer len: 0x{X}\n", .{ klen, fbase, flen });
    pageframe.setup_paging(kbase, klen);
    tty.map_framebuffer(fbase, flen);
    dbg.printf("Mapped framebuffer\n", .{});
    dbg.printf("paging setup!\n", .{});
}

pub const PageRequestError = error{
    OutOfMemory,
    InPageAllocFail,
};
pub const PAGE_SIZE = 4096;
pub fn reserve_address(base: usize, pageno: usize, state: list_entry_type) ?void {
    insert_entry(.{
        .next = null,
        .type = state,
        .base = base,
        .high = base + pageno * PAGE_SIZE,
    }) orelse return null;
}
pub fn request_pages(pageno: u64) ?usize {
    var cwnode: *list_entry = &home_pageframe_page.table[0];
    while (cwnode.type != .FREE or cwnode.high - cwnode.base < PAGE_SIZE * pageno) {
        if (cwnode.next) |n| cwnode = n else return null;
    }
    const base = cwnode.base;
    insert_entry(.{
        .base = cwnode.base,
        .high = cwnode.base + PAGE_SIZE * pageno,
        .type = .OCCUPIED,
        .next = null,
    }) orelse return null;
    return base;
}

const FreeError = error{
    PermissionDenied,
    DoubleFree,
    NoFittingPage,
};

pub fn free_pages(pageno: u64, base: u64) FreeError!void {
    var cw_list_entry: *list_entry = home_pageframe_page.table[0];
    var prev_entry: *list_entry = undefined;

    while (true) {
        if (cw_list_entry.base >> 12 == base >> 12) {
            if (cw_list_entry.type != .OCCUPIED) return error.DoubleFree;
            if (base == cw_list_entry.base and base + pageno * PAGE_SIZE == cw_list_entry.high) {
                cw_list_entry.type = .FREE;
                concat_nodes(cw_list_entry, prev_entry);
                return;
            } else if (base == cw_list_entry.base) {
                const entry = allocate_list_entry().?;
                entry.base = base + PAGE_SIZE * pageno;
                entry.type = .OCCUPIED;
                entry.high = cw_list_entry.high;
                cw_list_entry.high = base + PAGE_SIZE * pageno;
                entry.next = if (cw_list_entry.next) |e| b: {
                    break :b e;
                } else c: {
                    break :c null;
                };
                cw_list_entry.next = entry;
            }
        }
        if (cw_list_entry.next) |e| {
            prev_entry = cw_list_entry;
            cw_list_entry = e;
        } else return error.NoFittingPage;
    }
}
inline fn allocate_list_entry() ?*list_entry {
    var current_header: *header_page = &home_pageframe_page;
    while (true) {
        for (&current_header.table) |*te| {
            if (te.type == .UNDEFINED) {
                te.type = .RESERVED;
                return te;
            }
        }
        if (current_header.next) |n| {
            current_header = n;
        } else {
            const phy = request_pages(1) orelse return null;
            const ne: *header_page = @ptrFromInt(vmm.home_freelist.alloc_vaddr(1, phy, true) orelse return null);
            ne.next = null;
            dbg.printf("allocating new block\n", .{});
            for (&ne.table) |*nte| {
                nte.type = .UNDEFINED;
                nte.next = null;
                nte.base = 0;
                nte.high = 0;
            }
        }
    }
}
inline fn concat_nodes(cnode: *list_entry, lnode: *list_entry) void {
    if (cnode.type == lnode.type) {
        if (cnode.next) |n| {
            if (n.type == cnode.type) {
                lnode.next = n;
                lnode.high = n.high;
                cnode.type = .UNDEFINED;
                n.type = .UNDEFINED;
                return;
            }
        }
        lnode.high = cnode.high;
        if (cnode.next) |n| {
            lnode.next = n;
        } else lnode.next = null;
        cnode.type = .UNDEFINED;
    }
    if (cnode.next) |n| {
        if (cnode.type == n.type) {
            cnode.high = n.high;
            n.type = .UNDEFINED;
            if (n.next) |nn| {
                n.next = nn;
            } else n.next = null;
            return;
        }
    }
}
pub fn init_header_page(page: *header_page) void {
    page.next = null;
    var i: usize = 0;

    while (i < 127) : (i += 1) {
        var next: *list_entry = undefined;
        if (i + 1 < 127) next = &page.table[i + 1];
        page.table[i] = list_entry{
            .next = next,
            .base = 0,
            .type = .UNDEFINED,
            .high = 0,
        };
    }
}
extern fn get_cr3() u64;
