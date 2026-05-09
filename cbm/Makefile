BUILD=build
SYSDIR=../sys
ACME=acme --dialect 0.94.12

ACESYS=\
sys/ace.asm sys/config.asm sys/acecall.asm sys/acemem.asm \
sys/acewin.asm sys/acecon.asm sys/tags.asm sys/eram.asm \
$(ACEHDRS) $(ACEDRVS)

ACEHDRS=\
sys/acehead.asm sys/kernhead.asm sys/acemacro.asm sys/toolhead.asm

ACEDRVS=\
sys/acevdc.asm sys/acevic.asm sys/acesoft80.asm idun-io.asm \
sys/acepid.asm sys/acepiserv.asm sys/hook.asm

KERNEL=$(SYSDIR)/idun128 \
$(SYSDIR)/idun-64

HOOK=$(SYSDIR)/boot128 \
$(SYSDIR)/boot-64

SYS=\
$(APPS) $(CMDS) $(RESC)

APPS=\
build/dos.app \
build/cpm.app \
build/arcade.app \
build/shell.app

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
build/zload\
build/showkoa\
build/boxer\
build/turbo\
build/nmitest

TEST=\
build/eram

RESC=\
resc/chrset-commodore resc/chrset-standard resc/chrset-ansi resc/chrset-browse\
resc/autoexec.bat resc/basic780 resc/prompt.lua resc/sidplay.lua resc/tpat600.pbm\
resc/tpat480.pbm resc/tpat200.pbm resc/help.lua resc/commands.hlp resc/editor.hlp\
resc/makerom.lua resc/kernal128.patch resc/kernal64.patch\
$(wildcard resc/dos/*) $(wildcard resc/util/*)

all: rel sys

rel: $(BUILD) $(SYSDIR)

test: $(TEST)

$(BUILD): $(ACESYS)
	mkdir -p $@

sys: $(BUILD) $(SYSDIR) $(KERNEL) $(HOOK) $(SYS)
	@$(foreach f,$(SYS), cp $(f) $(SYSDIR);)

$(SYSDIR):
	mkdir -p $@/arcade.app.d

$(SYSDIR)/idun128 : idunk.asm $(ACESYS)
	$(ACME) --vicelabels $(BUILD)/idun128.sym -Dcomputer=128 -Dromsize=0 -o $(SYSDIR)/idun128 -f cbm idunk.asm

$(SYSDIR)/idun-64 : idunk.asm $(ACESYS)
	$(ACME) --vicelabels $(BUILD)/idun.sym -Dcomputer=64 -Dromsize=0 -o $(SYSDIR)/idun-64 -f cbm idunk.asm

$(SYSDIR)/boot128 : $(ACESYS) resc/boot128.prg
	$(ACME) -Dcomputer=128 -o $(SYSDIR)/boot128 -f cbm sys/hook.asm

$(SYSDIR)/boot-64 : $(ACESYS) resc/boot.prg
	$(ACME) -Dcomputer=64 -o $(SYSDIR)/boot-64 -f cbm sys/hook.asm

resc/boot128.prg : resc/boot128.bas
	bastext -o $<

resc/boot.prg : resc/boot.bas
	bastext -o $<

$(CMDS): $(BUILD)/%: cmd/%.asm $(ACEHDRS) sys/toolhead.asm toolx/* toolx/*/*
	$(ACME) --cpu 6510 --vicelabels $@.sym -f plain -o $@ $<

$(TEST): $(BUILD)/%: cmd/%.asm $(ACEHDRS)
	$(ACME) --cpu 6510 --vicelabels $@.sym -f plain -o $@ $<
	@$(foreach f,$(TEST), cp $(f) $(SYSDIR);)

$(BUILD)/dos.app: dos.app.s $(ACEHDRS) sys/toolbox.asm
	$(ACME) --cpu 6510 --vicelabels $(BUILD)/dos.sym -f plain -o $(BUILD)/dos.app dos.app.s

$(BUILD)/cpm.app: cpm.app.s $(ACEHDRS) sys/toolbox.asm
	$(ACME) --cpu 6510 --vicelabels $(BUILD)/cpm.sym -f plain -o $(BUILD)/cpm.app cpm.app.s

$(BUILD)/shell.app: shell.app.s $(ACEHDRS) sys/toolbox.asm
	$(ACME) --cpu 6510 --vicelabels $(BUILD)/shell.sym -f plain -o $(BUILD)/shell.app shell.app.s

$(BUILD)/arcade.app: arcade.app.s $(wildcard arcade.app.d/*.asm) $(wildcard arcade.app.d/*.m8x)
	$(ACME) --cpu 6510 --vicelabels $(BUILD)/arcade.sym -f plain -o $(BUILD)/arcade.app -I../cbm arcade.app.s
	@$(foreach f,$(wildcard arcade.app.d/*.lua), cp $(f) $(SYSDIR)/arcade.app.d;)

clean:
	rm -fr $(BUILD)
	rm -fr $(SYSDIR)
	rm -fr resc/boot.prg resc/boot128.prg

install: all
	mkdir -p /usr/share/idun/sys/arcade.app.d
	for item in $(SYSDIR)/*; do \
		[ -f "$$item" ] && install -m 644 -o $(USER) -g $(USER) "$$item" /usr/share/idun/sys/; \
	done
	for item in $(SYSDIR)/arcade.app.d/*; do \
		[ -f "$$item" ] && install -m 644 -o $(USER) -g $(USER) "$$item" /usr/share/idun/sys/arcade.app.d/; \
	done
