.global flush_cr3
flush_cr3:
	movq %rdi, %cr3
	retq
.global get_cr3
get_cr3:
	movq %cr3, %rax
	retq
