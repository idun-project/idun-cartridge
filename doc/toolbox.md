## Toolbox APIs
---

The Toolbox is a small set of reusable ML routines (~4 KiB) that are available alongside the Idun Kernel routines to make it easier to develop text-based tools in assembly language. These tools are launched from Idun Dos, and return the user to Dos when complete. By utilizing the Toolbox, tools can provide a simpler and more consistent user and programming experinece. There are 7 APIs for the following purposes:

1. [user](#tooluser): An API for UI and decorative text
2. [win](#toolwin): An API for defining window areas managed by tools that take over the screen.
3. [stat](#toolstat); An API for using the status bar that appears at the top of the screen when tools are running.
4. [keys](#toolkeys): An API for programming command keys used by the tool.
5. [mmap](#toolmmap): An API for loading data into memory and swapping cached memory with working memory. 
6. [tmo](#tooltmo): An API for setting one-shot timeouts to invoke a callback.
7. [sys](#toolsys): An API for calling System utilities

### toolUser
This API works for console and fullscreen tools. For console tools, it is mainly useful for creating text that stands out against the more mundane console output through the use of colors, lines, or borders. When used for a fullscreen tool, it can also provide "popup" dialogs, menus, or help.

The interface to the user API is designed so it can be data-driven. Therefore, the parameters to each function are embedded in the code, immediately following the `jsr` for the function.

`toolUserLayout/End` enable/disable active UI layout

- param = !byte 2 [layout-flags, width-or-height]
- layout-flags = h|r|o|x|x|x|x|x, where
    + h = horizontal (0=vertical)
    + r = retained (0=not retained)
    + o = overlayed (0=not overlayed)
- width-or-height = number of characters wide or high, depeending on if it is to be layed out vertically or horizontally.

`toolUserNode/End` start/end a text area definition

- param = !byte 3 [refresh-flag,width,height]
- refresh-flag = refresh counter to control redraw during vsync interrupt; only used for retained layout!
- width = width of text area in characters
- height = height of text area in characters

`toolUserGadget`

- param !byte 1 gadget-flags
- gadget-flags = f|s|x|x|x|pen, where
    + f = focus
    + s = select
    + pen = fgrd pen
- param !pet null-terminated gadget text (PETSCII)

`toolUserLabel`

- param !pet null-terminated gadget text (PETSCII)

`toolUserSeparator` outputs a horizontal line used as a separator

The following variables can be set and will be global to the text area (e.g. the "node") within which they are modified.

`toolUserColor` upper nybble is border pen; lower nybble is text pen

`toolUserStyles` = b|a|r|u|f|c|>|<, where
```
    - b = bordered text
    - a = 
    - r = reverse text
    - u = underline text
    - f = 
    - c = center text
    - < = left=align text
    - > = right-align text
```

### toolWin
This API is for tools that take over screen drawing, rather than just outputting to a scrolling console. They are useful for defining screen and active region dimensions, color palette, and character set. The active region can be scrolled vertically, and can be cached and retrieved to support popups.

`toolWinB` defines the variables that can be set.
- toolWinRegion: define rows x cols and top-left
- toolWinScroll: scrolling rows x cols and top-left
- toolWinPalette: colors to use for 8x palette entries

`toolWinRestore` restores the window setup back to the default and should be called at exit by any tool that manipulates the screen window, palette, etc.

### toolStat
This API is for manipulating the top line of the display, which is consistently used as a status bar. A minimum use would be to set a title for an interactive tool, which is displayed at the top left of the screen. Tools can ignore this API and the status bar will continue updating the standard values it displays automatically, such as the time & date.

`toolStatB` defines the variables that can be set.

`toolStatTitle` sets the title string

`toolStatAlert` temporarily replace status line text with alert message

### toolKeys
This API is for deifining the tool's command keys and their handlers.

`toolKeysSet` set up a command key handler

`toolKeysMacro` set up a macro key (up to 32 chars)

`toolKeysRemove` removes a command key and handler

`toolKeysHandler` call this API to check for a command key in the input and handle it.

Any key code can be used by the tool. However, reusing key codes already defined by the user as described below will override the user-defined function. Therefore, most tools should only use key codes outside the range $80-$8f for command keys.

In addition to command keys, up to 16 user-defined function key macro definitions may be creatied by the user with the `funkey` shell command. These user-defined keys are used to inject a macro string (up to 32 chars) any time the key is pressed from within any tool, including in the DOS shell itself.

Only the keycodes $80-$8f may be used with the `funkey` command. This includes F1-F12 codes, plus SH-HELP, SH-RUN, SH-RETURN. The code for CO-1 ($81) is specifically excluded by `funkey` and is available as an application command key instead.

### toolMmap

This API is for mapping files into a blob of extended RAM, such that the file's contents are easily swappable into a working memory buffer. The memory can be retrieved using an assigned "tag" string value, which is typically just the file name, but can also be any chosen symbolic name.

`toolMmapLoad` load contents of file into extended memory

`toolMmapAlloc` allocate blob storage in extended memory

`toolMmapFind` get far addr of memory blob named by tag

`toolMmapFetch` retrieve whole blob into working buffer

`toolMmapStash` store working buffer to backing store blob

`toolMmapRealloc` deallocate and free extended memory, then alloc new blob

Additionally, tagged memory can be treated as a read-only, random-access file, when opened with the device prefix `_:`. Opening a file with this prefix will try to locate the data in extended RAM using `mmapFind`, and will return a file descriptor (Fd) that can be used with the standard file I/O functions - `read`, `seek`, `close`.

### toolTmo

This API provides two functions for setting a countdown timer and invoking a callback function when the timer expires. It is based on the per-frame Irq handler, so the shortest timeout possible is roughly the time of one video frame. For timeouts of a few seconds or shorter, use `toolTmoJifs` to countdown 1-255 "jiffies" (~that many frames). For longer timeouts, use `toolTmoSecs` to countdown 1-255 seconds (allows ~4.25 mins). All timeouts occur only once, and you will need to reset them to trigger another. Also, calling either API will supercede any pending timeout that was counting down before.

`toolTmoJifs` invoke callback routine after 1-255 "jiffies"

`toolTmoSecs` invoke callback routine after 1-255 seconds

### toolSys

This API allows the tool to call other system tools by executing a subprocess with arguments.

`toolSyscall` invoke a subprocess
