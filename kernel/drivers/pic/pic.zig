const pio = @import("../drvlib/drvcmn.zig");
const PIC1 = 0x20; //base io address for master PIC
const PIC2 = 0xA0; //base address for slave PIC
const PIC1_COMMAND = PIC1;
const PIC1_DATA = (PIC1 + 1);
const PIC2_COMMAND = PIC2;
const PIC2_DATA = (PIC2 + 1);
const PIC_EOI = 0x20;
pub fn send_EOI(irq: u8) void {
    if (irq >= 8) {
        pio.outb(PIC2_COMMAND, PIC_EOI);
    }
    pio.outb(PIC1_COMMAND, PIC_EOI);
}
pub fn disable() void {
    pio.outb(PIC1_DATA, 0xff);
    pio.outb(PIC2_DATA, 0xff);
}
const ICW1_ICW4 = 0x01; // Indicates that ICW4 will be present
const ICW1_SINGLE = 0x02; // Single (cascade) mode
const ICW1_INTERVAL4 = 0x04; // Call address interval 4 (8)
const ICW1_LEVEL = 0x08; // Level triggered (edge) mode
const ICW1_INIT = 0x10; // Initialization - required!

const ICW4_8086 = 0x01; // 8086/88 (MCS-80/85) mode
const ICW4_AUTO = 0x02; // Auto (normal) EOI
const ICW4_BUF_SLAVE = 0x08; // Buffered mode/slave
const ICW4_BUF_MASTER = 0x0C; // Buffered mode/master
const ICW4_SFNM = 0x10;
pub fn PIC_remap(offset1: u8, offset2: u8) void {
    const a1: u8 = pio.inb(PIC1_DATA); // save masks
    const a2: u8 = pio.inb(PIC2_DATA);
    //printf("remapping PIC a1 = %d a2 = %d\n", a1, a2);
    pio.outb(PIC1_COMMAND, ICW1_INIT |
        ICW1_ICW4); // starts the initialization sequence (in cascade mode)
    pio.io_wait();
    pio.outb(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);
    pio.io_wait();
    pio.outb(PIC1_DATA, offset1); // ICW2: Master PIC vector offset
    pio.io_wait();
    pio.outb(PIC2_DATA, offset2); // ICW2: Slave PIC vector offset
    pio.io_wait();
    pio.outb(PIC1_DATA, 4); // ICW3: tell Master PIC that there is a slave PIC at IRQ2 (0000 0100)
    pio.io_wait();
    pio.outb(PIC2_DATA, 2); // ICW3: tell Slave PIC its cascade identity (0000 0010)
    pio.io_wait();
    pio.outb(PIC1_DATA, ICW4_8086); // ICW4: have the PICs use 8086 mode (and not 8080 mode)
    pio.io_wait();
    pio.outb(PIC2_DATA, ICW4_8086);
    pio.io_wait();

    pio.outb(PIC1_DATA, a1); // restore saved masks.
    pio.io_wait();
    pio.outb(PIC2_DATA, a2);
    pio.io_wait();
}
pub fn clear_mask() void {
    pio.outb(PIC1_DATA, 0);
    pio.outb(PIC2_DATA, 0);
}
pub fn IRQ_set_mask(IRQline: u8) void {
    var port: u16 = undefined;
    var value: u8 = undefined;

    if (IRQline < 8) {
        port = PIC1_DATA;
    } else {
        port = PIC2_DATA;
        IRQline -= 8;
    }
    value = pio.inb(port) | (1 << IRQline);
    pio.outb(port, value);
}
pub fn IRQ_clear_mask(IRQline: u8) void {
    var port: u16 = undefined;
    var value: u8 = undefined;

    if (IRQline < 8) {
        port = PIC1_DATA;
    } else {
        port = PIC2_DATA;
        IRQline -= 8;
    }
    value = pio.inb(port) & ~(1 << IRQline);
    pio.outb(port, value);
}
const PIC_READ_IRR = 0x0a; // OCW3 irq ready next CMD read
const PIC_READ_ISR = 0x0b; // OCW3 irq service next CMD read
fn __pic_get_irq_reg(ocw3: u32) u16 {
    pio.outb(PIC1_COMMAND, ocw3);
    pio.outb(PIC2_COMMAND, ocw3);
    return (pio.inb(PIC2_COMMAND) << 8) | pio.inb(PIC1_COMMAND);
}
pub fn pic_get_irr() u16 {
    return __pic_get_irq_reg(PIC_READ_IRR);
}

// Returns the combined value of the cascaded PICs in-service register
pub fn pic_get_isr() u16 {
    return __pic_get_irq_reg(PIC_READ_ISR);
}
