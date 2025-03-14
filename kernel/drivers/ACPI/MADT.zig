const tpars = @import("tpars.zig");
const MADTEntry = extern struct {
    entry_t: u8,
    record_len: u8,
    spec: union {
        proc_lapic: extern struct {
            acpi_proc_id: u8,
            apic_id: u8,
            flags: u32,
        },
        io_apic: extern struct {
            io_apic_id: u8,
            r: u8,
            io_apic_addr: u32,
            global_sys_interrupt_base: u32,
        },
        io_apic_int_src_override: extern struct {
            bus_src: u8,
            irq_src: u8,
            global_sys_interrupt: u32,
            flags: u16,
        },
        io_apic_non_maskable_int_src: extern struct {
            nmi_src: u8,
            r: u8,
            flags: u16,
            global_sys_int: u32,
        },
        lapic_non_maskable_interrupts: extern struct {
            acpi_proc_id: u8,
            flags: u16,
            lint: u8,
        },
        lapic_address_override: extern struct {
            r: u16,
            lapic_phy: u64,
        },
        proc_x2lapic: extern struct {
            r: u16,
            x2lapic_id: u32,
            flags: u32,
            acpi_id: u32,
        },
    },
};
pub const MADT = extern struct {
    cmn: tpars.CommonACPISDTHeader,
    lapic_addr: u32,
    flags: u32,
    entries: []MADTEntry,
    pub fn init() ?void {
        const phy = tpars.GL_RSDT.seek("APIC") orelse return null;
    }
};
