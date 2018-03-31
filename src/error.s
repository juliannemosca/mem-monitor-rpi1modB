
.set gpio_controller_addr,	0x20200000

.globl error_panic
error_panic:

	ldr	r0,=gpio_controller_addr

	mov 	r1,#1 		// put initial value in r1
	lsl 	r1,#18		// reach the 6th of the 3-bit sets
				// that corresponds to the led's pin
	str 	r1,[r0,#4] 	// use 4-byte offset to address pins 10-19

	// ask gpio to turn on led
	mov 	r1,#1
	lsl 	r1,#16
	str 	r1,[r0,#40]	// offset for GPCLRn - GPIO Pin Output Clear n
				// YES, we have to use `Clear`, and not `Set` :P

	// loop forever
	errLoop$:
	b errLoop$
