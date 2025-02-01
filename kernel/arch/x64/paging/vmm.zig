//! VMM(Virtual Memory manager) is one of the core structures designed for keeping track of the virtual address space
//! usage. It's designed to be personal for each process
//! Organisation:
//! This is a simple linked list allocator Where each entry can represent an area of continious virtual memory
//! with a constant physical offset
const palloc = @import("pageframe_allocator.zig");
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
pub const PRESENT = 1;
pub const RW = 1 << 1;
pub const US = 1 << 2;
pub const PWT = 1 << 3;
pub const CACHE_DISABLE = 1 << 4;
pub const GLOBAL = 1 << @bitOffsetOf(pf.PML1_entry, "global");
pub const PK = 1 << @bitOffsetOf(pf.PML1_entry, "PK");
pub const XD = 1 << @bitOffsetOf(pf.PML1_entry, "XD");
const dbg = @import("../../../drivers/dbg/dbg.zig");
const pio = @import("../../../drivers/drvlib/drvcmn.zig");
pub const VmmEntryTable = extern struct {
    next: ?*VmmEntryTable,
    t: [120]VmmFreeListEntry,
};
pub const VmmFreeList = extern struct {
    first: *VmmEntryTable,
    cr3: usize,
    //next: *VmmFreeList,
    ///Finds a corresponding physical address of the virtual address
    pub fn vaddr_to_paddr(self: *VmmFreeList, vaddr: usize) ?usize {
        var current_entry: *VmmFreeListEntry = &self.first.t[0];
        while (true) {
            if (current_entry.vbase <= vaddr and current_entry.len + current_entry.vbase >= vaddr and current_entry.mapped != false) {
                return vaddr - current_entry.vbase + current_entry.pbase;
            }
            if (current_entry.next) |n| current_entry = n else return null;
        }
    }
    ///finds a corresponding virtual address of the physical address
    pub fn paddr_to_vaddr(self: *VmmFreeList, paddr: usize) ?usize {
        var current_entry: *VmmFreeListEntry = &self.first.t[0];
        var ctr: usize = 0;
        while (true) {
            if (current_entry.pbase <= paddr and current_entry.len + current_entry.pbase >= paddr and current_entry.mapped != false) {
                return paddr - current_entry.pbase + current_entry.vbase;
            }
            if (current_entry.next) |n| {
                current_entry = n;
            } else return null;
            ctr += 1;
        }
    }
    /// NOTE: this only works if page is mapped into virtual memory otherwise this fails.
    /// The other reason why this could fail is if there is no more memory left
    pub fn alloc_vaddr(self: *VmmFreeList, pageno: usize, paddr: usize, kspace: bool, flags: usize) ?usize {
        const pml4: [*]pf.PML4_entry = @ptrFromInt(self.paddr_to_vaddr(self.cr3) orelse return null);
        var min: pf.virtual_address = @bitCast(@as(usize, 0));
        if (kspace == true) {
            min = @bitCast(pf.KERNEL_VHIGH);
        }
        var p4e: u16 = min.pml4;
        var curfit: usize = 0;
        p4: while (p4e < 512) : (p4e += 1) {
            if (pml4[p4e].present == 1) {
                var pml3: [*]pf.PML3_entry = @ptrFromInt(self.paddr_to_vaddr(pml4[p4e].addr << 12) orelse {
                    curfit = 0;
                    continue :p4;
                });
                var p3e: u16 = min.pml3;
                p3: while (p3e < 512) : (p3e += 1) {
                    if (pml3[p3e].present == 1) {
                        var pml2: [*]pf.PML2_entry = @ptrFromInt(self.paddr_to_vaddr(pml3[p3e].addr << 12) orelse {
                            curfit = 0;
                            continue :p3;
                        });
                        var p2e: u16 = 0;
                        p2: while (p2e < 512) : (p2e += 1) {
                            if (curfit != 0 and pml2[p2e].present == 0) { // attempt to allocate more pml2s
                                const pfpaddr = palloc.request_pages(1) orelse return null;

                                const pfvaddr = self.alloc_vaddr(1, pfpaddr, true, PRESENT | RW | XD) orelse return null;
                                const npml1: [*]pf.PML1_entry = @ptrFromInt(pfvaddr);
                                for (0..512) |e| {
                                    npml1[e] = pf.PML1_entry{
                                        .present = 0,
                                        .rw = 1,
                                    };
                                }
                                pml2[p2e].present = 1;
                                pml2[p2e].addr = @truncate(pfpaddr >> 12);
                                return self.alloc_vaddr(pageno, paddr, kspace, PRESENT | RW | XD);
                            }

                            if (pml2[p2e].present == 1) {
                                const pml2vaddr = self.paddr_to_vaddr(pml2[p2e].addr << 12) orelse {
                                    curfit = 0;
                                    continue :p2;
                                };
                                var pml1: [*]pf.PML1_entry = @ptrFromInt(pml2vaddr);
                                var p1e: u16 = 0;

                                p1: while (p1e < 512) : (p1e += 1) {
                                    if (pml1[p1e].present == 0) {
                                        const addr = @as(usize, @bitCast(pf.virtual_address{
                                            .pml1 = @truncate(p1e),
                                            .pml2 = @truncate(p2e),
                                            .pml3 = @truncate(p3e),
                                            .pml4 = @truncate(p4e),
                                            .offset = 0,
                                        }));
                                        if (pf.make_canonical(addr) < @as(usize, @bitCast(min))) {
                                            continue :p1;
                                        }
                                        curfit += 1;
                                        if (curfit == pageno) {
                                            palloc.reserve_address(paddr, pageno, .OCCUPIED) orelse return null;
                                            const raddr = pf.make_canonical(addr - ((pageno - 1) << 12));
                                            //reserving the addresses on the page table

                                            self.reserve_vaddr(raddr, paddr, pageno * pf.PAGE_SIZE, kspace, true) orelse return null;
                                            var i: usize = 0;
                                            var p_addr: pf.virtual_address = @bitCast(addr);
                                            while (i < pageno) {
                                                const l_addr: pf.virtual_address = @bitCast(raddr + pf.PAGE_SIZE * i);
                                                //pio.invlpg(@as(usize, @bitCast(l_addr)));
                                                if (l_addr.pml4 != p_addr.pml4) {
                                                    pml3 = @ptrFromInt(self.paddr_to_vaddr(pml4[l_addr.pml4].addr << 12) orelse return null);
                                                    pml2 = @ptrFromInt(self.paddr_to_vaddr(pml3[l_addr.pml3].addr << 12) orelse return null);
                                                    pml1 = @ptrFromInt(self.paddr_to_vaddr(pml2[l_addr.pml2].addr << 12) orelse return null);
                                                } else if (l_addr.pml3 != p_addr.pml3) {
                                                    pml2 = @ptrFromInt(self.paddr_to_vaddr(pml3[l_addr.pml3].addr << 12) orelse return null);
                                                    pml1 = @ptrFromInt(self.paddr_to_vaddr(pml2[l_addr.pml2].addr << 12) orelse return null);
                                                } else if (l_addr.pml2 != p_addr.pml2) {
                                                    pml1 = @ptrFromInt(self.paddr_to_vaddr(pml2[l_addr.pml2].addr << 12) orelse return null);
                                                }
                                                if (pml1[l_addr.pml1].present == 1) {
                                                    return null;
                                                }
                                                pml1[l_addr.pml1].addr = @truncate((paddr + i * pf.PAGE_SIZE) >> 12);
                                                pml1[l_addr.pml1] = @as(pf.PML1_entry, @bitCast(@as(usize, @bitCast(pml1[l_addr.pml1])) | flags | @as(usize, @bitCast(pml1[l_addr.pml1]))));
                                                // pml1[l_addr.pml1].rw = 1;
                                                // pml1[l_addr.pml1].present = 1;
                                                i += 1;
                                                p_addr = @bitCast(@as(usize, @bitCast(p_addr)) + 1 << 12);
                                            }
                                            return raddr;
                                        }
                                    } else {
                                        curfit = 0;
                                    }
                                }
                                p1e = 0;
                            }
                        }

                        p2e = 0;
                    }
                }
                p3e = 0;
            }
        }
        dbg.printf("alloc failed: checked all pmls {}\n", .{curfit});
        return null;
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
    fn alloc_entry(self: *VmmFreeList) ?*VmmFreeListEntry {
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
    fn insert_entry(self: *VmmFreeList, e: VmmFreeListEntry) ?void {
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
};
const pf = @import("pageframe.zig");
pub var home_freelist: VmmFreeList = undefined;
pub var first_table: VmmEntryTable = undefined;
pub fn setup(kphybase: usize, kphylen: usize) void {
    home_freelist.first = &first_table;
    home_freelist.first.t[0] = .{
        .next = &home_freelist.first.t[1],
        .len = pf.PAGE_SIZE,
        .t = .RESTRICTED,
        .vbase = 0,
        .pbase = 0,
        .mapped = false,
    };
    home_freelist.first.t[1] = .{
        .next = &home_freelist.first.t[2],
        .t = .U_FREE,
        .pbase = 0,
        .len = pf.TARGET_VBASE,
        .vbase = pf.PAGE_SIZE,
        .mapped = false,
    };
    home_freelist.first.t[2] = .{
        .vbase = pf.TARGET_VBASE,
        .t = .K_OCCUPIED,
        .next = null,
        .len = kphylen + pf.DEFAULT_STACK_SIZE, //4 is for the pages mapped after the kernel for kernel tables
        .pbase = kphybase,
        .mapped = true,
    };
    // home_freelist.first.t[3] = .{
    //     .vbase = pf.TARGET_VBASE + home_freelist.first.t[2].len,
    //     .t = .K_FREE,
    //     .next = null,
    //     .pbase = 0,
    //     .mapped = false,
    //     .len = 0xFFFFFFFFFFFFFFFF - home_freelist.first.t[3].vbase ,
    // };
}
