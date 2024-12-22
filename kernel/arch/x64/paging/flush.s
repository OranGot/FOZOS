.global flush_cr3
flush_cr3:
	cli
	movq %rdi, %cr3
	sti	
	retq
