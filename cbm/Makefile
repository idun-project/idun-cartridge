BUILD=build
SYSDIR=../sys

ACESYS=\
sys/ace.asm sys/config.asm sys/acecall.asm sys/acemem.asm \
sys/acewin.asm sys/acecon.asm sys/acetag.asm \
$(ACEHDRS) $(ACEDRVS)

ACEHDRS=\
sys/acehead.asm sys/kernhead.asm sys/acemacro.asm sys/toolhead.asm

ACEDRVS=\
sys/acevdc.asm sys/acevic.asm sys/acesoft80.asm idun-io.asm \
sys/acepid.asm sys/acepiserv.asm sys/hook.asm

KERNAL=$(SYSDIR)/idun128 \
$(SYSDIR)/idun-64

HOOK=$(SYSDIR)/boot128 \
$(SYSDIR)/boot-64

SYS=\
$(APPS) $(CMDS) $(RESC)

APPS=\
build/dos.app \
build/arcade.app

CMDS=\
build/tty\
build/edit\
build/mode\
build/keys\
build/del\
build/copy\
build/blanker\
build/joys\
build/diskcopy\
build/sidplay\
build/showvdc\
build/showzx\
build/mousetest\
build/liner\
build/go64\
build/browse\
build/zload

RESC=\
resc/chrset-commodore resc/chrset-standard resc/chrset-ansi resc/chrset-browse\
resc/autoexec.bat resc/basic780 resc/prompt.lua resc/sidplay.lua resc/tpat600.pbm\
resc/tpat480.pbm resc/tpat200.pbm resc/help.lua resc/commands.hlp resc/editor.hlp\
$(wildcard resc/dos/*) $(wildcard resc/util/*)

all: rel sys summary

rel: $(BUILD) $(SYSDIR)

$(BUILD): $(ACESYS)
	mkdir -p $@

sys: $(BUILD) $(SYSDIR) $(KERNAL) $(HOOK) $(SYS)
	@$(foreach f,$(SYS), cp $(f) $(SYSDIR);)

$(SYSDIR):
	mkdir -p $@/arcade.app.d

$(SYSDIR)/idun128 : idunk.asm $(ACESYS)
	acme -Dcomputer=128 -Dromsize=0 -o $(SYSDIR)/idun128 -f cbm idunk.asm

$(SYSDIR)/idun-64 : idunk.asm $(ACESYS)
	acme -Dcomputer=64 -Dromsize=0 -o $(SYSDIR)/idun-64 -f cbm idunk.asm

$(SYSDIR)/boot128 : $(ACESYS) resc/boot128.bas
	acme -Dcomputer=128 -o $(SYSDIR)/boot128 -f cbm sys/hook.asm

$(SYSDIR)/boot-64 : $(ACESYS) resc/boot.bas
	acme -Dcomputer=64 -o $(SYSDIR)/boot-64 -f cbm sys/hook.asm

$(CMDS): $(BUILD)/%: cmd/%.asm $(ACEHDRS) sys/toolhead.asm toolx/*/*
	acme --cpu 6510 --vicelabels $@.sym -f plain -o $@ $<

$(BUILD)/dos.app: dos.app.s $(ACEHDRS) sys/toolbox.asm
	acme --cpu 6510 --vicelabels $(BUILD)/dos.sym -f plain -o $(BUILD)/dos.app dos.app.s

$(BUILD)/arcade.app: arcade.app.s $(wildcard arcade.app.d/*.asm) $(wildcard arcade.app.d/*.m8x)
	acme --cpu 6510 --vicelabels $(BUILD)/arcade.sym -f plain -o $(BUILD)/arcade.app -I../cbm arcade.app.s
	@$(foreach f,$(wildcard arcade.app.d/*.lua), cp $(f) $(SYSDIR)/arcade.app.d;)

summary:
	@grep aceToolboxEnd $(BUILD)/dos.sym

clean:
	rm -fr $(BUILD)
	rm -fr $(SYSDIR)
