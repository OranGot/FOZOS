const PCI_VENDOR_ID = 0x00;
const PCI_DEVICE_ID = 0x02;
const PCI_COMMAND = 0x04;
const PCI_STATUS = 0x06;
const PCI_REVISION_ID = 0x08;
const PCI_PROG_IF = 0x09;
const PCI_SUBCLASS = 0x0a;
const PCI_CLASS = 0x0b;
const PCI_CACHE_LINE_SIZE = 0x0c;
const PCI_LATENCY_TIMER = 0x0d;
const PCI_HEADER_TYPE = 0x0e;
const PCI_BIST = 0x0f;
const PCI_BAR0 = 0x10;
const PCI_BAR1 = 0x14;
const PCI_BAR2 = 0x18;
const PCI_BAR3 = 0x1C;
const PCI_BAR4 = 0x20;
const PCI_BAR5 = 0x24;
const PCI_SECONDARY_BUS = 0x09;
const PCI_SYSTEM_VENDOR_ID = 0x2C;
const PCI_SYSTEM_ID = 0x2E;
const PCI_EXP_ROM_BASE_ADDR = 0x30;
const PCI_CAPABILITIES_PTR = 0x34;
const PCI_INTERRUPT_LINE = 0x3C;
const PCI_INTERRUPT_PIN = 0x3D;
const PCI_MIN_GRANT = 0x3E;
const PCI_CARDBUS_CIS_POINTER = 0x28;
const PCI_MAX_LATENCY = 0x3F;
pub const config_address = packed struct(u32) {
    reg_offset: u8,
    func_num: u3 = 0,
    dev_num: u5,
    bus_num: u8,
    reserved: u7 = 0,
    enable: u1 = 1,
};
const pio = @import("drvlib/drvcmn.zig");
pub fn config_read_word(bus: u8, dev: u8, func: u8, offset: u8) u16 {
    const config: config_address = .{
        .bus_num = @truncate(bus),
        .dev_num = @truncate(dev),
        .func_num = @truncate(func),
        .reg_offset = offset,
    };
    pio.outl(0xCF8, @bitCast(config));
    return @truncate((pio.inl(0xCFC) >> @truncate((offset & 2) * 8)) & 0xFFFF);
}
const tty = @import("tty/tty.zig");
pub fn init_devices() void {
    for (0..255) |bus| {
        for (0..32) |dev| {
            const vendor_id = config_read_word(@truncate(bus), @truncate(dev), 0, PCI_VENDOR_ID);
            if (vendor_id == 0xFFFF) continue;
            switch (config_read_word(@truncate(bus), @truncate(dev), 0, PCI_CLASS)) {
                0x1 => {
                    switch (config_read_word(@truncate(bus), @truncate(dev), 0, PCI_SUBCLASS)) {
                        0x7 => {
                            tty.printf("found an NVMe controller", .{});
                        },
                        else => tty.printf("unknown subclass of mass storage pci device {},{}: 0x{x}", .{ bus, dev, config_read_word(@truncate(bus), @truncate(dev), 0, PCI_SUBCLASS) }),
                    }
                },
                else => tty.printf("unknown class on pci device: {},{}:0x{x}\n", .{ bus, dev, config_read_word(@truncate(bus), @truncate(dev), 0, PCI_CLASS) }),
            }
        }
    }
}
