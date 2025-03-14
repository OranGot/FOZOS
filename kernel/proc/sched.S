.global soft_switch
soft_switch:
    swapgs
    movq %rbp, %gs:0 # saving kernel stack
    movq %rsp, %gs:8
    #no need to save user stack too
    movq (%rdi), %rax
    movq %rax, %cr3
    movq 8(%rdi), %r15
    movq 16(%rdi), %r14
    movq 24(%rdi), %r13
    movq 32(%rdi ), %r12
    movq 40(%rdi ), %r11
    movq 48(%rdi ), %r10
    movq 56(%rdi ), %r9
    movq 64(%rdi ), %r8
    # movq 136(%rdi), %rsp
    #movq 80(%rdi ), %rdi
    movq 88(%rdi ), %rsi
    movq 96(%rdi ), %rdx
    movq 104(%rdi ), %rcx
    movq 112(%rdi ), %rbx
    movq 120(%rdi), %rbx
    pushq $0x23
    pushq 144(%rdi) # rsp
    pushq 136(%rdi) # rflags
    pushq $0x1B     # user mode code segment
    pushq 128(%rdi) # pushing the instruction ptr 
    swapgs
    movq 72(%rdi ), %rbp
    iretq
.global kernel_soft_switch
kernel_soft_switch:
    swapgs
    movq %rbp, %gs:0 # saving kernel stack
    movq %rsp, %gs:8
    #no need to save user stack too
    movq (%rdi), %rax
    movq %rax, %cr3
    movq 8(%rdi), %r15
    movq 16(%rdi), %r14
    movq 24(%rdi), %r13
    movq 32(%rdi ), %r12
    movq 40(%rdi ), %r11
    movq 48(%rdi ), %r10
    movq 56(%rdi ), %r9
    movq 64(%rdi ), %r8
    # movq 136(%rdi), %rsp
    #movq 80(%rdi ), %rdi
    movq 88(%rdi ), %rsi
    movq 96(%rdi ), %rdx
    movq 104(%rdi ), %rcx
    movq 112(%rdi ), %rbx
    movq 120(%rdi), %rbx
    pushq $0x10
    pushq 144(%rdi) # rsp
    pushq 136(%rdi) # rflags
    pushq $0x8 # kernel mode code segment
    pushq 128(%rdi) # pushing the instruction ptr 
    # pushq $0
    swapgs
    movq 72(%rdi ), %rbp
    iretq
