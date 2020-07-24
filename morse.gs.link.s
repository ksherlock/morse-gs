
	lkv 1
	ver 2

	ovr all
	asm morse.gs.s
	asm charctrl.s

	lnk morse.gs.l
	lnk charctrl.l

	typ $b3
	aux $db03
	sav morse.gs
	ent
*	cmd compile morse.gs.rez keep=morse.gs
