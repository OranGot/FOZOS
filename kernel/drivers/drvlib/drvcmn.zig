pub inline fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}
pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}
pub inline fn outl(port: u16, val: u32) void {
    asm volatile ("outl %[val], %[port]"
        :
        : [val] "{eax}" (val),
          [port] "N{dx}" (port),
    );
}

pub inline fn inl(port: u16) u32 {
    return asm ("inl %[port], %[result]"
        : [result] "={eax}" (-> u32),
        : [port] "{dx}" (port),
    );
}
pub inline fn invlpg(v_addr: usize) void {
    asm volatile ("invlpg (%[v_addr])"
        :
        : [v_addr] "r" (v_addr),
        : "memory"
    );
}
pub fn io_wait() void {
    outb(0x80, 0);
}
