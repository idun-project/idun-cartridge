; *** Macros used with ACE core and applications
!macro ldaSCII .value {
	!if .value >="A" and .value <="Z" {
		lda #.value+$80
	}
	!if .value >= "a" and .value <="z" {
		lda #.value-$20
	}
	!if .value >= " " and .value <="?" {
		lda #.value
	}
	!if .value = "[" or .value = "@" {
		lda #.value
	}
}

!macro cmpASCII .value {
	!if .value >="A" and .value <="Z" {
		cmp #.value+$80
	}
	!if .value >= "a" and .value <="z" {
		cmp #.value-$20
	}
	!if .value >= " " and .value <="?" {
		cmp #.value
	}
	!if .value = "[" or .value = "@" {
		cmp #.value
	}
}
