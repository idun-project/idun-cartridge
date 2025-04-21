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
!macro DebugLogB .msg, .bp {
	lda #<.msg
	ldy #>.msg
	sta zp+0
	sty zp+1
!if .bp!=0 {
	lda .bp
	ldx #1
	jsr aceConDebugLog
} else {
	ldx #0
	jsr aceConDebugLog
}
}
!macro DebugLogW .msg, .wp {
	lda #<.msg
	ldy #>.msg
	sta zp+0
	sty zp+1
!if .wp!=0 {
	lda .wp+0
	sta zw+0
	lda .wp+1
	sta zw+1
	ldx #2
	jsr aceConDebugLog
} else {
	ldx #0
	jsr aceConDebugLog
}
}
!macro as_device {
	and #$1f
	asl
	asl
}