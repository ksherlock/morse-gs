	lst off
	rel
	xc
	xc

	use morse.equ
	use e16.window
	use e16.event
	use e16.types
	use e16.control
	use e16.resources

*	lst on

kWindowID equ $1000
kPlayID	equ 1
kStopID	equ 2
kAboutAlert equ 1

	tbx on


beep_left	equ 0
beep_right	equ 1
noise_left	equ 2
noise_right	equ 3
timer_1		equ 4
timer_3		equ 5
timer_7		equ 6


bic	mac
	if #=]1
	and ]1!$ffff
	else
	err 1 ; immediate only.
	fin
	<<<

docwait	mac
	if MX<2
	err 1 ; 8-bit m only
	fin
wait	lda >SoundCtrl
	bmi wait
	<<<

docmode mac
	docwait
*	lda >SoundAddr
	bic #%01000000 ; DOC mode
	ora #%00100000 ; auto-incr
	sta >SoundCtrl
	<<<


main
	mx %00
	phk
	plb

	sta MyID
	jsr init

	jsr mainloop

	jsr shutdown
	_GSOS:Quit :QuitDCB
	brk $ea

:QuitDCB	dw 2
		adrl 0
		dw 0


draw_window
	pha
	pha
	_GetPort
	_DrawControls
	rtl


mainloop

	pha
	pha ; result
	psl #0
	psl #0
	psl #draw_window
	psl #0
	psw #refIsResource
	psl #kWindowID
	psw #rWindParam1
	_NewWindow2
	lda 3,s
	sta window+2
	lda 1,s
	sta window
*	pll window

*	psl window
	_ShowWindow

	_InitCursor
	stz quit

	lda #$0001ffff
	sta event+owmTaskMask
	lda #^$0001ffff
	sta event+owmTaskMask+2

:loop
	pha
	psw #-1
	psl #event
	_TaskMaster
	pla
	cmp #:table_size+1
	bcs :loop

	asl
	jsr (:table,x)
	lda quit
	beq :loop

:rts
	rts

:table
	dw :idle ; null
	dw :rts ; mouse down
	dw :rts ; mouse up
	dw :rts ; key down
	dw :rts ; auto key down
	dw :rts
	dw :rts ; update
	dw :rts
	dw :rts ; activate
	dw :rts ; switch
	dw :rts ; desk acc.
	dw :rts ; driver
	dw :rts ; app 1
	dw :rts ; app 2
	dw :rts ; app 3
	dw :rts ; app 4
	dw :rts ; wInDesk
	dw menu ; wInMenuBar
	dw :rts ; wClickCalled
	dw :rts ; wInContent
	dw :rts ; wInDrag
	dw :rts ; wInGrow
	dw bye ; wInGoAway
	dw :rts ; wInZoom
	dw :rts ; wInInfo
	dw menu ; wInSpecial menu 250-255
	dw :rts ; wInDeskItem menu 1-249
	dw :rts ; wInFrame
	dw :rts ; wInactMenu
	dw :rts ; wClosedNDA
	dw :rts ; wCalledSysEdit
	dw :rts ; wTrackZoom
	dw :rts ; wHitFrame
	dw control ; wInControl
	dw :rts ; wInControlMenu
:table_size = {*-:table}/2

:idle
	lda _finished
	beq :rts
	stz _finished
	brl stopped

bye
	lda #1
	sta quit
	rts


menu
	lda event+owmTaskData
	sec
	sbc #250
	cmp #:table_size+1
	bcs :xmenu

	asl
	tax
	jsr (:table,x)
:xmenu
	psw #0
	psw event+owmTaskData+2
	_HiliteMenu
:rts	rts

:table
	dw :rts ; 250 undo
	dw :rts ; 251 cut
	dw :rts ; 252 copy
	dw :rts ; 253 paste
	dw :rts ; 254 clear
	dw :rts ; 255 close
	dw bye ; 256 - quit
	dw about
:table_size = {*-:table}/2

about
	pha
	psw #awResource
	psl #0
	psl #kAboutAlert
	_AlertWindow
	pla
	rts

control
	lda event+owmTaskData4 ; id of control selected.
	cmp #:table_size+1
	bcs :rts
	asl
	tax
	jmp (:table,x)
:rts	rts

:table
	dw :rts ; 0 - none
	dw play
	dw stop
:table_size = {*-:table}/2


play
* copy text to the buffer and start audio.

	pha
	pha
	psw #%00000000000_00_001 ; c-string, ptr
	psl #_buffer
	psl #256
	psw #0 ; style 
	psl #0 ; style ref
	psl #0 ; teHandle.
	_TEGetText
	pla
*	sta :len
	pla

	bcs :err

	jsr buffer_to_buffer
	bcc :err ;

* can use key filter to block invalid characters....
* copy/convert :buffer to _buffer -still needed for space elimination,
* disable text edit?
* disable play button
* enable stop button
* queue up playing

	psw #inactiveHilite
	psl window ; window
	psl #kPlayID
	_HiliteCtlByID

	psw #noHilite
	psl window ; window
	psl #kStopID
	_HiliteCtlByID

	jsr start_audio

:err	rts


buffer_to_buffer
:c	equ 0

	lda #0
	ldx #0
	ldy #0
	stz :c

	sep $20

:loop	lda _buffer,x
	beq :eof
	bmi :space
	cmp #' '+1
	bcc :space
	phx
	tax
	bit valid,x
	plx
	bvc :space
	sta _buffer,y
	inx
	iny
	stz :c
	bra :loop	

:space	inx
	lda :c
	bne :loop
	inc :c
	lda #' '
	sta _buffer,y
	iny
	bra :loop

:eof	sta _buffer,y
	rep $20
	tya ; len
	cmp #1
	rts


stop
	jsr stop_audio

stopped
* enable controls
	psw #noHilite
	psl window ; window
	psl #kPlayID
	_HiliteCtlByID

	psw #inactiveHilite
	psl window ; window
	psl #kStopID
	_HiliteCtlByID

	rts



start_audio
	mx %00

	stz _index
	stz _template
	stz _template+2
	stz _on
	stz _active
	stz _finished

	sep $30

	docmode

* start osc 0-3 w/ volume 0.

	lda #$40
	sta >SoundAddr
	lda #0
	sta >SoundData
	sta >SoundData
	lda #$01  ; silent channel to fix GS+ audio deficiencies.
	sta >SoundData
	sta >SoundData

	lda #$a0
	sta >SoundAddr
	lda #%0000_0_00_1 ; free-run, disabled
	sta >SoundData
	lda #%0001_0_00_1 ; free-run, disabled
	sta >SoundData
	lda #%0000_0_00_0 ; free-run, enabled
	sta >SoundData
	lda #%0001_0_00_0 ; free-run, enabled
	sta >SoundData

* volume, again.
	lda #$40
	sta >SoundAddr
	lda #$ff
	sta >SoundData
	sta >SoundData


* trigger the timing oscillator.
	lda #$a0+timer_1
	sta >SoundAddr
	lda #%0000_1_01_0 ; one-shot, enabled, interrupt
	sta >SoundData
	rep $30

	inc _active

	rts

shutdown
	mx %00
	jsr stop_audio

	psw #$b
	psl old_irq
	_SetVector

	psw #refIsHandle
	psl tools
	_ShutDownTools
	psw MyID
	_MMShutDown
	_TLShutDown

	rts

stop_audio
	mx %00
	stz _active

* shut off all oscillators.
	sep $30

	docmode

	lda #$a0
	sta >SoundAddr
	lda #%0000_0_01_1 ; one-shot, disabled, nointerrupt
	sta >SoundData
	sta >SoundData
	sta >SoundData
	sta >SoundData
	sta >SoundData
	sta >SoundData
	sta >SoundData

	rep #$30
	stz _finished

	rts

audio_irq
	mx %11

	lda >_active
	bne :ok
	clc
	rtl

:ok
	phb
	phk
	plb

	docmode

	rep $30

	lsr _template+2
	ror _template

	sep $30
	bcc :off
*	lda _on
*	bne :trigger1
*	ldx #$ff
*	stx _on
	jsr beep_on
*	jsr setvolume


:trigger1 ; osc 5 interrupt on
	lda #$a0+timer_1
	sta >SoundAddr
	lda #%0000_1_01_0 ; one-shot, enabled, interrupt
	sta >SoundData
	bra :exit

:off
* turn off sound generators.
*	stz _on
*	ldx #0
*	jsr setvolume
	jsr beep_off


* check for advance...
	lda _template
	bne :trigger1

	rep $30
	ldx _index
	lda _buffer,x
	and #$7f
	beq :fini

	inx
	stx _index
	cmp #' '+1
	blt :space

	asl
	asl
	tax
	lda table,x
	sta _template
	lda table+2,x
	sta _template+2
	sep $30
*	bra :trigger3 ; inter-char delay.

:trigger3 ; osc 6 interrupt on
	lda #$a0+timer_3
	sta >SoundAddr
	lda #%0000_1_01_0 ; one-shot, enabled, interrupt
	sta >SoundData
	bra :exit



:fini	mx %00
*	stz _index
	stz _active
	inc _finished
	bra :exit

:space	mx %00
	stz _template ; should already be 0.
	stz _template+2
	sep $30
*	bra :trigger7 ; inter-word delay

:trigger7 ; osc 7 interrupt on
	lda #$a0+timer_7
	sta >SoundAddr
	lda #%0000_1_01_0 ; one-shot, enabled, interrupt
	sta >SoundData
	bra :exit

:exit
	plb
	clc
	rtl

beep_on
	mx %11
	lda _on
	bne :rts
	lda #$a0
	sta >SoundAddr
	lda #%0000_0_00_0 ; free-run, enabled
	sta >SoundData
	lda #%0001_0_00_0 ; free-run, enabled
	sta >SoundData
	inc _on

:rts	rts

beep_off ; changes to one-shot mode so it will expire at the end of the sample
	mx %11
	lda _on
	beq :rts
	lda #$a0
	sta >SoundAddr
	lda #%0000_0_01_0 ; one-shot, enabled
	sta >SoundData
	lda #%0001_0_01_0 ; one-shot, enabled
	sta >SoundData
	stz _on
:rts	rts

setvolume
	mx %11
	lda #$40
	sta >SoundAddr
	txa
	sta >SoundData
	sta >SoundData
	rts



init
	mx %00

	_TLStartUp
	pha
	pha
	psw MyID
	psw #refIsResource
	psl #1
	_StartUpTools
	pll tools

	pha
	pha
	psw #refIsResource
	psl #1
	psl #0
	_NewMenuBar2
	_SetSysBar

	psl #0
	_SetMenuBar

	psw #1
	_FixAppleMenu

	pha
	_FixMenuBar
	pla
	_DrawMenuBar

	jsr init_audio
	rts

init_audio
	pha
	pha
	psw #$b
	_GetVector
	pll old_irq

	psw #$b
	psl #audio_irq
	_SetVector

	sep $30

	docmode


* halt all oscillators. 
	ldy #$20-7
	lda #$a0
	sta >SoundAddr

* osc 1-4 are free-run, halted, stereo pairs.
	lda #%0000_0_00_1 ; free-run, halted
	sta >SoundData
	lda #%0001_0_00_1 ; free-run, halted
	sta >SoundData
	lda #%0000_0_00_1 ; free-run, halted
	sta >SoundData
	lda #%0001_0_00_1 ; free-run, halted
	sta >SoundData

* 5-7 are one-shot, interrupt enabled, halted.
	lda #%0000_1_01_1 ; one-shot, halted, interrupt enabled.
	sta >SoundData
	sta >SoundData
	sta >SoundData

* all others - halted.
	lda #%0000_0_01_1 ; one-shot, halted
]loop	sta >SoundData
	dey
	bne ]loop


* volume 0
	ldy #$20
	lda #$40
	sta >SoundAddr
	lda #0
]loop	sta >SoundData
	dey
	bne ]loop


* 32 oscillators.

	lda #$e1
	sta >SoundAddr
	lda #31*2
	sta >SoundData

* osc 1/2 are 256 bytes, running at the natural rate.

* osc 5/6/7 are 256 bytes, running at 1 / 3 / 6 time units 

* frequency low registers
	lda #$00
	sta >SoundAddr
	lda #<$0200  ; low
	sta >SoundData
	sta >SoundData
*	lda #>$0180
	sta >SoundData
	sta >SoundData

	lda #<5103
	sta >SoundData
	lda #<1701
	sta >SoundData
	lda #<729
	sta >SoundData

* freq high
	lda #$20
	sta >SoundAddr
	lda #>$0200
	sta >SoundData
	sta >SoundData
*	lda #>$0180
	sta >SoundData
	sta >SoundData

	lda #>5103
	sta >SoundData
	lda #>1701
	sta >SoundData
	lda #>729
	sta >SoundData



* wave table pointer
	lda #$80
	sta >SoundAddr
	lda #$00 ; page 0
	sta >SoundData
	sta >SoundData
	inc ; page 1
	sta >SoundData
	sta >SoundData
*	inc ; page 2 
	sta >SoundData
	sta >SoundData
	sta >SoundData

* wave table size registers
	lda #$c0
	sta >SoundAddr
* 1-4 use 256 byte date, 9-bit shift.
	lda #%00000000
	sta >SoundData
	sta >SoundData
	sta >SoundData
	sta >SoundData
* 5-7 use 256 byte data, 16-bit shift
	lda #%00_000_111
	sta >SoundData
	sta >SoundData
	sta >SoundData


* now load data...

	docwait

	ora #%01100000 ; ram mode, incr
	sta >SoundCtrl

	lda #0
	sta >SoundAddr
	sta >SoundAddr+1

	ldx #0
]loop	lda beep_f5,x
	sta >SoundData
	inx
	bne ]loop


*]loop	lda noise,x
*	sta >SoundData
*	inx
*	bne ]loop


* 256 silent bytes for the timer.
	lda #$80
]loop	sta >SoundData
	inx
	bne ]loop


	rep #$30

	rts


	lst off
	put tables

old_irq	ds 4

tools	ds 4
window	ds 4
MyID	ds 2


quit	ds 2
event	ds wmTaskRecSize





_active		ds 2
_finished	ds 2
_on		ds 2

_template	ds 4
_index		ds 2
_buffer		ds 256
*_buffer		asc 'Apple 2 forever',00

	dat 8

	sav morse16.l
*	lst on
	sym

