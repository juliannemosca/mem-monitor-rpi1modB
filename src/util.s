/* -----------------------------------------
 * Misc. utilities
 * -----------------------------------------*/

.include "globals.s"

.set str_num_buffer_size,	8

.section .data

num_ascii_lookup:
	.byte '0','1','2','3','4','5','6','7','8','9'
	.byte 'A','B','C','D','E','F'

str_num_buffer:
	.4byte 0
	.4byte 0

.section .text

/* taks a number from 0x0 to 0xF
 * in r0 and returns its corresponding
 * ascii code in r0
 */
.globl num_to_ascii
num_to_ascii:
	ldr	r1, =num_ascii_lookup
	ldrb	r0, [r1, r0]
	ret

/* taks an ascii code for a single number
 * 0-9, A-F and returns the correponding
 * numeric value
 */
.globl ascii_to_num
ascii_to_num:
	ldr	r1, =num_ascii_lookup
	mov	r2, #0
1:
	cmp	r2, #0xf
	bhi	2f

	ldrb	r3, [r1, r2]
	cmp	r0, r3
	moveq	r0, r2
	reteq

	add	r2, #1

	b	1b
2:
	mvn 	r0, #0	// return -1
	//mov	r0, #0
	ret

/* takes a pointer to a null terminated
 * string containing an hex-number (max. 4 bytes)
 * and returns the corresponding number
 */
.globl string_to_num
string_to_num:

	push {r4, r5, r6, r7, r8, lr}

	in_string	.req r4
	counter		.req r5
	val		.req r6
	buffer		.req r7
	buf_offset	.req r8

	ldr	buffer, =str_num_buffer
	mov	in_string, r0
	mov	counter, #0
1:
	ldrb	val, [in_string, counter]
	cmp	val, #0	// if we reached the end of the string
	beq	2f	// jump out of loop

	cmp	counter, #str_num_buffer_size
	//beq	error_panic
	mvneq 	r0, #0	// return -1
	beq	4f

	mov	r0, val			// prepare param
	bl	ascii_to_num		// get ascii for num
	strb	r0, [buffer, counter]	// push value into buffer

	add	counter, #1
	
	b	1b
2:
	mov	buf_offset, #0
	mov	r0, #0
3:
	cmp	buf_offset, counter
	beq	4f

	ldrb	r1, [buffer, buf_offset]
	lsl	r0, #4
	orr	r0, r1

	add	buf_offset, #1
	b	3b
4:

	.unreq in_string
	.unreq counter
	.unreq val
	.unreq buffer
	.unreq buf_offset

	pop {r4, r5, r6, r7, r8, pc}

/*
 * @param r0:	pointer to a null-terminated string
 * @return:	length of the string
 */
.globl string_len
string_len:

	mov	r2, #0		// init counter in r2

1:
	ldrb	r1, [r0]
	cmp	r1, #0
	addne	r2, #1
	addne	r0, #1
	bne	1b

	mov	r0, r2		// put the result in r0

	ret
/*
 * @param r0:	pointer to destination str. to append to
 * @param r1:	pointer to source str. from which to copy
 * @param r2:	if non-zero ommits \n char
 * @param r3:	if non-zero handle backspace
 */
.globl string_append
string_append:

	dst		.req r4
	src		.req r5
	seek_p		.req r6
	val		.req r7
	src_offset	.req r8
	inc_newline	.req r9
	end_str_p	.req r10
	handle_bsp	.req r11

	push {r4, r5, r6, r7, r8, r9, r10, r11}

	mov	dst, r0
	mov	src, r1
	mov	seek_p, dst
	mov	src_offset, #0
	mov	inc_newline, r2

	bsp_count	.req r0
	appended_len	.req r1

	mov	bsp_count, #0	// when handling bsp keep count in r0
	mov	appended_len, #0

	// find the addr from which to start copying
1:
	ldrb	val, [seek_p]
	cmp	val, #0
	addne	seek_p, #1
	bne	1b

	mov	end_str_p, seek_p
	// start copying from src into dst
2:
	ldrb	val, [src, src_offset]
	cmp	val, #0
	beq	6f

	teq	inc_newline, #0	// do not include newlines?
	beq	3f		// branch ahead

	cmp	val, #'\n'	// else check if char is \n
	beq	5f		// branch ahead if it is
3:
	teq	handle_bsp, #0	// do not handle backspace?
	beq	4f		// branch ahead then

	cmp	val, #'\b'	// check if val is \b
	bne	4f		// branch ahead if not

	cmp	seek_p, dst
	beq	5f

	sub	seek_p, #1
	add	bsp_count, #1		// inc. handled bsp count
	b	5f
4:
	strb	val, [seek_p]
	add	seek_p, #1	// increment p on destination
	add	appended_len, #1
5:
	add	src_offset, #1	// increment offset on src

	b	2b
6:

	add	end_str_p, appended_len
	sub	end_str_p, bsp_count	// also take any handled bsp from
					// end str p since it was initialized
					// to seek p, and it may need to erase
					// a previously appended char

	strb	val, [end_str_p]	// copy null terminator

	.unreq bsp_count
	.unreq appended_len

	.unreq dst
	.unreq src
	.unreq seek_p
	.unreq val
	.unreq src_offset
	.unreq inc_newline
	.unreq end_str_p
	.unreq handle_bsp

	pop {r4, r5, r6, r7, r8, r9, r10, r11}
	ret
