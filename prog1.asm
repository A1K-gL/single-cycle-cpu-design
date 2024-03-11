j main

prime:
	addi t3, x0, 0x2 
	slt a1, a0, t3
	blt a0, t3, return
	find:
		rem t4, a0, t3 
		beq t4, x0, found
		addi t3, t3, 0x1
		j find
	found:
		addi a1, x0, 0x1
		beq a0, t3, return
		addi a1, x0, 0x0
	return:
		ret
main:
	addi t0, x0, 0
	lw t1, 0x00000004(x0)
	lw t2, 0x00000008(x0)
	for:
		beq t0, t1, done
		lw a0, 0x0(t2)
		jal prime
		sw a1, 0x0(t2)
		addi t2, t2, 0x4
		addi t0, t0, 0x1
		j for
	done:
	j done