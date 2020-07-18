
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
	lda #%0000_0_00_0 ; free-run, enabled
	sta >SoundData
	lda #%0001_0_00_0 ; free-run, enabled
	sta >SoundData
	lda #%0000_0_00_0 ; free-run, enabled
	sta >SoundData
	lda #%0001_0_00_0 ; free-run, enabled
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
	rts

sound_irq
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
]loop	lda beep,x
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

* 26300 hz
* want a 256-byte B5 sine wav
* coeff = 2 * PI * 987.767 / 26300 = 0.23598186697022278
* PI/2/coeff = 6.656428084760879
* PI/2/6.4 = 0.2454369260617026
* pcm = [128 + round(127 * sin(n*xx)) for n in range(0,256)]


beep
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


noise
	hex 6c917262a488987a82a7895966a7589e
	hex 646a9b8887607b85a086925c678d7395
	hex 7686949c61a69a9897a7a5979d668371
	hex 91a05ca65972a48b857896906a6978a4
	hex a891679b826a83658c9c8d6162926b8a
	hex 8a6970589e8998986c87738b927c9f60
	hex 8372959289748c606ca6658e74a89471
	hex 966f8477799b606ca388a66b72847d5a
	hex 8b678f6983619080a17f6e775f5f787c
	hex 7a845a5890927a5ba66598a267746f79
	hex 985f94808a839da191a162848a7c6ea6
	hex 8376837d86689f7d9b94a57b6997688b
	hex 67a86b8e8869a85ca28b9e729d8c799a
	hex 629b8b678189728e9a8ba686a49f6a90
	hex 5879588f91797b6c5d7080587a6a6995
	hex 616da595987565a2a3a159a09a829974

table
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000001011101110101 ; !     ..--.
	adrl %00000000000000000101110101011101 ; "     .-..-.
	adrl %00000000000000000000010101011101 ; #     .-...
	adrl %00000000000000011101010111010101 ; $     ...-..-
	adrl %00000000000001110101110101010111 ; %     -...-.-
	adrl %00000000000000000111010111010101 ; &     ...-.-
	adrl %00000000000001011101110111011101 ; '     .----.
	adrl %00000000000000000101110111010111 ; (     -.--.
	adrl %00000000000001110101110111010111 ; )     -.--.-
	adrl %00000000000000000000010111010101 ; *     ...-.
	adrl %00000000000000000001011101011101 ; +     .-.-.
	adrl %00000000000001110111010101110111 ; ,     --..--
	adrl %00000000000000000111010101010111 ; -     -....-
	adrl %00000000000000011101011101011101 ; .     .-.-.-
	adrl %00000000000000000001011101010111 ; /     -..-.
	adrl %00000000000001110111011101110111 ; 0     -----
	adrl %00000000000000011101110111011101 ; 1     .----
	adrl %00000000000000000111011101110101 ; 2     ..---
	adrl %00000000000000000001110111010101 ; 3     ...--
	adrl %00000000000000000000011101010101 ; 4     ....-
	adrl %00000000000000000000000101010101 ; 5     .....
	adrl %00000000000000000000010101010111 ; 6     -....
	adrl %00000000000000000001010101110111 ; 7     --...
	adrl %00000000000000000101011101110111 ; 8     ---..
	adrl %00000000000000010111011101110111 ; 9     ----.
	adrl %00000000000000010101011101110111 ; :     ---...
	adrl %00000000000000010111010111010111 ; ;     -.-.-.
	adrl %00000000000000000000000000000000
	adrl %00000000000000000001110101010111 ; =     -...-
	adrl %00000000000000000000000000000000
	adrl %00000000000000000101011101110101 ; ?     ..--..
	adrl %00000000000000010111010111011101 ; @     .--.-.
	adrl %00000000000000000000000000011101 ; A     .-
	adrl %00000000000000000000000101010111 ; B     -...
	adrl %00000000000000000000010111010111 ; C     -.-.
	adrl %00000000000000000000000001010111 ; D     -..
	adrl %00000000000000000000000000000001 ; E     .
	adrl %00000000000000000000000101110101 ; F     ..-.
	adrl %00000000000000000000000101110111 ; G     --.
	adrl %00000000000000000000000001010101 ; H     ....
	adrl %00000000000000000000000000000101 ; I     ..
	adrl %00000000000000000001110111011101 ; J     .---
	adrl %00000000000000000000000111010111 ; K     -.-
	adrl %00000000000000000000000101011101 ; L     .-..
	adrl %00000000000000000000000001110111 ; M     --
	adrl %00000000000000000000000000010111 ; N     -.
	adrl %00000000000000000000011101110111 ; O     ---
	adrl %00000000000000000000010111011101 ; P     .--.
	adrl %00000000000000000001110101110111 ; Q     --.-
	adrl %00000000000000000000000001011101 ; R     .-.
	adrl %00000000000000000000000000010101 ; S     ...
	adrl %00000000000000000000000000000111 ; T     -
	adrl %00000000000000000000000001110101 ; U     ..-
	adrl %00000000000000000000000111010101 ; V     ...-
	adrl %00000000000000000000000111011101 ; W     .--
	adrl %00000000000000000000011101010111 ; X     -..-
	adrl %00000000000000000001110111010111 ; Y     -.--
	adrl %00000000000000000000010101110111 ; Z     --..
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000011101011101110101 ; _     ..--.-
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000011101 ; a     .-
	adrl %00000000000000000000000101010111 ; b     -...
	adrl %00000000000000000000010111010111 ; c     -.-.
	adrl %00000000000000000000000001010111 ; d     -..
	adrl %00000000000000000000000000000001 ; e     .
	adrl %00000000000000000000000101110101 ; f     ..-.
	adrl %00000000000000000000000101110111 ; g     --.
	adrl %00000000000000000000000001010101 ; h     ....
	adrl %00000000000000000000000000000101 ; i     ..
	adrl %00000000000000000001110111011101 ; j     .---
	adrl %00000000000000000000000111010111 ; k     -.-
	adrl %00000000000000000000000101011101 ; l     .-..
	adrl %00000000000000000000000001110111 ; m     --
	adrl %00000000000000000000000000010111 ; n     -.
	adrl %00000000000000000000011101110111 ; o     ---
	adrl %00000000000000000000010111011101 ; p     .--.
	adrl %00000000000000000001110101110111 ; q     --.-
	adrl %00000000000000000000000001011101 ; r     .-.
	adrl %00000000000000000000000000010101 ; s     ...
	adrl %00000000000000000000000000000111 ; t     -
	adrl %00000000000000000000000001110101 ; u     ..-
	adrl %00000000000000000000000111010101 ; v     ...-
	adrl %00000000000000000000000111011101 ; w     .--
	adrl %00000000000000000000011101010111 ; x     -..-
	adrl %00000000000000000001110111010111 ; y     -.--
	adrl %00000000000000000000010101110111 ; z     --..
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000
	adrl %00000000000000000000000000000000


old_irq	ds 4
quit	ds 2
_active		ds 2
_template	ds 4
_on		ds 2
_index		ds 2
*_buffer		ds 256
_buffer		asc 'SOS SOS SOS',00

	sav morse.l
	lst on
	sym

