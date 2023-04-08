## Idun to Lua Interface
---

### Introduction

Idun provides several methods by which Lua code running on the Raspberry Pi can provide coprocessing functionality to idun tools and applications. First, let's describe the three basic ways of integrating Lua code, from simplest to most complicated:

1. Write a Lua script and execute it in a tty from the idun-shell.

This is by far the easiest way to add applications written in Lua. The idun-shell has a `lua` command that will accept the name of a Lua script and launch it in a terminal. So, a simple text program written in Lua and using the Lua `print()` function would just work. To see this in action, switch to the `idun-base/apps` (usually mapped to `e:`) directory and type `lua sieve.lua`. The script is a generic thing that spits out prime numbers up to 10000. It only uses `print()` for output.

To do a more interactive program that requires user input, you simply switch the Lua stdio to use the [minisock](#mini-socket) API described below. Now, every character typed or printed is available on both the Lua and C128 side. To see an example of a script that works this way, simply type `help` or press `F1` in the shell. The help system is implemented as a [Lua script](../cbm/resc/help.lua).

2. Write a Lua "server" that handles requests from your idun "client" application.

Included with Idun is an [idun-handler](#idun-handler) Lua object that makes it easy to create client/server applications where Lua does the "heavy lifting". For example, the `sidplay` command relies on a helpful [Lua server](../cbm/resc/sidplay.lua) to pre-process the SID files. 

3. Write a "native" idun application in a combination of Lua and 6502 assembler.

Finally, Idun supports creating application in Lua in which the C128 is mainly the front-end for rendering graphics, playing sound, and receiving user inputs. In theory, all of the application logic and data processing can be done in Lua. 

To communicate, messages are passed to the C128 using a "mailbox" interface, and these messages can be of arbitrary size and content. Even streaming data as fast as the C128 can handle it is possible. Likewise, there is an "event" interface that allows asynchronous events, like user input, to be forwarded to the Lua script. The two best, though simple, examples of this are e:mandelbrot.app and e:cube.app. These Lua/6502 assembler hybrid apps will even work in the idun-vice emulator.

Of course, complicated rendering like drawing polygons on the VDC hi-res display, and complicated input like using the mouse, needs support on the C128 side. This is the role of the [m8 ("mate") API](#m8-api) and [m8x ("mate extensions")](#m8x-extensions).

### mini socket

Under the hood of the Lua interface is a dedicated local socket connection that passes the data stream between the C128 and your script. The `minisock` is actually a standard Lua way to talk to a socket, and it is augmented by a second Lua object `redirect`.

In the simplest case, the normal way of outputting text to `stdout` and inputting text from `stdin` is modified as so:

- Instead of `print(str)` or `io.write(str)`, you use `minisock.write(redirect.stdout, str)`.
- Instead of `io.read()`, you use `key = minisock.read(redirect.stdin, 10000)`. The number is a timeout value given in milliseconds; so, 10 seconds for this example. This is just the maximum time you want your script to block waiting on a keystroke from the user. It can be 0 ms to make it non-blocking, or a very big number if you want to block "forever". More practically, place it in a loop that polls for other things or does other work.

Minisock can of course be used in a more structured way, such as for passing pre-defined requests and responses between assembler and Lua code. This is where idun-handler provides a helpful and simple solution.

### idun handler

The handler is included, so you can just `require("idun-handler")` in your script. Then, you implement a function to handle the requests that your assembler code will send to Lua. In [sidplay.lua](../cbm/resc/sidplay.lua), for example, the `handleRequest(req)` function supports 2 types of requests using this simple bit of Lua script:

```
	-- Allowed requests: "H"=get sid header, "P"=get sid program
	if req == "H" then
		return sidhdr
	elseif req == "P" then
		-- Prepend with the size
		local resp = string.pack("<H", #sidprg)
		return resp .. sidprg
	else
		return nil, 3  	-- Bad request
	end
```
Since this isn't the Web, you don't need fancy long names. An "H" request and a "P" request are sufficient, and these are sent as two-byte messages from the C128 ("H\n" or "P\n"). So, 8-bit efficiency is maintained.

Likewise, the response to the "P" request is many kilobytes of SID tune data. However, the assembler side just has to copy all that data to RAM as fast as it can read it from the cartridge port.

### m8 API

The m8 (say "Mate") API is what allows code written in Lua to run on the Raspberry Pi's processor, but call into 8-bit machine code that's running on the 6502 CPU in your Commodore 128. It's akin to "old school" programming on the Commodore using BASIC to call machine language routines, except the high-level script is Lua and runs on a powerful ARM coprocessor. To use m8, just add a line like `local m8 = require("m8api")` to your Lua program.

#### Low-level m8 functions

All of the functionality in m8 is ultimately based on just two low-level functions:

```
1. m8.load({6502_ml_code}, load_addr, [start_addr])
2. m8.intr({6502_ml_code})
```

The `m8.load` function takes some ml code written for the 6502, and quickly loads it into the Commodore at the memory location specified by `load_addr`. An optional `start_addr`, if provided, causes a `jmp` to that address as soon as the code has been loaded. The size of the 6502_code blob that is downloaded to the Commodore is only limited by the RAM available to the 6502.

The `m8.intr` function is used to invoke some inline ml code, which might be as simple as a `jsr` call to a subroutine in the Commodore memory. Such a subroutine may be a user routine loaded via `m8.load`, a routine in a running application or tool, an Idun Kernel routine, or even a  routine in Commodore ROM.

Since the 6502_code that is provided to `m8.intr` may be _up to 512 bytes_, it can be much more complex than just calling a subroutine. Another common use-case would be to treat it as a traditional interrupt handler such that Lua code can both trigger a Commodore interrupt, and provide the handler to run in response, through a simple call to `m8.intr`.

#### High-level m8 functions

__UNDER CONSTRUCTION__

`m8.mailbox` is the standard API for message passing from Lua to assembler.

`m8.waitevent` is the standard API for receiving input events from assembler in Lua.

`m8.writeln` is for outputting lines of text to the display for a full-screen Lua application. For console applications in Lua, you can just use [minisock](#minisock) or the Lua `print()` function.

`m8.file.load_prg` is for loading/starting a native program from a Lua script.

### m8x extensions

m8x ("mate extensions") is the standard way to add application-dependent functionality to Lua apps. These extensions become part of the callable code in the m8 namespace created by the applications. So, it allows new functionality to be invoked on the assembler side. For an example, see: [cube.app.d](../samples/cube.app.d/) and [mandelbrot.app.d](../samples/mandelbrot.app.d/).

### System (sys.) functions

__UNDER CONSTRUCTION__

### User (usr.) functions

__UNDER CONSTRUCTION__
