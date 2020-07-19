
	lst off
	rel
	xc
	xc


	tbx on

border_color	equ 0

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

	jsr cmdline

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


cmdline
]ptr	equ 0
]c	equ 4

	mx %00
*	brk $ea
	; x:y is command line ptr.
	sty 0
	stx 2
	stz ]c

	ldx #0
]loop   lda :default,x
	sta _buffer,x
	beq :eod
	inx
	inx
	bra ]loop
:eod

	lda 0
	ora 2
	beq :eof2
	lda #0  ; clear b accumulator for tax.

* skip past first word of command line.
	sep $20
	ldy #8
]loop	lda [0],y
	beq :eof2
	iny
	cmp #' '+1
	bcs ]loop

	ldx #0
]loop	lda [0],y
	beq :eof
	iny
	and #$7f
	phx
	tax
	bit valid,x
	plx
	bvc :inval
	sta _buffer,x
	inx
	stz ]c
	bra ]loop
:inval
	lda ]c
	bne ]loop
	lda #' '
	sta _buffer,x
	inx
	inc ]c
	bra ]loop


:eof
	stz _buffer,x
:eof2
	rep $20
	rts

:default asc 'SOS',00,00,00



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
	jsr stop

	psw #$b
	psl old_irq
	_SetVector

	if border_color
	sep $20
	lda >$e0c034
	and #$f0
	ora old_border
	sta >$e0c034
	rep $20
	fin
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
*	lda _on
*	bne :trigger1
*	ldx #$ff
*	stx _on
	jsr beep_on
*	jsr setvolume

	if border_color
	lda >$e0c034 ; white border
	ora #$0f
	sta >$e0c034
	fin

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
	if border_color
	lda >$e0c034 ; black border
	and #$f0
	sta >$e0c034
	fin

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
** volume.
*	lda #$40
*	sta >SoundAddr
*	lda #$ff
*	sta >SoundData
*	sta >SoundData
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

	pha
	pha
	psw #$b
	_GetVector
	pll old_irq

	psw #$b
	psl #sound_irq
	_SetVector

	sep $30

	if border_color
	lda >$e0c034
	and #$0f
	sta old_border
	fin

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

* 26300 hz
* want a 256-byte B5 sine wav
* coeff = 2 * PI * 987.767 / 26300 = 0.23598186697022278
* PI/2/coeff = 6.656428084760879
* PI/2/6.4 = 0.2454369260617026
* pcm = [128 + round(127 * sin(n*xx)) for n in range(0,256)]


beep_b5
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

beep_f5
	hex 8096abbfd1e0edf6fdfffef9f0e4d5c4
	hex b19c86705b473424160c050102060d18
	hex 26374a5e74899fb3c7d8e6f1fafefffc
	hex f5ebdecebca8937d67523f2d1e110803
	hex 010308111e2d3f52677d93a8bccedeeb
	hex f5fcfffefaf1e6d8c7b39f89745e4a37
	hex 26180d060201050c162434475b70869c
	hex b1c4d5e4f0f9fefffdf6ede0d1bfab96
	hex 806a55412f20130a03010207101c2b3c
	hex 4f647a90a5b9ccdceaf4fbfffefaf3e8
	hex dac9b6a28c77614d39281a0f06020104
	hex 0b15223244586d8399aec1d3e2eff8fd
	hex fffdf8efe2d3c1ae99836d5844322215
	hex 0b040102060f1a28394d61778ca2b6c9
	hex dae8f3fafefffbf4eadcccb9a5907a64
	hex 4f3c2b1c10070201030a13202f41556a

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

valid
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $40 ; !     ..--.
	db $40 ; "     .-..-.
	db $40 ; #     .-...
	db $40 ; $     ...-..-
	db $40 ; %     -...-.-
	db $40 ; &     ...-.-
	db $40 ; '     .----.
	db $40 ; (     -.--.
	db $40 ; )     -.--.-
	db $40 ; *     ...-.
	db $40 ; +     .-.-.
	db $40 ; ,     --..--
	db $40 ; -     -....-
	db $40 ; .     .-.-.-
	db $40 ; /     -..-.
	db $40 ; 0     -----
	db $40 ; 1     .----
	db $40 ; 2     ..---
	db $40 ; 3     ...--
	db $40 ; 4     ....-
	db $40 ; 5     .....
	db $40 ; 6     -....
	db $40 ; 7     --...
	db $40 ; 8     ---..
	db $40 ; 9     ----.
	db $40 ; :     ---...
	db $40 ; ;     -.-.-.
	db $00
	db $40 ; =     -...-
	db $00
	db $40 ; ?     ..--..
	db $40 ; @     .--.-.
	db $40 ; A     .-
	db $40 ; B     -...
	db $40 ; C     -.-.
	db $40 ; D     -..
	db $40 ; E     .
	db $40 ; F     ..-.
	db $40 ; G     --.
	db $40 ; H     ....
	db $40 ; I     ..
	db $40 ; J     .---
	db $40 ; K     -.-
	db $40 ; L     .-..
	db $40 ; M     --
	db $40 ; N     -.
	db $40 ; O     ---
	db $40 ; P     .--.
	db $40 ; Q     --.-
	db $40 ; R     .-.
	db $40 ; S     ...
	db $40 ; T     -
	db $40 ; U     ..-
	db $40 ; V     ...-
	db $40 ; W     .--
	db $40 ; X     -..-
	db $40 ; Y     -.--
	db $40 ; Z     --..
	db $00
	db $00
	db $00
	db $00
	db $40 ; _     ..--.-
	db $00
	db $40 ; a     .-
	db $40 ; b     -...
	db $40 ; c     -.-.
	db $40 ; d     -..
	db $40 ; e     .
	db $40 ; f     ..-.
	db $40 ; g     --.
	db $40 ; h     ....
	db $40 ; i     ..
	db $40 ; j     .---
	db $40 ; k     -.-
	db $40 ; l     .-..
	db $40 ; m     --
	db $40 ; n     -.
	db $40 ; o     ---
	db $40 ; p     .--.
	db $40 ; q     --.-
	db $40 ; r     .-.
	db $40 ; s     ...
	db $40 ; t     -
	db $40 ; u     ..-
	db $40 ; v     ...-
	db $40 ; w     .--
	db $40 ; x     -..-
	db $40 ; y     -.--
	db $40 ; z     --..
	db $00
	db $00
	db $00
	db $00
	db $00

old_irq	ds 4
old_border ds 2 
quit	ds 2
_active		ds 2
_template	ds 4
_on		ds 2
_index		ds 2
_buffer		ds 256
*_buffer		asc 'Apple 2 forever',00

	sav morse.l
*	lst on
	typ exe
	sym

