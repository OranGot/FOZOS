    .section .rodata
msg:    .asciz "Hello from the userspace!\n"  # Null-terminated string

    .section .text
    .global _start

_start:
    movq $1, %rax      
    movq $1, %rdi      
    leaq msg(%rip), %rsi  
    movq $26, %rdx     
    syscall            # invoke syscall
    
    # exit 
    movq $60, %rax     
    movq $0, %rdi    
    syscall            # invoke syscall
