APPS=\
hello.app\
sieve.app\
mandelbrot.app\
cube.app

all: $(APPS)

hello.app: hello.asm hello.app.d/app.asm ../cbm/toolx/*/*
	acme --cpu 6510 -f plain -o hello.app -I../cbm hello.asm

sieve.app: sieve.asm sieve.app.d/app.asm ../cbm/toolx/*/*
	acme --cpu 6510 -f plain -o sieve.app -I../cbm sieve.asm

mandelbrot.app: mandelbrot.asm mandelbrot.app.d/app.asm ../cbm/toolx/*/*
	acme --cpu 6510 -f plain -o mandelbrot.app -I../cbm mandelbrot.asm

cube.app: cube.asm cube.app.d/app.asm ../cbm/toolx/*/*
	acme --cpu 6510 -f plain -o cube.app -I../cbm cube.asm

clean:
	rm $(APPS)