
	lkv 1
	ver 2

	ovr all
	asm morse16.s
	asm charctrl.s

	lnk morse16.l
	lnk charctrl.l

	typ $b3
	aux $db03
	sav morse16
	ent
*	cmd compile morse16.rez keep=morse16
