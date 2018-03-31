.include "globals.s"

.section .init
.globl _start
_start:
	b 	main

.section .text

main:
	mov	sp, #0x8000
	bl	video_init_frame_buffer
	
	/*
	 * TO-DO:
	 * 	don't be so optimistic here
	 *	and call some panic func
	 *	to turn a led on or something
	 *	if things go wrong.

	cmp	r0, #0
	beq	error_panic
	*/
	bl	video_set_addr

	ldr	r0, =palette_high_color_green
	bl	video_set_color

	bl	term_init

	/* done with init, output some debug info */

	// DEBUG:
	//
	// uncomment the following to print the addr
	// of the test run program at start
	//
	//ldr	r0, =test_run_program
	//bl	proc_print_addr
	//bl	term_print_newline


	readline_loop$:

	bl 	term_readline
	bl	proc_input
	b	readline_loop$

/* ---------------------------------------
 * test program for run (R) command:
 * ---------------------------------------*/
.globl dbg_test_run_program
test_run_program:

	ldr	r0, =test_run_program_string
	bl	term_print
	bl	term_print_newline

	ldr	pc, =proc_op_run_back

/* ---------------------------------------
 * more data:
 * ---------------------------------------*/
.section .data

.align 2

test_run_program_string:
.asciz "this is a test run program!"

dbg_string:
.asciz "dbg: "
