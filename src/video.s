/* ---------------------------------------
 * Video driver for Raspberry pi 1 Model B
 * ---------------------------------------*/

/*
 * Format of GPU Framebuffer Structure:
 *
 * The structure expected by the GPU for initializing the frame buffer is as follows:
 * Bytes 	Name		Description
 *
 * 0-3 		width 		Width of the requested frame buffer.
 * 4-7 		height 		Height of the requested frame buffer.
 * 8-11 	virtual_width 	Virtual Width
 * 12-15 	virtual_height 	Virtual Height.
 * 16-19 	pitch 		Number of bytes between each row
 *				of the frame buffer. This is set by the GPU.
 *
 * 20-23 	depth 		The number of bits per pixel of the requested
 *				frame buffer.
 * 24-27 	x_offset 	Offset in the x direction.
 * 28-31 	y_offset 	Offset in the y direction.
 * 32-35 	pointer 	The pointer to the frame buffer
 *				into which your code should write.
 *				This is set by the GPU.
 * 36-39 	size 		The size of the frame buffer.
 *				Set by the GPU.
 *
 * Each of the 32-bit values should be little endian
 * (i.e: that of the included ARM processor). Hence a simple C struct
 * with a data type of uint32_t for each of these fields will suffice.
 *
 * (from: https://elinux.org/RPi_Framebuffer)
 *
 */

.include "globals.s"

.set video_no_cache_region_offset, 0x40000000
.set mailbox_num, 	1

.set video_width,	640
.set video_height,	480	
.set video_depth,	16	/* 16 bit, use high color */
.set video_pixel_size_bytes,	2

/*
 * The external entry points into this file are:
 *
 *   video_init_frame_buffer:	initialize frame buffer addr
 *				from the data structure.
 *   video_set_addr:		set the frame buffer addr to use
 *				(must be initialized first).
 *   video_set_color:		set the color to draw
 *   video_plot_pixel:		write a pixel to the screen.
 *   
 */
	
.section .data

/*
 * (from the docs:
 *  https://github.com/raspberrypi/firmware/wiki/Mailbox-framebuffer-interface)
 *
 * The buffer must be 16-byte aligned as only the upper 28 bits
 * of the address can be passed via the mailbox.
 */
.align 16

frame_buffer_struct:
	.int video_width	// width
	.int video_height	// height
	.int video_width	// virtual width
	.int video_height	// virtual height
	.int 0			// pitch (returned by GPU)
	.int video_depth	// depth
	.int 0			// x-offset (returned by GPU)
	.int 0			// y-offset (returned by GPU)
	.int 0			// pointer (returned by GPU)
	.int 0			// size (returned by GPU)

video_addr:
	.int 0

.align 2
.globl video_color
video_color:
	.2byte 0
	
.section .text

/* -----------------------------------------------
 * initialize frame buffer from the data structure
 * -----------------------------------------------
 *
 * IMPORTANT: this is a blocking call, it will
 *            block until it can send the message
 *            and receive an answer from the GPU
 *
 * @return      0: 	if not successful
 *		addr: 	of frame buffer struct if successful
 */
.globl video_init_frame_buffer
video_init_frame_buffer:
	ldr	r0,=frame_buffer_struct
	add	r0, #video_no_cache_region_offset
	mov	r1, #mailbox_num

	push 	{lr}
	bl	mlbox_snd

	mov	r0, #mailbox_num
	bl	mlbox_rcv

	teq	r0, #0
	movne	r0, #0
	retpne

	ldr	r0,=frame_buffer_struct
	
	retp

/* ---------------------------------------
 * set the frame buffer addr to use
 * (must be initialized first).
 * ---------------------------------------
 *
 * @param r0	addr to use
 */
.globl video_set_addr
video_set_addr:
	ldr	r1, =video_addr
	str	r0, [r1]
	ret

/* ---------------------------------------
 * set the active color to draw with
 * ---------------------------------------
 *
 * @param r0	16-bit color information
 */
.globl video_set_color
video_set_color:
	ldr	r1, =video_color
	strh	r0, [r1]
	ret

/* ---------------------------------------
 * write a pixel to the screen, to the
 * specified x-y coord.
 * ---------------------------------------
 *
 * @param r0	x
 * @param r1	y
 */
.globl video_plot_pixel
video_plot_pixel:

	/*
	 * validate params
	 * (this validation is fine as long
	 *  as screen resolution is hard-coded,
	 *  remember to change it if it's ever
	 *  parametrized)
	 */
	cmp 	r0, #video_width
	rethi

	cmp 	r1, #video_height
	rethi

	push {r4}

	/* get the video address to write to
	 */
	ldr 	r2, =video_addr /* store in r2 the video_addr pointer*/
	ldr 	r2, [r2]	/* dereference pointer */

	ldr	r2, [r2, #32] 	/* add fb structure pointer field offset */

	/*
	 * calculate pixel addr. offset
	 * and add it to video address
	 *
	 * video addr = (video addr + (x + y * width) * pixel size)
	*/
	mov	r3, #0
	ldr	r4, =video_width
	mla	r3, r1, r4, r0 /* add (y * width + x)
				* to r3 */

	ldr	r4, =video_pixel_size_bytes
	mla	r2, r3, r4, r2 /*
				* addr =
				* (r3 * pix size + addr) */

	ldr	r4, =video_color
	ldrh	r4, [r4]
	strh	r4, [r2]

	pop {r4}

	ret
