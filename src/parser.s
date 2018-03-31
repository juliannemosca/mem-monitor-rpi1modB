/* -----------------------------------------
 * parser.s
 * -----------------------------------------*/

.include "globals.s"

.set parser_small_buf_size,	15 // (+ 1 for \n)

.section .data

.align 5
parsed_input:
	.int	0	// operation to perform:
			// 0x1 - READ
			// 0x2 - WRITE
			// 0x4 - RUN

	.int	0	// number of parameters returned

	.rept 	12	// save space for up to
	.int	0	// 12 parameters
	.endr	

parser_small_buf:
	.rept	parser_small_buf_size+1
	.byte	0
	.endr
	
.section .text

.macro parse_input_save_param_from_buffer
	
	// ------------------------
	// see if there're params
	// to save in the structure
	//

	cmp	small_buf_len, #0	// check if there's something
					// in small buf to put in the params
	beq	0f

	// add trailing null terminator 
	mov	r0, #0
	strb	r0, [small_buf, small_buf_len]

	mov	r0, small_buf
	bl	string_to_num

	str	r0, [res_params_p]
	add	res_params_p, #4	// inc. pointer 4 bytes
					// to next param
	add	param_count, #1

	// reset small buf len
	mov	small_buf_len, #0

	// have we reached the max. params num?
	cmp	param_count, #12
	beq	parse_input_end$
	//

0:
	// ------------------------

.endm

.macro parse_input_save_param_from_r0

	str	r0, [res_params_p]
	add	res_params_p, #4	// inc. pointer 4 bytes
					// to next param
	add	param_count, #1

	// have we reached the max. params num?
	cmp	param_count, #12
	beq	parse_input_end$

.endm

/*
 * @param r0:	pointer to a null-terminated string
 *		containing input to parse
 * @return r0:	pointer to a structure with the
 *		result of the parsing, or 0 if error
 */
.globl parse_input
parse_input:

	/*
	 * note: on read `.` and write `:` chars.
	 *
	 * read `.` can go anywhere in the line except
	 * at the end.
	 *
	 * write `:` can go only as a first or second
	 * parameter. if found on other place it's an err.
	 *
	 * if any of both is entered finding the other
	 * triggers an error.
	 *
	 * `R` is accepted only after an address, and
	 * any input after it is ignored.
	 *
	 * `.` is entered in the params array as -1
	 * `:` is entered in the params array as -2
	 */

	push {r4, r5, r6, r7, r8, r9, r10, r11, lr}

	res_p		.req 	r4
	res_params_p	.req	r5
	seek_p		.req	r6
	small_buf	.req	r7
	small_buf_len	.req	r8
	operation_type	.req	r9
	param_count	.req	r10
	cur_ch		.req	r11

	ldr	res_p, =parsed_input
	mov	res_params_p, res_p
	add	res_params_p, #8

	mov	seek_p, r0
	ldr	small_buf, =parser_small_buf

	mov	small_buf_len, #0
	mov	param_count, #0
	mov	operation_type, #0

1:
	// read character
	ldrb	cur_ch, [seek_p]

	// is it null? branch ahead
	cmp	cur_ch, #0
	beq	parse_input_end$

	// is it newline? branch ahead
	cmp	cur_ch, #'\n'
	beq	parse_input_end$

	// is it a `.`?
	cmp	cur_ch, #'.'
	beq	parse_input_read_range$

	// is it a `:`?
	cmp	cur_ch, #':'
	beq	parse_input_write$

	// is it an `R`?
	cmp	cur_ch, #'R'
	beq	parse_input_run$

	// is it a space? if not branch ahead to parse num
	cmp	cur_ch, #' '
	bne	parse_input_num$

	parse_input_save_param_from_buffer
	b	parse_input_next_char$

	// ------------------------

	parse_input_read_range$:

	// was already a different operation entered?
	// when so, zero-out struct pointer and b to end

	cmp	operation_type, #0
	beq	parse_range_ok$

	cmp	operation_type, #1
	beq	parse_range_ok$

	mov	res_p, #0
	b	2f

	parse_range_ok$:

	// save any param that's in the buffer first
	parse_input_save_param_from_buffer

	// set operation type to 0x1
	ldr	operation_type, =#0x1

	// set parameter to -1
	mvn     r0, #0
	parse_input_save_param_from_r0

	b	parse_input_next_char$

	// ------------------------

	parse_input_write$:

	// same as in read, validate operation
	// only that here operation type *has* to be zero
	cmp	operation_type, #0
	movne	res_p, #0
	bne	2f

	// `:` can only be the first or second param
	// otherwise error
	cmp	param_count, #2
	movhs	res_p, #0
	bhs	2f

	// save any param that's in the buffer first
	parse_input_save_param_from_buffer

	// set operation type to 0x2
	ldr	operation_type, =#0x2

	// set parameter to -2
	mvn     r0, #1
	parse_input_save_param_from_r0

	b	parse_input_next_char$

	// ------------------------

	parse_input_run$:

	// same as before, validate operation
	cmp	operation_type, #0
	movne	res_p, #0
	bne	2f

	// save any param that's in the buffer first
	parse_input_save_param_from_buffer

	// `R` can only be after the addr.
	// has been entered as the first param,
	// otherwise error
	cmp	param_count, #1
	movhi	res_p, #0
	bhi	2f

	// set operation type to 0x4
	ldr	operation_type, =#0x4

	// ignore anything after
	b	parse_input_end$

	// ------------------------
	
	parse_input_num$:
	// is it a valid hex character?
	mov	r0, cur_ch
	bl	ascii_to_num
	cmp	r0, #0
	blo	parse_input_next_char$	// continue if not valid

	// append add char to small buffer
	strb	cur_ch, [small_buf, small_buf_len]
	add	small_buf_len, #1

	// hmm... this should be better
	// handled, but will do for now
	cmp	small_buf_len, #parser_small_buf_size
	beq	parse_input_end$

	// ------------------------

	// next char
	parse_input_next_char$:

	add	seek_p, #1	// increment seek pointer

	// loop back
	b	1b

	// ------------------------
	// ------------------------
	parse_input_end$:

	// save any unsaved param
	parse_input_save_param_from_buffer

	// default operation type to READ
	cmp	operation_type, #0
	moveq	operation_type, #1

	// copy operation & param count to result struct
	str	operation_type, [res_p]
	str	param_count, [res_p, #4]

2:
	// copy pointer to result struct to r0
	mov	r0, res_p

	// cleanup aliases
	.unreq res_p
	.unreq res_params_p
	.unreq seek_p
	.unreq small_buf
	.unreq small_buf_len
	.unreq operation_type
	.unreq param_count
	.unreq cur_ch

	pop {r4, r5, r6, r7, r8, r9, r10, r11, pc}
