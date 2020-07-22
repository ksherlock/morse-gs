	lst off
	rel
	xc
	xc
	mx %00

	use E16.Control
*	lst on
	tbx on

ldax	mac
	if #=]1
	lda ]1
	ldx ^]1
	else
	lda ]1
	ldx ]1+2
	fin
	eom

stax	mac
	sta ]1
	stx ]1+2
	eom


res	= 0

	dum 1
ptr	ds 4
rtlb	ds 4
handle	ds 4
param	ds 4
code	ds 2
rv	ds 4

locals	= 4
params	= 4+4+2

	dend

char_control	ent

* Inputs:           On entry, the parameters are passed to us on the stack.
*
*                   |                   | Previous Contents
*                   |-------------------|
*                   |    ReturnValue    | LONG - Space for return value
*                   |-------------------|
*                   |    CtlCode        | WORD - operation to perform
*                   |-------------------|
*                   |    CtlParam       | LONG - add'l parameter
*                   |-------------------|
*                   |    theCtlHandle   | LONG - Handle to control record
*                   |-------------------|
*                   |    RtnAddr        | 3 BYTES - RTL address
*                   |-------------------|
*                   |                   | <-- Stack pointer
*
* Outputs:          Put something into ReturnValue, pull off the parameters,
*                   and return to the Control Manager.
*
*                   |                   | Previous Contents
*                   |-------------------|
*                   |    ReturnValue    | LONG - Space for return value
*                   |-------------------|
*                   |    RtnAddr        | 3 BYTES - RTL address
*                   |-------------------|
*                   |                   | <-- Stack pointer


	do res
	pha
	pha
	psl #char_control
	_FindHandle
	_HLock
	fin

	phb
	phk
	plb
	tsc
	do locals
	sec
	sbc #locals
	tcs
	fin
	phd
	tcd

	stz rv
	stz rv+2
	stz ptr
	stz ptr+2

	lda code
	cmp #:table_size+1
	bcs :exit

:deref

	asl
	tax

	lda :table,x
	beq :exit

	cpx #recSize*2
	beq :exec

	ldy #2
	lda [handle]
	sta ptr
	lda [handle],y
	sta ptr+2
	ldy #control_size-2

:loop	lda [ptr],y
	sta control,y
	dey
	dey
	bpl :loop


:exec
	jsr (:table,x)
	stax rv

:exit

	do res
	pha
	pha
	psl #char_control
	_FindHandle
	_HUnlock
	fin

	lda rtlb
	sta rv-4
	lda rtlb+2
	sta rv-2
	pld
	tsc
	clc
	adc #params+locals
	tcs
	plb
	rtl
:rts
	lda #0
	ldx #0
	rts

:table
	dw do_draw ; drawCtl
	dw 0 ; calcCRect
	dw 0 ; testCtl
	dw do_init ; initCtl
	dw 0 ; dispCtl
	dw 0 ; posCtl
	dw 0 ; thumbCtl
	dw 0 ; dragCtl
	dw 0 ; autoTrack
	dw do_draw ; newValue
	dw 0 ; setParams
	dw 0 ; moveCtl
	dw do_recsize ; recSize
	dw 0 ; ctlHandleEvent
	dw 0 ; ctlChangeTarget
	dw 0 ; ctlChangeBounds
	dw 0 ; ctlWindChangeSize
	dw 0 ; ctlHandleTab
	dw 0 ; ctlNotifyMultiPart
	dw 0 ; ctlWinStateChange

:table_size = {*-:table}/2

control
	ds	4	; next control
	ds	4	; window
	ds	8	; rect
	ds	1	; flags
	ds	1	; hilite
	ds	2	; value
	ds	4	; proc
	ds	4	; action
	ds	4	; data
	ds	4	; refcon
	ds	4	; colors
	ds	16	; reserved
	ds	4	; id
	ds	2	; more flags
	ds	2	; version

control_size equ *-control

do_recsize
	ldax #control_size
	rts

do_init

	lda #0
	ldy #octlValue
	sta [ptr],y
	ldy #octlData
	sta [ptr],y
	iny
	iny
	sta [ptr],y
	
	ldax #0
	rts

do_draw

	dum 0
y1	ds 2
x1	ds 2
y2	ds 2
x2	ds 2
	dend

*	brk $ea

* check if we need to draw
	lda control+oCtlFlag
	bit ctlInVis
	beq :visi
]rts	ldax #0
	rts

:visi
* need to set the background pattern / foreground pattern?

	pha
	pha
	_GetPort
	pha
	_GetFontFlags
	pha
	_GetTextMode


	psl control+octlOwner
	_SetPort

	_PenNormal

	psw #4
	_SetFontFlags

	psw #$4444 ; red
	_SetForeColor

	psw #$ffff
	_SetBackColor

	psw #0
	_SetTextMode


* erase the rect

*	psw #4
*	_SetSolidBackPat

	psl #control+octlRect
	_EraseRect


	lda control+octlValue
	and #$00ff
	beq :rts
	cmp #' '+1
	bcc :rts

* find the center of the rectangle.  should have left/right/center options.

	pea #0
	pha
	_CharWidth
	pla
	sta :w
	cmp #0
	beq :rts


	lda control+octlRect+x2
	sec
	sbc control+octlRect+x1
*	sta :rw
	sbc :w
	lsr ; /= 2
	clc
	adc control+octlRect+x1

	pha ; x
	lda control+octlRect+y2
	sec
	sbc #4
	pha ; y
	_MoveTo


	psw control+octlValue
	_DrawChar


:rts
	_SetTextMode
	_SetFontFlags
	_SetPort

	ldax #0
	rts

:w	ds 2
*:rw	ds 2

	sav charctrl.l
	sym
