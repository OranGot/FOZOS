const std = @import("std");
const builtin = @import("builtin");
const target = builtin.target.cpu.arch;
const pmm = @import("pmm.zig");
pub const VmmFreeListEntry = extern struct {
    t: VmmFreeListEntryType = .UNDEFINED,
    vbase: usize,
    len: usize,
    pbase: usize = 0,
    mapped: bool = false,
    next: ?*VmmFreeListEntry = null,
};
pub const VmmFreeListEntryType = enum(u8) {
    K_FREE = 4,
    K_OCCUPIED = 1,
    U_FREE = 2,
    U_OCCUPIED = 3,
    UNDEFINED = 0,
    RESTRICTED = 5, //This is only for 0x0 - 0x1000 area of memory. For null deref to crash
};
const x64_pf = @import("../../arch/x64/paging/pageframe.zig");
pub const PRESENT = switch (target) {
    .x86_64 => 1,
    else => @compileError("Unknown architecture!!!\n"),
};
pub const RW = switch (target) {
    .x86_64 => 1 << 1,
    else => @compileError("Unknown architecture!!!\n"),
};

pub const US = switch (target) {
    .x86_64 => 1 << 2,
    else => @compileError("Unknown arch\n"),
};
pub const PWT = switch (target) {
    .x86_64 => 1 << 3,
    else => @compileError("Unknown arch\n"),
};
pub const CACHE_DISABLE = switch (target) {
    .x86_64 => 1 << 4,
    else => @compileError("Unknown arch\n"),
};
pub const GLOBAL = switch (target) {
    .x86_64 => 1 << @bitOffsetOf(x64_pf.PML1_entry, "global"),
    else => @compileError("Unknown arch\n"),
};
pub const PK = switch (target) {
    .x86_64 => 1 << @bitOffsetOf(x64_pf.PML1_entry, "PK"),
    else => @compileError("Unknown arch\n"),
};
pub const XD = switch (target) {
    .x86_64 => 1 << @bitOffsetOf(x64_pf.PML1_entry, "XD"),
    else => @compileError("Unknown arch\n"),
};
const dbg = @import("../../drivers/dbg/dbg.zig");
const pio = @import("../../drivers/drvlib/drvcmn.zig");
pub const VmmEntryTable = extern struct {
    next: ?*VmmEntryTable,
    t: [120]VmmFreeListEntry,
};
pub const VmmFreeList = extern struct {
    first: *VmmEntryTable,
    cr3: usize,
    ///Finds a corresponding physical address of the virtual address
    pub fn vaddr_to_paddr(self: *VmmFreeList, vaddr: usize) ?usize {
        switch (target) {
            .x86_64 => return @import("../../arch/x64/paging/vmm.zig").vaddr_to_paddr(self, vaddr),
            else => @compileError("Unsupported arch!!!"),
        }
    }
    ///finds a corresponding virtual address of the physical address
    pub fn paddr_to_vaddr(self: *VmmFreeList, paddr: usize) ?usize {
        switch (target) {
            .x86_64 => return @import("../../arch/x64/paging/vmm.zig").paddr_to_vaddr(self, paddr),
            else => @compileError("Unsupported arch!!!\n"),
        }
    }
    pub fn alloc_vaddr(self: *VmmFreeList, pageno: usize, paddr: usize, kspace: bool, flags: usize) ?usize {
        switch (target) {
            .x86_64 => return @import("../../arch/x64/paging/vmm.zig").alloc_vaddr(self, pageno, paddr, kspace, flags),
            else => @compileError("Unsupported arch!!!\n"),
        }
    }
    pub fn free_vaddr(self: *VmmFreeList, base: usize, pageno: u64) void {
        switch (target) {
            .x86_64 => return @import("../../arch/x64/paging/vmm.zig").free_vaddr(self, base, pageno),
            else => @compileError("Unsupported arch!!!\n"),
        }
    }
    /// WARNING: only reserves on the allocator NOT on page tables
    pub fn reserve_vaddr(self: *VmmFreeList, vbase: usize, pbase: usize, len: usize, kspace: bool, mapped: bool) ?void {
        var t: VmmFreeListEntryType = .U_OCCUPIED;
        if (kspace == true) {
            t = .K_OCCUPIED;
        }
        _ = self.insert_entry(VmmFreeListEntry{
            .vbase = vbase,
            .t = t,
            .pbase = pbase,
            .len = len,
            .mapped = mapped,
        }) orelse return null;
    }
    pub fn alloc_entry(self: *VmmFreeList) ?*VmmFreeListEntry {
        var cwtable: *VmmEntryTable = self.first;
        while (true) {
            for (&cwtable.t) |*e| {
                if (e.t == .UNDEFINED) {
                    e.t = .RESTRICTED;
                    return e;
                }
            }
            if (cwtable.next) |n| {
                cwtable = n;
            } else @panic("TODO: Vmm allocate more tables");
        }
    }
    pub fn insert_entry(self: *VmmFreeList, e: VmmFreeListEntry) ?void {
        var cwnode: *VmmFreeListEntry = &self.first.t[0];
        var pnode: ?*VmmFreeListEntry = null;
        var ctr: usize = 0;

        while (cwnode.vbase + cwnode.len <= e.vbase) {
            if (cwnode.next) |n| {
                pnode = cwnode;
                cwnode = n;
            } else { //address out of range
                const e1 = self.alloc_entry() orelse return null;
                e1.* = e;
                cwnode.next = e1;
                return;
            }
            ctr += 1;
        }
        if (cwnode.vbase == e.vbase and cwnode.len == e.len) { //|*********|
            cwnode.t = e.t;
            cwnode.pbase = e.pbase;
            return;
        }
        if (cwnode.vbase == e.vbase and cwnode.len > e.len) { // |****-----|
            const ins_e = self.alloc_entry() orelse return null;
            ins_e.* = e;
            cwnode.vbase += e.len;
            cwnode.pbase += e.len;
            ins_e.next = cwnode;
            if (pnode) |pn| {
                pn.next = ins_e;
            }
            return;
        }
        if (cwnode.vbase + cwnode.len == e.vbase + e.len) { // |-----****|
            const ins_e = self.alloc_entry() orelse return null;
            ins_e.* = e;
            ins_e.next = cwnode.next;
            cwnode.next = ins_e;
            cwnode.len = e.vbase - cwnode.vbase;
            return;
        }
        // |cwnode-ins_e2-ins_e1|
        // |--****--|
        if (cwnode.vbase < e.vbase and e.len < cwnode.len) {
            const ins_e1 = self.alloc_entry() orelse return null;
            const ins_e2 = self.alloc_entry() orelse return null;
            ins_e1.* = cwnode.*;

            ins_e2.* = e;
            cwnode.len = e.vbase - cwnode.vbase;
            ins_e1.next = cwnode.next;
            cwnode.next = ins_e2;
            ins_e2.next = ins_e1;
            ins_e1.vbase = ins_e2.vbase + ins_e2.len;
            ins_e1.pbase = ins_e2.pbase + ins_e2.len;
            return;
        } //                         fnode        e     cwnode
        if (e.len > cwnode.len) { //|----****|******|***---|
            var loopctr: usize = 0;
            const fnode: *VmmFreeListEntry = cwnode;
            while (cwnode.vbase + cwnode.len < e.vbase + e.len) {
                loopctr += 1;
                if (cwnode.next) |n| cwnode = n else return null;
            }
            fnode.len = e.vbase - fnode.vbase;
            const e1 = self.alloc_entry() orelse return null; //TODO: make it free
            fnode.next = e1;
            e1.* = e;
            e1.next = cwnode;
            if (cwnode.mapped == true) {
                @panic("TODO VMM!");
            }
            cwnode.vbase = e.vbase + e.len;
            return;
        }
        @panic("TODO VMM! ENTRY NOT HANDLED!");
    }

    ///simple abstraction for allocating pages
    pub fn alloc_pages(self: *VmmFreeList, pageno: u64, kspace: bool, flags: usize) ?usize {
        const p = pmm.request_pages(pageno) orelse return null;
        // dbg.printf("allocated physical: 0x{X}\n", .{p});
        return self.alloc_vaddr(pageno, p, kspace, flags);
    }
    ///simple abstraction for freeing pages
    pub fn free_pages(self: *VmmFreeList, base: usize, pageno: u64) void {
        // dbg.printf("freeing page: 0x{X}, {}\n", .{ base, pageno });
        pmm.free_pages(self.vaddr_to_paddr(base) orelse {
            dbg.printf("Warning, free failed\n", .{});
            return;
        }, pageno) orelse {
            dbg.printf("Warning, free failed\n", .{});
            return;
        };
        self.free_vaddr(base, pageno);
    }
};
pub var home_freelist: VmmFreeList = undefined;
pub var first_table: VmmEntryTable = undefined;
