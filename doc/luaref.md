## Idun to Lua Interface
---

### Introduction

Idun provides several methods by which Lua code running on the Raspberry Pi can provide coprocessing functionality to idun tools and applications. First, let's describe the three basic ways of integrating Lua code, from simplest to most complicated:

* Write a Lua script and execute it in a tty from the idun-shell.

This is by far the easiest way to add applications written in Lua. The idun-shell has a `mlua` command that will accept the name of a Lua script and launch it in a terminal. So, a simple text program written in Lua and using the Lua `print()` function would just work. To see this in action, switch to the `idun-base/apps` (usually mapped to `e:`) directory and type `mlua sieve.lua`. The script is a generic thing that spits out prime numbers up to 10000. It only uses `print()` for output.

To do a more interactive program that requires user input, you simply switch the Lua stdio to use the [minisock](#mini-socket) API described below. Now, every character typed or printed is available on both the Lua and Commodore side. To see an example of a script that works this way, simply type `help` or press `F1` in the shell. The help system is implemented as a [Lua script](https://github.com/idun-project/idun-cartridge/blob/main/cbm/resc/help.lua).

* Write an Idun tool that calls a Lua module.

It is quite easy to create a tool for Idun in which much of the functionality is contained in a Lua module that runs on the cartridge with full access to its modern Linux environment. For example, the `sidplay` command relies on a helpful [Lua module](https://github.com/idun-project/idun-cartridge/blob/main/cbm/resc/sidplay.lua) to pre-process the SID files. The Lua functions inside the module can be called from assembly language using the `usrcall` API, including passing parameters into Lua from assembly. Likewise, data can be returned from the Lua function and accessed in assembly using the `maprecv` API. For more information on using this method, refer to [Lua "usr" modules](#lua-usr-modules).

* Write a Idun application in a combination of Lua and 6502 assembler.

Finally, Idun supports creating applications in Lua in which the Commodore is mainly the front-end for rendering graphics, playing sound, and receiving user inputs. In theory, all of the application logic and data processing can be done in Lua. 

To communicate, messages are passed asynchronously to the Commodore using a "mailbox" interface, and these messages can be of arbitrary size and content. Likewise, there is an "event" interface that allows asynchronous events, like keyboard or joystick input, to be sent to the Lua program. The two best, though simple, examples of this are e:mandelbrot.app and e:cube.app. These Lua/6502 assembler hybrid apps will even work in the idun-vice emulator.

Of course, complicated rendering like drawing polygons on the VDC hi-res display, and complicated input like using the mouse, needs support on the Commodore side. This is the role of the [m8 ("mate") API](#m8-api) and [m8x ("mate extensions")](#m8x-extensions).

### mini socket

Under the hood of the Lua interface is a dedicated local socket connection that passes the data stream between the Commodore and your Lua program. The `minisock` is actually a standard Lua way to talk to a socket, and it is augmented by a second Lua object `redirect`.

In the simplest case, the normal way of outputting text to `stdout` and inputting text from `stdin` is modified as so:

- Instead of `print(str)` or `io.write(str)`, you use `minisock.write(redirect.stdout, str)`.
- Instead of `io.read()`, you use `key = minisock.read(redirect.stdin, 10000)`. The number is a timeout value given in milliseconds; so, 10 seconds for this example. This is just the maximum time you want your script to block waiting on a keystroke from the user. It can be 0 ms to make it non-blocking, or a very big number if you want to block "forever". More practically, place it in a loop that polls for other things or does other work.

Minisock can of course be used in a more structured way, such as for passing pre-defined requests and responses between assembler and Lua code.

### m8 API

The m8 (say "Mate") API is what allows code written in Lua to run on the Raspberry Pi's processor, but call into 8-bit machine code that's running on the 6502 CPU in your Commodore. It's akin to "old school" programming on the Commodore using BASIC to call machine language routines, except the high-level script is Lua and runs on a powerful ARM coprocessor. To use m8, just add a line like `local m8 = require("m8api")` to your Lua program.

#### Low-level m8 functions

All of the functionality in m8 is ultimately based on a couple low-level functions:

1. m8.intr({6502_ml_code})
2. m8.

The `m8.load` function takes some ml code written for the 6502, and quickly loads it into the Commodore at the memory location specified by `load_addr`. An optional `start_addr`, if provided, causes a `jmp` to that address as soon as the code has been loaded. The size of the 6502_code blob that is downloaded to the Commodore is only limited by the RAM available to the 6502.

The `m8.intr` function is used to invoke some inline ml code, which might be as simple as a `jsr` call to a subroutine in the Commodore memory. Such a subroutine may be a user routine loaded via `m8.load`, a routine in a running application or tool, an Idun Kernel routine, or even a  routine in Commodore ROM.

Since the 6502_code that is provided to `m8.intr` may be _up to 512 bytes_, it can be much more complex than just calling a subroutine. Another common use-case would be to treat it as a traditional interrupt handler such that Lua code can both trigger a Commodore interrupt, and provide the handler to run in response, through a simple call to `m8.intr`.

#### High-level m8 functions

__UNDER CONSTRUCTION__

`m8.mailbox` is the standard API for message passing from Lua to assembler.

`m8.waitevent` is the standard API for receiving input events from assembler in Lua.

`m8.writeln` is for outputting lines of text to the display for a full-screen Lua application. For console applications in Lua, you can just use minisock or the Lua `print()` function.

`m8.file.load_prg` is for loading/starting a native program from a Lua script.

### m8x extensions

m8x ("mate extensions") is the standard way to add application-dependent functionality to Lua apps. These extensions become part of the callable code in the m8 namespace created by the applications. So, it allows new functionality to be invoked on the assembler side. For an example, see: [cube.app.d](https://github.com/idun-project/idun-cartridge/blob/main/samples/cube.app.d/) and [mandelbrot.app.d](https://github.com/idun-project/idun-cartridge/blob/main/samples/mandelbrot.app.d/).

### Lua sys module

This module is builtin to the cartridge Lua environment and contains many functions. The functions can be utilized in 3 ways:

1. called from within your Lua programs
2. passed as "one-shot" commands from Linux programs using a local messaging socket
3. called from assembly programs using the `syscall` API

These are the available functions with description.

- `sys.loader(load_type)` Load a native program on Commodore by invoking an extension ROM file loader and launcher.
- `sys.chdir(dir_name)` Set the Idun device/directory
- `sys.shell(cmd, args)` Command the shell.app to run an internal command, or launch and Idun or native program.
- `sys.stop()` Injects a STOP key event; can be used to terminate running Idun programs that monitor STOP.
- `sys.reboot(mode)` Reboot Idun cart with specified mode (C64/C128),
- `sys.kvm_on()` Enable the Idun internal KVM; now keyboard and mouse will directly control Linux. Disable with `C=+k`.

For use from assembly with `syscall`, not all of the functions are available. It is limited to:

1. `sys.loader()` - with MAP_SYS_LOAD_BINARY command
2. `sys.reboot()` - with MAP_SYS_REBOOT command
3. `sys.kvm_on()` - with MAP_SYS_KVM_SWITCH command

### Lua usr modules

As is described above, a Idun tool written in assembly language can make use of a "companion" Lua module. The functions of the module are invoked from assembly using `usrcall` and the function return values can be read using `maprecv`.

Your module must be written in the standard Lua way, which means the final statement in your script should be `return <module>`. The module is a Lua table that includes some functions that you wish to use from your assembly code. Other local functions may be present in your script, but only those that are part of the module table will be available directly via `usrcall`.

You must name your Lua module the same as your tool. So, a tool called "foo" would have file "foo.asm" and "foo.lua". Specifying  function id #0 to `usrcall` instructs it to load your module as the new "usr" module visible to Lua. So, this must be done prior to calling any of the functions. The functions can then be called by id #1..n, where the id is just the position of the function in an alphabetically sorted list of the available function names.

Complex parameters and return values are supported by `usrcall`. These are byte-packed so as to make it very efficient for assembly language and very easy to deal with in Lua- just using the `string.pack()` and `string.unpack()` Lua functions. For both input parameter and results, a size prefix is automatically prepended by the API. This means that, on the Lua side, your function accepts a single parameter that is processed using `params = string.unpack("s2", packed)`. Once the size prefix is peeled off, you can make further calls to `string.unpack` on the `params` string to parse out whatever parameters your function requires. Return values work similarly, and use two builtin helper functions- `m8.ret()` and `m8.err()`.

To return an error value from Lua, simply use `m8.err(error_code)`. This will wind up as the assembly code `errno` variable when you use `mapstat` to check the status of your Lua call. To send complex return values from your function, pack the values into a string using the `string.pack()` function, then pass with `m8.ret(packed)`. This will be the data you read on the assembly side using `maprecv`. Naturally, you must pay close attention to how your packed data is formatted so you can process its internal values in the byte stream you will receive on the assembly side.
