.global sys_handle_generic
.extern handle_syscall
sys_handle_generic: 
    cli
    swapgs
    movq %rsp, %gs:16 #saving user stack
    movq %rbp, %gs:24
    movq %gs:0, %rbp #setting up kernel stack 
    movq %gs:8, %rsp
    swapgs
    pushq %rax
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rsi
    pushq %rdi
    #pushq %rbp
    pushq %r8
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
	movq %rsp, %rdi
	call handle_syscall
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %r8
    #popq %rbp
    popq %rdi
    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    popq %rax 
    swapgs
    movq %rbp, %gs:0 #saving kernel stack 
    movq %rsp, %gs:8
    movq %gs:16, %rsp  #restoring user stack
    movq  %gs:24,  %rbp
    swapgs 
    sti
    sysretq
