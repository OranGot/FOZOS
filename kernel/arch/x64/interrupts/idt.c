/*
I gave up trying to impliment idt in zig
*/
#include <stdint.h>
#include <stdbool.h>
#include "idt.h"
__attribute__((aligned(0x10)))
static idt_entry_t idt[256]; // Create an array of IDT entries; aligned for performance
static idtr_t idtr;
#define IDT_MAX_DESCRIPTORS 256
extern void handle_int(int_regs*);
void isr_handler(int_regs* interrupt){
    handle_int(interrupt);
}
void idt_set_descriptor(uint8_t vector, void* isr, uint8_t flags) {
    idt_entry_t* descriptor = &idt[vector];

    descriptor->isr_low        = (uint64_t)isr & 0xFFFF;
    descriptor->kernel_cs      = 0x28;
    descriptor->ist            = 0;
    descriptor->attributes     = flags;
    descriptor->isr_mid        = ((uint64_t)isr >> 16) & 0xFFFF;
    descriptor->isr_high       = ((uint64_t)isr >> 32) & 0xFFFFFFFF;
    descriptor->reserved       = 0;
}
static bool vectors[IDT_MAX_DESCRIPTORS];

extern void* isr_table [];
void idt_init() {
    idtr.base = (uintptr_t)&idt[0];
    idtr.limit = (uint16_t)sizeof(idt_entry_t) * IDT_MAX_DESCRIPTORS - 1;

    for (uint16_t vector = 0; vector < IDT_MAX_DESCRIPTORS; vector++) {
        idt_set_descriptor(vector, isr_table[vector], 0x8E);
        vectors[vector] = true;
    }

    __asm__ volatile ("lidt %0" : : "m"(idtr)); // load the new IDT
    //__asm__ volatile ("sti"); // set the interrupt flag
}
