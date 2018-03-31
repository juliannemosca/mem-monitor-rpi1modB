/* -----------------------------------------
 * Mailbox driver for Raspberry pi 1 Model B
 * -----------------------------------------*/

/* Notes:
 *
 * 2000b880-2000b8bf : bcm2835-mbox addresses
 * ---------------------------------------
 * Mailbox registers
 *
 * The following table shows the register offsets for the different mailboxes.
 * For a description of the procedure for using these registers
 * to access a mailbox, see:
 * https://github.com/raspberrypi/firmware/wiki/Accessing-mailboxes
 *
 * Mailbox 	Peek  	Read/Write  	Status  	Sender  	Config
 *   0    	0x10  	0x00        	0x18    	0x14    	0x1c
 *   1    	0x30  	0x20        	0x38    	0x34    	0x3c
 *
 *
 * from: https://github.com/raspberrypi/firmware/wiki/Mailboxes
 *
 */

.include "globals.s"
	
.set mlbox_base_addr, 		0x2000B880
.set mlbox_rw_offset, 		0x20
.set mlbox_status_offset, 	0x18

// This bit is set in the status register if there is no space to write into the mailbox
.set mlbox_full, 		0x80000000
// This bit is set in the status register if there is nothing to read from the mailbox
.set mlbox_empty,  		0x40000000

	.macro waitWhileMlbox statusreg, mbox, mask
1:	
	ldr \statusreg,[\mbox,#mlbox_status_offset]
	tst \statusreg,#\mask
	bne 1
	.endm


/*
 * The external entry points into this file are:
 *
 *   mlbox_load_addr: 	return the mailbox base addr
 *   mlbox_snd:		send a message to a mailbox
 *   mlbox_rcv:		receive a message from a mailbox
 *   
 */
	
/* ---------------------------------------
 * return the mailbox base addr
 * ---------------------------------------
 */
.globl mlbox_load_addr
mlbox_load_addr:
	ldr r0, =mlbox_base_addr
	ret

/* ---------------------------------------
 * send a message to a mailbox
 * ---------------------------------------
 *
 * @param r0	message
 * @param r1	mailbox for sending
 */
.globl mlbox_snd
mlbox_snd:

	/*
	 * validate params
	 */
	tst 	r0,#0b1111 	/* message will be added to mbox num
				 * lowest 4 bits are reserved and have
				 * to be 0 */
	retne

	cmp 	r1,#1		/* we only support mailbox 1 */
	rethi

	/*
	 * load address, wait for ready, send
	 */
	mov 	r2, r0 		/* move r0 to r2 before loading mbox addr*/
	push 	{lr}
	bl 	mlbox_load_addr

	waitWhileMlbox r3, r0, mlbox_full	/* use r3 for status, of mailbox in r0,
					 * against bitmask
					 * 0x80000000 (mlbox_full)
					 * to wait until it's not full
					 */

	add 	r1, r2				/* add channel to msg */
	str	r1,[r0,#mlbox_rw_offset]	/* store r1 into the mailbox
						 * addr + rw offset */

	retp

/* ---------------------------------------
 * receive a message from a mailbox
 * ---------------------------------------
 *
 * @param r0	mailbox for receiving
 *
 * @return      received message
 */
.globl mlbox_rcv
mlbox_rcv:

	/*
	 * validate params
	 */
	cmp 	r0,#1		/* we only support mailbox 1 */
	rethi

	/*
	 * load address, wait for ready, receive and check sender
	 */
	mov 	r1, r0 		/* move r0 to r1 before loading mbox addr*/
	push 	{lr}
	bl 	mlbox_load_addr

	keepWaitingMlboxRcv$:		/* we'll branch here if it is not
					 * from the right sender */

	waitWhileMlbox r2 r0 mlbox_empty	/*
					 * use r2 for status, of mailbox in r0,
					 * against bitmask
					 * 0x40000000 (mlbox_empty)
					 * to wait until it's not empty
					 */

	and r3, r2,#0b1111		/* AND the status value in r2 to 0xF
					 * to get the sender, put it in r3 */
	teq r3, r1			/* is this message for us? */
	bne keepWaitingMlboxRcv$	/* if not keep waiting */

	and r0,r2,#0xfffffff0		/* move the answer (top 28 bits of r2)
					 * to r0 */

	retp
