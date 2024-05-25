APPS=\
hello.app\
sieve.app\
mandelbrot.app\
cube.app
ACME=acme --dialect 0.94.12

all: $(APPS) plasma

hello.app: hello.asm hello.app.d/app.asm ../cbm/toolx/*/*
	$(ACME) --cpu 6510 -f plain -o hello.app -I../cbm hello.asm

sieve.app: sieve.asm sieve.app.d/app.asm ../cbm/toolx/*/*
	$(ACME) --cpu 6510 -f plain -o sieve.app -I../cbm sieve.asm

mandelbrot.app: mandelbrot.asm mandelbrot.app.d/app.asm ../cbm/toolx/*/*
	$(ACME) --cpu 6510 -f plain -o mandelbrot.app -I../cbm mandelbrot.asm

cube.app: cube.asm cube.app.d/app.asm ../cbm/toolx/*/*
	$(ACME) --cpu 6510 -f plain -o cube.app -I../cbm cube.asm

plasma: plasma.asm
	$(ACME) --cpu 6510 plasma.asm
	
clean:
	rm $(APPS) plasma