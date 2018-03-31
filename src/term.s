/* ---------------------------------------
 * Terminal IO functionality
 * ---------------------------------------*/

.include "globals.s"
	
.set term_char_width,		8
.set term_char_height,		8
.set term_cols,			80 	// 640/char_width

.set term_output_buffer_size,	4800	// term_cols * (480/char_height)
.set term_last_line_begins_at,	4720 	// buffer_size - term_cols

.set term_input_echo_buf_len,	8	// (_at least_
					// keyboard_max_keys_down + 1 always null)
					// TO-DO: define better symbols :P

.set term_input_line_buf_len,	2400	// use half of the screen sized buffer

.section .data

.align 4
	
term_font:
	.incbin "ext/2513r.bin"

/* ---------------------------------------
 * terminal output buffer data:
 * ---------------------------------------*/
term_output_buffer_cursor:
	.int	0

term_output_buffer:
	.rept 	term_output_buffer_size
	.byte	0
	.endr

term_output_buffer_start:
	.int	0

term_output_buffer_end:
	.int	0

// holds the current length of
// the contents in the output buffer:
term_output_buffer_len:
	.int	0

// points to the addr in the output buffer
// from which to write on the next char.
term_output_buffer_write_from:
	.int	0

// points to the addr in the output buffer
// that corresponds to the first character
// in the screen:
term_output_buffer_screen_start:
	.int	0

.section .text

/* ---------------------------------------
 * output a character to the screen
 * ---------------------------------------
 *
 * @param r0	x
 * @param r1    y
 * @param r2    char num. (0-127)
 */
.globl term_output_char
term_output_char:

	push {r4, r5, r6, r7, r8, lr}

	mov	r8, #0		/* zero-out r8 for later */

	cmp	r2, #127
	bhi	out_char_end$	/* invalid param, b to end */
	blo	1f

	/* for the DEL char. code we save the current
	 * video color in r8 to restore later and set
	 * video color to background color.
	 *
	 * NOTE: background color is hard-coded to black by now */

	ldr	r8, =video_color
	ldrh	r8, [r8]

	push	{r0, r1}
	ldr	r0, =palette_high_color_black
	bl	video_set_color
	pop	{r0, r1}

1:

	/* find the char addr in the font */
	//lsl	r2, #4		// multiply char num. by 16
				// (for 16 height fonts only)

	lsl	r2, #3		/* multiply char num. by 8 */
	ldr	r7, =term_font
	add	r2, r7 		/* add the font's starting addr */

	/* use r3 and r4 for the y-x loop counters*/
	mov	r3, #0
	mov	r4, #0

	/* rows loop */
	out_char_row$:

	cmp	r3, #term_char_height	/* if done with last row b to end */
	beq	out_char_end$

	/* get the row's byte in r6 */
	ldrb	r6, [r2]

	ldr	r5, =#1			/* use r5 to test each column */

	/* draw columns loop */
	out_char_col$:
	cmp	r4, #term_char_width
	moveq	r4, #0			/* x back to first col. */
	addeq	r3, #1			/* y to next row */
	addeq	r2, #1			/* increment font char addr
					 * to next byte */
	beq	out_char_row$		/* move on to next row */

	/* test each column and plot if necessary */
	tst	r6, r5
	beq	out_char_finish_col$	/* bit is 0, skip the plotting */

	push	{r0, r1, r2, r3}	/* save r0-r3 registers */

	/* prepare parameters to call plot */
	add	r0, r4
	add	r1, r3

	/* plot the point */
	bl	video_plot_pixel
	
	pop	{r0, r1, r2, r3}	/* restore r0-r3  registers */

	out_char_finish_col$:

	lsl	r5, #1			/* rotate left for next col. */
	add	r4, #1			/* add to loop's x */
	b	out_char_col$		/* move on to next column */

	/* output end */
	out_char_end$:

	/* restore video color if necessary */
	cmp	r8, #0
	movne	r0, r8
	blne	video_set_color

	pop {r4, r5, r6, r7, r8, pc}

/* ---------------------------------------
 * initialize the terminal buffers
 * ---------------------------------------
 *
 */
.globl term_init
term_init:

	push	{r4, r5, lr}

	ldr	r0, =term_output_buffer
	ldr	r1, =term_output_buffer_start
	ldr	r2, =term_output_buffer_end
	ldr	r3, =term_output_buffer_cursor
	ldr	r4, =term_output_buffer_screen_start
	ldr	r5, =term_output_buffer_write_from

	str	r0, [r1]
	str	r0, [r3]
	str	r0, [r4]
	str	r0, [r5]

	add	r0, #term_output_buffer_size
	str	r0, [r2]

	bl	keyboard_init

	pop	{r4, r5, pc}

/* ---------------------------------------
 * write a character to the output buffer
 * ---------------------------------------
 *
 * @param r0	an ASCII character code to
 *		write to the buffer
 * @return r0	non-zero if the screen
 *              has to be redrawn
 */
.globl term_write_output_buffer
term_write_output_buffer:

	ascii_code	.req r0
	cursor_p	.req r1
	cursor		.req r2
	buffer_start	.req r3
	buffer_end	.req r4
	x_aux		.req r5
	to_write	.req r6
	written		.req r7
	screen_start	.req r8
	screen_start_p	.req r9
	needs_redraw	.req r10

	push {r4, r5, r6, r7, r8, r9, r10, lr}

	mov	needs_redraw, #0

	ldr	cursor_p, =term_output_buffer_cursor	// get pointer addr
	ldr	cursor, [cursor_p]			// get value from pointer

	// load the buffer start and end addrs
	ldr	buffer_start, =term_output_buffer_start
	ldr	buffer_start, [buffer_start]
	ldr	buffer_end, =term_output_buffer_end
	ldr	buffer_end, [buffer_end]

	ldr	screen_start_p, =term_output_buffer_screen_start

	// init written chars
	mov	written, #0

	// is it a backspace?
	teq	ascii_code, #'\b'
	bne	0f

	// is cursor at the beginning of buffer?
	cmp	cursor, buffer_start
	beq	5f	// then we don't let it go back anymore,
			// branch to the end

	//ldrb	ascii_code, =#127 // prepare a DEL char.
	//strb	ascii_code, [cursor]
	push 	{r0, r1, r2, r3}
	bl	term_erase_prompt
	pop 	{r0, r1, r2, r3}

	// cursor -= 1
	sub	cursor, #1

	// save cursor value back
	str	cursor, [cursor_p]

	//push 	{r0, r1, r2, r3}
	//bl	term_display_prompt
	//pop 	{r0, r1, r2, r3}

	// decrement write-from value
	// as flush function expects it to
	// be aligned with cursor
	ldr	r1, =term_output_buffer_write_from
	ldr	r2, [r1]
	sub	r2, #1
	str	r2, [r1]

	// ask to redraw screen
	//
	//ldr	needs_redraw, =#1

	b	5f	// branch to end

0:
	// is it a newline?
	teq	ascii_code, #'\n'
	movne	to_write, #1	// keep chars to write count
	bne	3f		// not a newline, jump forward

	// for a newline char. fill the rest of the line
	// with the DEL char.
	mov	ascii_code, #127

	// calculate how many chars until the end of line
	// the algorithm's something as follows:
	//
	// x = cursor - buffer start
	// while x > cols
	//   x = x - cols
	//
	// n = cols - x
	// n = (n == 0 ? cols : n)

	mov	x_aux, cursor
	sub	x_aux, buffer_start
	ldr	to_write, =#term_cols
1:
	cmp	x_aux, to_write
	bls	2f
	sub	x_aux, to_write
	b	1b
2:
	sub	to_write, x_aux
	teq	to_write, #0
	ldreq	to_write, =#term_cols
	// now we have num of chars to write in r6
3:

	//
	// (put a regular char in the buffer)
	//
	strb	ascii_code, [cursor]		// store char in buffer
	add	cursor, #1			// increment addr value

	// has the cursor reached the end? then wrap
	cmp	cursor, buffer_end
	moveq	cursor, buffer_start

	// has the cursor reached the screen start point?
	// if not jump ahead, else update
	ldr	screen_start, [screen_start_p]

	cmp	cursor, screen_start
	bne	4f

	// --- update screen start
	//
	add	screen_start, #term_cols	// move screen start pointer
						// n cols positions ahead
	cmp	screen_start, buffer_end
	movhs	screen_start, buffer_start

	str	screen_start, [screen_start_p]
	add	needs_redraw, #1
	//
	// ---
4:
	add	written, #1
	cmp	written, to_write	// compare chars written with chars to write
	bne	3b

	// save cursor back again
	str	cursor, [cursor_p]

	// increment chars written in buffer count
	.unreq cursor_p
	.unreq cursor
	len_p	.req r1
	len	.req r2

	ldr	len_p, =term_output_buffer_len
	ldr	len, [len_p]
	add	len, written
	str	len, [len_p]
5:
	mov	r0, needs_redraw

	.unreq ascii_code
	.unreq len_p
	.unreq len
	.unreq buffer_start
	.unreq buffer_end
	.unreq x_aux
	.unreq to_write
	.unreq written
	.unreq screen_start
	.unreq screen_start_p
	.unreq needs_redraw

	pop	{r4, r5, r6, r7, r8, r9, r10, pc}
	ret

/* ---------------------------------------
 * misc. utility functions:
 * ---------------------------------------
 *
 */
term_rel_pos_from_output_buf:
	push {r4, r5}

	addr_to_find	.req r0
	buffer_start	.req r1
	buffer_end	.req r2
	screen_start	.req r3
	seek_p		.req r4
	rel_pos		.req r5

	ldr	buffer_start, =term_output_buffer_start
	ldr	buffer_start, [buffer_start]

	ldr	buffer_end, =term_output_buffer_end
	ldr	buffer_end, [buffer_end]

	ldr	screen_start, =term_output_buffer_screen_start
	ldr	screen_start, [screen_start]

	ldr	rel_pos, =#1

	// init seek pointer at screen start
	mov	seek_p, screen_start
1:
	cmp	seek_p, addr_to_find
	beq	2f

	add	rel_pos, #1
	add	seek_p, #1

	cmp	seek_p, buffer_end
	moveq	seek_p, buffer_start

	cmp	rel_pos, #term_output_buffer_size
					// if it's higher than buffer size
	bhi	error_panic		// then it is an error

	b	1b
2:
	mov	r0, rel_pos

	.unreq addr_to_find
	.unreq buffer_start
	.unreq buffer_end
	.unreq screen_start
	.unreq seek_p
	.unreq rel_pos

	pop {r4, r5}
	ret

.globl term_rel_pos_to_x_y
term_rel_pos_to_x_y:

	// @param r0:	relative position of char
	//
	// @return r0:	x coord for char in the screen
	// @return r1:	y coord for char in the screen

	//push {r4, r5}

	mov	r2, r0		// put pos n in r2
	mov	r0, #0		// set x
	mov	r1, #0		// set y
	ldr	r3, =term_cols

1:
	cmp	r2, r3
	bls	2f

	sub	r2, r3
	add	r1, #1
	b	1b

2:
	// n has to be adjusted here
	// to n -= 1
	sub	r2, #1

	// x = n * char width

	lsl	r2, #3  // @NOTE: only use this with widths
			// that we can shift, otherwise we
			// have to use the slower `mul`
			// instruction below

	//ldr	r4, =#term_char_width
	//mov	r5, r2
	//mul	r2, r5, r4

	mov	r0, r2		// put pos n in r0

	// y = y * char height
	lsl	r1, #3

	//pop {r4, r5}
	ret

/*
 * outputs what's on the output buffer
 * to the screen
 *
 * @param r0:	if non-zero, last line will be cleared
 */
term_redraw_screen:

	push {r4, r5, r6, r7, r8, r9, r10, lr}

	current_char_p	.req r4
	position	.req r5
	buffer_start	.req r6
	buffer_end	.req r7
	x_bkp		.req r8
	y_bkp		.req r9
	is_scroll	.req r10

	mov	is_scroll, r0

	ldr	buffer_start, =term_output_buffer_start
	ldr	buffer_start, [buffer_start]

	ldr	buffer_end, =term_output_buffer_end
	ldr	buffer_end, [buffer_end]

	ldr	current_char_p, =term_output_buffer_screen_start
	ldr	current_char_p, [current_char_p]

	ldr	position, =#1
1:
	mov	r0, position
	bl	term_rel_pos_to_x_y

	mov	x_bkp, r0			// save the x-y values
	mov	y_bkp, r1

	ldrb	r2, =#127			// output DEL char.
	bl	term_output_char

	cmp	is_scroll, #0
	beq	2f

	// if it is scrolling check if we're
	// writing the last line, and clear it instead
	ldr	r0, =#term_last_line_begins_at
	cmp	position, r0
	bhs	3f
2:
	mov	r0, x_bkp			// restore x-y
	mov	r1, y_bkp

	ldrb	r2, [current_char_p]
	bl	term_output_char
3:
	add	current_char_p, #1
	cmp	current_char_p, buffer_end
	moveq	current_char_p, buffer_start

	add	position, #1
	cmp	position, #term_output_buffer_size
	bls	1b

	// cleanup aliases
	.unreq current_char_p
	.unreq position
	.unreq buffer_start
	.unreq buffer_end
	.unreq x_bkp
	.unreq y_bkp
	.unreq is_scroll

	pop {r4, r5, r6, r7, r8, r9, r10, pc}

/* ---------------------------------------
 * flush the terminal output buffer
 * to the screen
 * ---------------------------------------
 *
 */
.globl term_flush_output_buffer
term_flush_output_buffer:

	push	{r4, r5, r6, r7, r8, r9, lr}

	buf_start_addr 		.req r4
	buf_end_addr		.req r5
	write_from		.req r6
	relative_pos		.req r7
	chars_left		.req r8
	screen_start		.req r9

	// get how many characters left to write
	ldr	chars_left, =term_output_buffer_len
	ldr	chars_left, [chars_left]
	cmp	chars_left, #0		// if buffer is empty return now
	beq	3f

	// load addrs for buffer limits
	ldr	buf_start_addr, =term_output_buffer_start
	ldr	buf_start_addr, [buf_start_addr]

	ldr	buf_end_addr, =term_output_buffer_end
	ldr	buf_end_addr, [buf_end_addr]

	// load screen start pointer
	ldr	screen_start, =term_output_buffer_screen_start
	ldr	screen_start, [screen_start]

	// get the FROM addr in the buffer
	ldr	write_from, =term_output_buffer_write_from
	ldr	write_from, [write_from]

	// get relative position
	mov	r0, write_from			// prepare param in r0
	bl	term_rel_pos_from_output_buf	// get relative position
	mov	relative_pos, r0		// save relative pos in r7

1:

	cmp	chars_left, #0			// see if we're done
	beq	2f				// if yes go to end

	// prepare to output the character

	mov	r0, relative_pos		// prepare param
	// DEBUG
	//cmp	r0, #0
	//beq	error_panic
	// DEBUG
	bl	term_rel_pos_to_x_y		// get coord for rel. pos.

	// unless the character is already a DEL character
	// first output a DEL char. and then the character
	// from the buffer
	ldrb	r2, [write_from]		// read in char code
	teq	r2, #127

	ldrne	r2, =#127
	blne	term_output_char
	movne	r0, relative_pos		// prepare param
	blne	term_rel_pos_to_x_y		// get coord for rel. pos.

	// now comes the char in the buffer
	ldrb	r2, [write_from]		// read in char code
	bl	term_output_char		// write character to screen

	sub	chars_left, #1			// one character less to print

	add	relative_pos, #1		// increment relative position
	cmp	relative_pos, #term_output_buffer_size
	moveq	relative_pos, #1

	//
	// wrap up this and continue with next character
	add	write_from, #1			// increment `from` pointer
	cmp	write_from, buf_end_addr
	moveq	write_from, buf_start_addr

	b	1b

2:	// (end, save state...)

	// update `write from` pointer value
	ldr	r0, =term_output_buffer_write_from
	str	write_from, [r0]

	// DEBUG
	ldr	r1, =term_output_buffer_cursor
	ldr	r1, [r1]
	cmp	write_from, r1
	bne	error_panic
	// DEBUG

	// update `chars left`
	ldr	r0, =term_output_buffer_len
	str	chars_left, [r0]

	// (...and cleanup aliases)
3:
	.unreq buf_start_addr
	.unreq buf_end_addr
	.unreq write_from
	.unreq relative_pos
	.unreq chars_left
	.unreq screen_start

	pop {r4, r5, r6, r7, r8, r9, pc}

/* ---------------------------------------
 * print a string to the screen
 * ---------------------------------------
 *
 * @param r0	pointer to a null-
 *		terminated string
 */
.globl term_print
term_print:
	push {r4, r5, lr}

	mov	r4, r0		/* put r0 in r4 */
	mov	r5, #0		// zero-out r5

1:
	ldrb	r0, [r4]	/* get the value from the r4 addr in r0 */
	teq	r0, #0 		/* if it's the null char b to end */
	beq	2f

	bl	term_write_output_buffer
	teq	r0, #0
	addne	r5, #1

	add	r4, #1		/* incr. addr to next char */
	b	1b		/* continue with next char */

2:

	// check if the screen needs redrawing
	teq	r5, #1
	addeq	r0, #1 // prepare param to scroll on redraw
	bleq	term_redraw_screen

	/* flush the buffer */
	bl	term_flush_output_buffer

	pop {r4, r5, pc}

/* ---------------------------------------
 * this is a synchronous function, it
 * collects input and echoes it to the
 * screen until it receives a newline
 * character.
 *
 * ---------------------------------------
 *
	*/
.section .data

.align 2
term_input_echo_buf:
	.rept 	term_input_echo_buf_len
	.byte	0
	.endr

term_input_line_buf:
	.rept 	term_input_line_buf_len
	.byte	0
	.endr

.section .text
.globl term_readline
term_readline:
	push {r4, r5, r6, r7, r8, r9, r10, r11, lr}

	keys_flags	.req	r4
	input_echo_buf	.req	r5
	found_newline	.req	r6
	offset_echo_buf	.req	r7
	keymap		.req	r8
	flags_mask	.req	r9
	keys_down_addr	.req	r10
	input_line_buf	.req	r11

	// output prompt
	bl	term_display_prompt

	// get needed addresses and init
	ldr	input_line_buf, =term_input_line_buf
	mov	r0, #0			// initialize line buffer
	str	r0, [input_line_buf]

	bl	keyboard_get_keys_down_addr
	mov	keys_down_addr, r0

	ldr	input_echo_buf, =term_input_echo_buf
	ldr	keymap, =term_keymap

	mov	found_newline, #0
	mov	keys_flags, #0
1:
	/* get input from keyboard */
	mov	r0, keys_flags
	bl	keyboard_get_input
	mov	keys_flags, r0

	cmp	keys_flags, #0
	beq	1b

	//mov	keys_read, r0		// save the number of keys read
	mov	offset_echo_buf, #0	// init a counter in r7
	ldrb	flags_mask, =#0b00000001
2:
	// have we found a newline, forget the rest
	// of input collected, jump to print and and return
	cmp	found_newline, #1
	beq	3f

	// check the bit flag for this caracter
	// if it's not set skip it
	tst	keys_flags, flags_mask
	beq	3f	
	
	// load the next char received from keyboard in r0
	// and convert to ascii char code
	ldrh	r0, [keys_down_addr, offset_echo_buf]
	ldrb	r0, [keymap, r0]

	// is it a newline?
	teq	r0, #'\n'
	addeq	found_newline, #1

	// store the character in the string pointer + offset
	// for echo buffer
	strb	r0, [input_echo_buf, offset_echo_buf]

	// clear the bit flag for the char we just read
	bic	keys_flags, keys_flags, flags_mask

3:
	
	lsl	flags_mask, #1
	add	offset_echo_buf, #1
	cmp	offset_echo_buf, #6 // keyboard_max_keys_down
	blo	2b

	// add trailing \0 to echo buffer
	mov	r0, #0
	strb	r0, [input_echo_buf, offset_echo_buf]

	// echo collected input until now
	// or jump back if there's no input
	ldrb	r0, [input_echo_buf]
	teq	r0, #0
	beq	1b

	// unless there's only a newline char
	// to append to the line buffer,
	// make sure we're not about to overflow
	// the input line buffer
	ldrb	r0, [input_echo_buf]
	cmp	r0, #'\n'
	beq	l3b_term_readline$

	push	{r4}

	// get current length of input buffer
	mov	r0, input_line_buf
	bl	string_len

	// save max input line buf len in r4
	ldr	r4, =#term_input_line_buf_len

	// substract current length of input buffer
	sub	r4, r0

	// -1 for a possible newline in the next input
	sub	r4, #1

	// get current length of echo buffer
	//
	// NOTE: input echo buffer len may be slightly
	//       bigger, but that's not a problem here
	//

	mov	r1, input_echo_buf
	bl	string_len

	cmp	r4, r0			// compare the space we have in r4
					// with the space we need in r0
	pop	{r4}
	blo	l3c_term_readline$	// do not append any more input
					// if lower.

	l3b_term_readline$:		// hacky label, TODO: fix local labels

	// append the input to the line buffer
	// for processing after
	mov	r0, input_line_buf	// append dst
	mov	r1, input_echo_buf	// append src
	ldr	r2, =#1			// no newlines
	ldr	r3, =#1			// handle backspaces
	bl	string_append

	// echo input
	mov	r0, input_echo_buf
	bl	term_print

	l3c_term_readline$:		// hacky label, TODO: fix local labels

	// clear echo buffer
	mov	r0, #0
	str	r0, [input_echo_buf]
	str	r0, [input_echo_buf, #1]
	
	// output prompt
	bl	term_display_prompt

	/* keep on reading until there's a newline */
	cmp	found_newline, #1
	bne	1b

4:
	mov	r0, input_line_buf

	.unreq	keys_flags
	.unreq	input_echo_buf
	.unreq	found_newline
	.unreq	offset_echo_buf
	.unreq	keymap
	.unreq	flags_mask
	.unreq	keys_down_addr

	pop {r4, r5, r6, r7, r8, r9, r10, r11, pc}

/* ---------------------------------------
 *
 * ---------------------------------------*/
term_display_prompt:
	push {r4, r5, lr}

	ldr 	r0, =term_output_buffer_cursor
	ldr	r0, [r0]

	bl	term_rel_pos_from_output_buf	// get relative position
	bl	term_rel_pos_to_x_y		// get coord for rel. pos.

	mov	r4, r0			// save r0 and r1 to reuse
	mov	r5, r1

	ldrb	r2, =#127		// output DEL char.
	bl	term_output_char

	mov	r0, r4			// restore r0 and r1
	mov	r1, r5

	ldr	r2, =term_prompt	// output prompt char.
	ldrb	r2, [r2]
	bl	term_output_char

	pop {r4, r5, pc}

term_erase_prompt:
	push {lr}

	ldr 	r0, =term_output_buffer_cursor
	ldr	r0, [r0]

	bl	term_rel_pos_from_output_buf	// get relative position
	bl	term_rel_pos_to_x_y		// get coord for rel. pos.

	ldrb	r2, =#127		// output DEL char.
	bl	term_output_char

	pop {pc}

.globl term_print_newline
term_print_newline:
	push {lr}

	ldr	r0, =term_newline
	bl	term_print

	pop {pc}

/* ---------------------------------------
 *
 * ---------------------------------------*/

.section .data

term_prompt:
	.byte '@'
	.byte 0

term_newline:
	.2byte '\n', 0x0

term_keymap:
	.byte 0x0, 	0x0, 	0x0, 	0x0, 	'A', 	'B', 	'C', 	'D'
	.byte 'E', 	'F', 	'G', 	'H', 	'I', 	'J', 	'K', 	'L'
	.byte 'M', 	'N', 	'O', 	'P', 	'Q', 	'R', 	'S', 	'T'
	.byte 'U', 	'V', 	'W', 	'X', 	'Y', 	'Z', 	'1', 	'2'
	.byte '3', 	'4', 	'5', 	'6', 	'7', 	'8', 	'9', 	'0'
	.byte '\n', 	0x0, 	'\b', 	0x0, 	' ', 	0x0, 	0x0, 	0x0
	.byte 0x0, 	0x0, 	0x0, 	':', 	0x0, 	0x0, 	 ',', 	'.'
	.byte '?', 	0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	0x0
	.byte 0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	0x0
	.byte 0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	0x0
	.byte 0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	0x0, 	'-', 	0x0
	.byte '\n', 	'1', 	'2', 	'3', 	'4', 	'5', 	'6', 	'7'
	.byte '8', 	'9', 	'0', 	'.', 	0x0, 	0x0, 	0x0, 	0x0
