
/*
 * Definitions for return instructions
 */
	.macro ret
	mov pc,lr
	.endm

	.macro rethi
	movhi pc,lr
	.endm

	.macro retne
	movne pc,lr
	.endm

	.macro reteq
	moveq pc,lr
	.endm

	.macro retp
	pop {pc}
	.endm

	.macro retpne
	popne {pc}
	.endm

/* ----------------------------------------------
 * some palette commonly used colors  here */

.set palette_high_color_green,	0b0000011111100000
.set palette_high_color_red,	0b1111000000000000
.set palette_high_color_black, 	0b0
