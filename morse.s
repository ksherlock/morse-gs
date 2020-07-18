
	rel
	xc
	xc


	tbx on

SoundCtrl	equ $e0c03c
SoundData	equ $e0c03d
SoundAddr	equ $e0c03e ; and $3f

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

main
	mx %00
	phk
	plb


	jsr init
	jsr start

	sep $30
]wait	lda _active
	beq :done
	
	lda >$e0c000 ; keydown - exit.
	bpl ]wait
	sta >$e0c010

:done
	rep $30
	jsr shutdown


	lda #0
	rtl

start
	mx %00

	stz _index
	stz _template
	stz _template+2
	stz _on
	stz _active

	sep $30
*]wait	lda >SoundCtrl
*	bmi ]wait
	docwait

* start osc 0-3 w/ volume 0.

	lda #$40
	sta >SoundAddr
	lda #0
	sta >SoundData
	sta >SoundData
	sta >SoundData
	sta >SoundData

	lda #$a0
	sta >SoundAddr
	lda #%0000_0_01_0 ; free-run, enabled
	sta >SoundData
	sta >SoundData
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
	jsr stop

	psw #$b
	psl old_irq
	_SetVector
	rts

stop
	mx %00
	stz _active

* shut off all oscillators.
	sep $30
*]wait	lda >SoundCtrl
*	bmi ]wait
	docwait

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
	rts

sound_irq
	mx %11

	lda >_active
	beq :ok
	clc
	rtl

:ok
	phb
	phk
	plb
	rep $30

	lsr _template+2
	ror _template

	sep $30
	bcc :off
	lda _on
	bne :trigger1
	ldx #$ff
	stx _on
	jsr setvolume

:trigger1 ; osc 5 interrupt on
	lda #$a0+timer_1
	sta >SoundAddr
	lda #%0000_1_01_0 ; one-shot, enabled, interrupt
	sta >SoundData
	bra :exit

:off
* turn off sound generators.
	stz _on
	ldx #0
	jsr setvolume
* check for advance...
	lda _template
	bne :trigger1

	rep $30
	ldx _index
	lda _buffer,x
	and #$ff
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

	pha
	pha
	psw #$b
	_GetVector
	pll old_irq

	psw #$b
	psl #sound_irq
	_SetVector

	sep $30

*]wait	lda >SoundCtrl
*	bmi ]wait
	docwait

	ora #%00100000		; auto increment (for later)
	bic #%01000000		; DOC mode
	sta >SoundCtrl


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
	lda #%0000_1_00_1 ; one-shot, halted, interrupt enabled.
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
	lda #<$0100  ; low
	sta >SoundData
	sta >SoundData
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
	lda #>$0100
	sta >SoundData
	sta >SoundData
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
	sta >SoundData
	sta >SoundData
	lda #$01 ; page 1 
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

*]wait	lda >SoundCtrl
*	bmi ]wait
	docwait

	ora #%01000000 ; ram mode
	sta >SoundCtrl

	lda #0
	sta >SoundAddr
	sta >SoundAddr+1

	ldx #0
]loop	lda b5,x
	sta >SoundData
	inx
	bne ]loop

* 256 silent bytes for the timer.
	lda #$80
]loop	sta >SoundData
	inx
	bne ]loop

* swap back to register mode.

*]wait	lda >SoundCtrl
*	bmi ]wait
	docwait

	bic #%01000000		; DOC mode
	sta >SoundCtrl


	rep #$30
	rts


	lst off

* 26300 hz
* want a 256-byte B5 sine wav
* coeff = 2 * PI * 987.767 / 26300 = 0.23598186697022278
* PI/2/coeff = 6.656428084760879
* PI/2/6.4 = 0.2454369260617026
* pcm = [128 + round(127 * sin(n*xx)) for n in range(0,256)]


b5
	hex 809fbcd5eaf8fefef5e6d1b6997a5b3f
	hex 26130601030d1e344f6d8cabc7def0fb
	hex fffbf0dec7ab8c6d4f341e0d03010613
	hex 263f5b7a99b6d1e6f5fefef8ead5bc9f
	hex 8061442b160802020b1a2f4a6786a5c1
	hex daedfafffdf3e2ccb193745539221005
	hex 0105102239557493b1cce2f3fdfffaed
	hex dac1a586674a2f1a0b020208162b4461
	hex 809fbcd5eaf8fefef5e6d1b6997a5b3f
	hex 26130601030d1e344f6d8cabc7def0fb
	hex fffbf0dec7ab8c6d4f341e0d03010613
	hex 263f5b7a99b6d1e6f5fefef8ead5bc9f
	hex 8061442b160802020b1a2f4a6786a5c1
	hex daedfafffdf3e2ccb193745539221005
	hex 0105102239557493b1cce2f3fdfffaed
	hex dac1a586674a2f1a0b020208162b4461


table

old_irq	ds 4
quit	ds 2
_active		ds 2
_template	ds 4
_on		ds 2
_index		ds 2
_buffer		ds 256

	sav morse.l
	lst on
	sym

