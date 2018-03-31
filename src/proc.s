/* -----------------------------------------
 * process input and supported operations
 * -----------------------------------------*/

.section .data

proc_last_opened_addr:
	.int	0x8000

proc_print_addr_buffer:
	.int	0

proc_line_buffer:
	.rept	80+1
	.byte	0
	.endr

msg_syntax_err:
	.asciz "invalid input, syntax error"

.section .text

.macro proc_input_validate_param
	cmp	param, #0
	blo	proc_parse_error$
.endm

/*
 * @param r0:	pointer to a null-terminated string
 *		containing input to process
 */
.globl proc_input
proc_input:

	push {r4, r5, r6, r7, r8, r9, r10, r11, lr}

	parse_result		.req	r4
	param			.req	r5
	param_next		.req	r6
	params_p		.req	r7
	count			.req	r8
	total_read		.req	r9
	max_params		.req	r10
	last_opened_addr	.req	r11

	ldr	total_read, =#0
	ldr	last_opened_addr, =proc_last_opened_addr

	// parse the input
	bl	parse_input
	cmp	r0, #0
	beq	proc_parse_error$

	mov	parse_result, r0
	mov	params_p, r0
	add	params_p, #8

	// load the operation code from the result
	ldr	r1, [parse_result]
	ldr	max_params, [parse_result, #4]

	// debug
	cmp	max_params, #12
	bhi	error_panic
	cmp	max_params, #0
	blo	error_panic
	// debug

	// check the operation code and branch accordingly
	//
	cmp	r1, #1 // TODO: use consts
	beq	proc_op_read$

	cmp	r1, #2
	beq	proc_op_write$

	cmp	r1, #4
	beq	proc_op_run$

	b 	proc_not_supported$

	// ------------------------
	// READ
	// ------------------------
	proc_op_read$:

	cmp	max_params, #0
	beq	proc_parse_error$

	proc_op_read_begin$:

	mov	count, #0

	ldr	param, [params_p]
	proc_input_validate_param
	mov	param_next, param

	// is the param we're reading a `.`?
	mvn     r0, #0
	cmp	r0, param
	ldreq	param, [last_opened_addr]	// load last addr. as param
	beq	proc_op_read_range$		// b to read range

	proc_input_validate_param

	add	count, #1		// increment count

	// check if we already read all params
	mov	r0, #0
	add	r0, count, total_read

	cmp	r0, max_params
	beq	proc_op_read_1$

	// peek next param and see if it's a `.`
	//
	mov	r1, count
	lsl	r1, #2

	ldr	r2, [params_p, r1] 	// check if next param is -1 (`.`)
	mvn     r0, #0
	cmp	r0, r2
	bne	proc_op_read_1$		// if it is b to read range

	proc_op_read_range$:

	// after `.` if there's no other param
	// b to syntax error
	add	count, #1		// increment count

	mov	r0, #0
	add	r0, count, total_read

	cmp	r0, max_params
	beq	proc_parse_error$

	// read next param
	mov	r1, count
	lsl	r1, #2

	ldr	param_next, [params_p, r1]

	add	count, #1

	proc_op_read_1$:

	// print the requested range
	//
	mov	r0, param		// from
	mov	r1, param_next		// to
	bl	proc_print_mem_from_to

	// inc. counters, offsets, etc...
	//
	str	param, [last_opened_addr]

	mov	r0, count
	lsl	r0, #2

	add	params_p, r0
	add	total_read, count

	cmp	total_read, max_params
	beq	proc_input_end$

	b	proc_op_read_begin$

	// ------------------------
	// WRITE
	// ------------------------
	proc_op_write$:

	// there has to be at least something to write
	// and the write symbol
	cmp	max_params, #2
	blo	proc_parse_error$

	// get first parameter
	ldr	param, [params_p]
	proc_input_validate_param
	add	total_read, #1

	w_from	.req param
	w_val	.req param_next

	// check if the starting address is specified
	// of if we have to use the implicit starting addr.
	mvn     r0, #1
	cmp	r0, param
	ldreq	param, [last_opened_addr]	// load last addr. as param
	addne	total_read, #1			// if this param wasn't a `:`
						// but an addr. instead we know
						// we can skip the next (which is
						// guaranteed to be the write symbol)

	proc_op_write_1$:

	// read the next value to write
	// read next param
	mov	r0, total_read
	lsl	r0, #2
	ldr	w_val, [params_p, r0]
	add	total_read, #1

	// write the value to the addr.
	strb	w_val, [w_from]

	// are we done?
	cmp	total_read, max_params
	beq	proc_input_end$

	// write next addr
	add	w_from, #1

	// loop back
	b	proc_op_write_1$

	// cleanup aliases
	.unreq w_from
	.unreq w_val

	// ------------------------
	// RUN
	// ------------------------
	proc_op_run$:

	// we expect exactly 1 parameter
	// here which is the addr. to jump to
	cmp	max_params, #1
	bne	proc_parse_error$

	// get parameter
	ldr	param, [params_p]
	proc_input_validate_param

	// set the program counter
	// to the addr. specified
	// in the parameter
	//
	mov	pc, param

	.globl proc_op_run_back
	proc_op_run_back:

	b	proc_input_end$

	// ------------------------
	// NOT SUPPORTED
	// ------------------------
	proc_not_supported$:
	// ------------------------
	// PARSE ERR.
	// ------------------------
	proc_parse_error$:

	ldr	r0, =msg_syntax_err
	bl	term_print
	bl	term_print_newline

	// ------------------------
	proc_input_end$:

	.unreq parse_result
	.unreq param
	.unreq param_next
	.unreq params_p
	.unreq count
	.unreq total_read
	.unreq max_params
	.unreq last_opened_addr

	pop {r4, r5, r6, r7, r8, r9, r10, r11, pc}


/*
 * @param r0:	addr to print from
 * @param r1:	addr to print to
 *
 */
.globl proc_print_mem_from_to // DEBUG, remove .globl
proc_print_mem_from_to:
	push {r4, r5, r6, r7, r8, lr}

	val	.req	r4
	buffer	.req	r5
	from	.req	r6
	to	.req	r7
	cols	.req	r8

	mov	from, r0
	mov	to, r1

	mov	cols, #0

	ldr	buffer, =proc_line_buffer

	// from > to ? only print from
	cmp	from, to
	movhi	to, from

1:

	// starting a line? print address
	cmp	cols, #0
	moveq	r0, from
	bleq	proc_print_addr

	// print space
	ldr	r0, =#' '
	strb	r0, [buffer]

	mov	r0, #0
	strb	r0, [buffer, #1]

	mov	r0, buffer
	bl	term_print

	// load value
	//ldrb	val, [from]

	mov	r0, from //val
	bl	mem_peek
	bl	term_print

	add	cols, #1

	cmp	cols, #16
	bleq	term_print_newline
	moveq	cols, #0

	add	from, #1

	cmp	from, to
	bls	1b

2:
	cmp	cols, #0
	blne	term_print_newline // print a newline if we haven't before

	.unreq val
	.unreq buffer
	.unreq from
	.unreq to
	.unreq cols

	pop {r4, r5, r6, r7, r8, pc}

.globl proc_print_addr
proc_print_addr:
	push {r4, r5, lr}

	// NOTE: using mem_peek here to print
	//       is not so-good design, ideally
	//       a function should be in util
	//       to print formatted input, but
	//       it's not there yet
	//
	//       ¯\_(ツ)_/¯
	//

	ldr	r5, =proc_line_buffer
	ldr	r4, =proc_print_addr_buffer
	str	r0, [r4]
	mov	r0, r4

	add	r0, #3
	bl	mem_peek
	bl	term_print

	mov	r0, r4
	add	r0, #2
	bl	mem_peek
	bl	term_print

	mov	r0, r4
	add	r0, #1
	bl	mem_peek
	bl	term_print

	mov	r0, r4
	bl	mem_peek
	bl	term_print

	ldr	r0, =#':'
	strb	r0, [r5]

	mov	r0, #0
	strb	r0, [r5, #1]

	mov	r0, r5
	bl	term_print

	pop {r4, r5, pc}
