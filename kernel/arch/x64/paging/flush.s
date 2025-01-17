.global flush_cr3
flush_cr3:
	movq %rdi, %cr3
	subq %rbp, %rsp
	movq %rbp, %rax
	movq %rsi, %rbp
	subq %rsi, %rax
	movq %rsi, %rsp
	retq
.global get_cr3
get_cr3:
	movq %cr3, %rax
	retq
