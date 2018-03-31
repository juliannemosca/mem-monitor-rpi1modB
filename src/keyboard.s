/* ---------------------------------------
 * keyboard library access
 * ---------------------------------------*/

/* NOTE: even though the library supports
 *       multiple keyboards, this program
 *       supports only one for simplicity
 */
	
.include "globals.s"

.set keyboard_max_keys_down,	6

.section .data

.align 2
keyboard_addr:
	.int 0

.align 2
keyboard_keys_down:
	.rept 	keyboard_max_keys_down
	.hword	0
	.endr

//.align 1
//keyboard_keys_pressed_flags:
//	.byte	0
	
.section .text

/* ---------------------------------------
 * initialize the USB keyboard
 * ---------------------------------------
 *
 */
.globl keyboard_init
keyboard_init:

	push {lr}

	// initialize keyboard
	bl	UsbInitialise
	cmp	r0, #0
	blo	error_panic

	//bl 	UsbCheckForChange
	bl	KeyboardCount
	cmp	r0, #0
	beq	error_panic

	mov	r0, #0
	bl	KeyboardGetAddress

	cmp	r0, #0
	bls	error_panic

	// store the recently obtained keyboard address
	ldr	r1, =keyboard_addr
	str	r0, [r1]

	pop {pc}

/* ---------------------------------------
 * return the addr for the keys down array
 * ---------------------------------------
 *
 */
.globl keyboard_get_keys_down_addr
keyboard_get_keys_down_addr:
	ldr	r0, =keyboard_keys_down
	ret
/* ---------------------------------------
 * read up to 6 keys of input from the
 * keyboard. count of keys read is
 * returned and scan codes for the keys
 * are stored at keyboard_keys_down
 *
 * @param r0:	bit-flags for keys already
 *		read since last call
 * @return r0:	updated flags according
 *		to the newly read keys
 *
 * ---------------------------------------
 *
 */
.globl keyboard_get_input
keyboard_get_input:

	push {r4, r5, r6, r7, r8, r9, lr}

	kb_addr		.req r4
	offset		.req r5
	counter		.req r6
	keys_down_addr	.req r7
	keys_flags	.req r8
	flags_mask	.req r9

	//
	
	ldr	kb_addr, =keyboard_addr
	ldr	kb_addr, [kb_addr]

	//ldr	keys_flags_p, =keyboard_keys_pressed_flags
	//ldrb	keys_flags, [keys_flags_p]
	mov	keys_flags, r0
	
	// TO-DO: maybe check that the keyboard was init before?

	mov	r0, kb_addr
	
	// poll keyboard
	bl	KeyboardPoll
	cmp	r0, #0
	blo	error_panic

	mov	counter, #0			// init a counter
	ldr	flags_mask, =0b00000001

	// addr to store the keys down
	ldr	keys_down_addr, =keyboard_keys_down

	str	counter, [keys_down_addr] 	// zero-out prev values
	strh	counter, [keys_down_addr, #4]

1:	// (read all keys down)
	cmp 	counter, #keyboard_max_keys_down
	beq	2f

	// prepare params in r0 and r1
	mov	r0, kb_addr
	mov	r1, counter

	// call to get key down
	bl	KeyboardGetKeyDown

	// Check if a keypress is new
	// and save the scan code
	//
	// Compare the scan code with the previous
	// one, if it's different then it's a new key
	// so save the new one instead and set the
	// corresponding flag
	
	mov	offset, counter	// calc. offset in r5
	lsl	offset, #1

	ldrh	r1, [keys_down_addr, offset]
	cmp	r0, r1
	beq	kbd_get_input_next$	// same one, move on to next

	// save the key's scan code
	strh	r0, [keys_down_addr, offset]

	// set the flag for this key 
	//
	// if scan code's zero clear the flag,
	// else set it
	cmp	r0, #0
	biceq	keys_flags, keys_flags, flags_mask
	orrne	keys_flags, flags_mask

	//
	kbd_get_input_next$:
	// add to counter
	add	counter, #1
	lsl	flags_mask, #1
	// loop back
	b	1b

2:

	mov r0, keys_flags

	.unreq kb_addr
	.unreq offset
	.unreq counter
	.unreq keys_down_addr
	.unreq keys_flags
	.unreq flags_mask

	pop {r4, r5, r6, r7, r8, r9, pc}

/* ---------------------------------------
 * DEBUG
 * ---------------------------------------
 *
 */

/*
.globl debug_keyboard_get_input
debug_keyboard_get_input:

	push {r4, r5, r6, r7, lr}

	ldr	r5, =keyboard_addr
	ldr	r5, [r5]

1:
	ldr	r7, =0xffff
2:
	sub	r7, #1
	cmp	r7, #0
	bne	2b
	
	mov	r0, r5
	
	// poll keyboard
	bl	KeyboardPoll
	cmp	r0, #0
	blo	error_panic

	mov	r6, #0			// init a counter

3:	// (read all keys down)
	cmp 	r6, #keyboard_max_keys_down
	beq	1b

	// prepare params in r0 and r1
	mov	r0, r5
	//mov	r1, r6
	ldr	r1, =#58

	// call to get key down
	bl	KeyboadGetKeyIsDown

	//cmp	r0, #58
	//beq	error_panic
	cmp	r0, #0
	bhi	error_panic

	// add to counter
	add	r6, #1

	// loop back
	b	3b





	pop {r4, r5, r6, r7, pc}
*/
