.global flush_cr3
flush_cr3:
	movq %rdi, %cr3
	retq
