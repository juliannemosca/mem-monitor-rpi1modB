/* -----------------------------------------
 * Memory Monitor functionality
 * -----------------------------------------*/

.include "globals.s"

.section .data

mem_peek_buf:
	.4byte 0

.section .text

/* takes a memory addr. and returns a pointer
 * to a null terminated string with its contents.
 *
 * this will read 1 byte starting
 * from the indicated address
 *
 * @param r0:	a memory address to peek
 * @return r0:	a pointer to a null terminated string
 *		with the address' content
 */
.globl mem_peek
mem_peek:

	push {r4, r5, r6, lr}

	ldr	r4, =mem_peek_buf

	// zero-out buffer
	mov	r2, #0
	strh	r2, [r4]

	// read one byte from the specified address
	ldrb	r5, [r0]

	// store the upper half of the byte in r4
	// and keep the lower half in r3
	mov	r6, r5

	and	r6, #0b11110000
	and	r5, #0b00001111

	// now shift the upper half to the right 4 places
	lsr	r6, #4

	// translate each number to ascii
	//
	//
	mov	r0, r6
	bl	num_to_ascii
	// store the fist half of the string
	strb	r0, [r4]

	mov	r0, r5
	bl	num_to_ascii
	// store the second half of the string
	strb	r0, [r4, #1]

	// put pointer to the result string in r0
	mov	r0, r4

	pop {r4, r5, r6, pc}
