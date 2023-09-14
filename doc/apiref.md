## Idun/ACE-128 PROGRAMMER'S REFERENCE GUIDE (v1.0)

### by Craig Bruce 09-Feb-1997. Revised for Idun 30-Mar-2023.
------------------------------------------------------------------

   * [Introduction](#introduction-original-by-c-bruce)
   * [Reference](#reference-updated-for-idun)
      * [SYSTEM VARIABLES AND CONSTANTS](#system-variables-and-constants)
         * [1. ZERO-PAGE VARIABLES](#1-zero-page-variables)
         * [2. SYSTEM VARIABLES](#2-system-variables)
         * [3. SYSTEM CONSTANTS](#3-system-constants)
      * [SYSTEM CALLS](#system-calls)
         * [1. FILE CALLS](#1-file-calls)
         * [2. DIRECTORY CALLS](#2-directory-calls)
         * [3. SCREEN-CONTROL CALLS](#3-screen-control-calls)
         * [4. CONSOLE CALLS](#4-console-calls)
         * [5. GRAPHICS CALLS](#5-graphics-calls)
         * [6. PROCESS-CONTROL CALLS](#6-process-control-calls)
         * [7. MEMORY CALLS](#7-memory-calls)
         * [8. TIME CALLS](#8-time-calls)
         * [9. TTY ACCESS CALLS](#9-tty-access-calls)
         * [10. TAGGED MEMORY AND MEMORY-FILE CALLS](#10-tagged-memory-and-memory-file-calls)
         * [11. MISCELLANEOUS CALLS](#11-miscellaneous-calls)
         * [12. IOCTL CALLS](#12-ioctl-calls)
      * [USER-PROGRAM ORGANIZATION](#user-program-organization)

## Introduction

The core of the Idun software is comprised of a kernel, device drivers, command-line shell, and application API originally written by Craig Bruce in 1992-1997, and modified for Idun 30 years later. While the original shell was inspired by Unix, the one included with Idun is intended to be reminiscent of MS-DOS. The kernel and device drivers have been modified to work with the idun-cartridge, and many additions have been made to the API. This document covers the API. This API is used by all the tools that are included with and run within the idun-shell [(see: dos.app.s)](../cbm/dos.app.s). Perhaps, the best way to learn the API is to look at the assembly language source code for the tools [(see: cbm/cmd/)](../cbm/cmd/), and consult the reference below for better understanding.

## Reference

### SYSTEM VARIABLES AND CONSTANTS

 This section describes the interface between user programs and the Idun kernel.  I am very careful throughout this interface specification about revealing any internal details that you do not strictly need to know.  The interface with Idun is not specified in terms of absolute addresses; to aid in portability and extensibility, all interfaces are specified in terms of symbolic assembler labels.  All of the Idun code is currently written for the ACME assembler. Also, because these interface absolute addresses are subject to change from version to version of the kernel, executables compiled for use with an old version of Idun may not work with a new version.

#### 1. ZERO-PAGE VARIABLES

There are four zero-page variables used for passing arguments in most system calls.  They are as follows:
```
SYMBOL   BYTES   DESCRIPTION
-------  -----   -----------
zp           2   zeropage pointer
zw           2   zeropage word
mp           4   memory pointer
syswork     16   system work area / arguments
```
The first two, "zp" and "zw" are used in many calls.  They store simple 16-bit values; "zp" usually stores pointers to strings in application memory.  The "mp" variable is 32-bits in length and is used exclusively for passing far memory pointers for use with the far memory routines.  All three of these variables will remain unchanged inside of system call unless they will contain a return value.  "syswork" is a 16-byte array used mainly when there are too many arguments for other variables to hold, and all non-input and non-output bytes of "syswork" are subject to change by the kernel.  All input arguments placed in the "syswork" locations will be preserved unless otherwise indicated.

#### 2. SYSTEM VARIABLES

There are several non-zeropage variables for storing system status and return values:
```
SYMBOL          BYTES   DESCRIPTION
----------      -----   -----------
errno               1   error number code returned by failed system calls
aceArgc             2   argument count for current process
aceArgv             2   argument vector address for current process
aceMemTop           2   highest address, plus one, that user prog can use
aceDirentBuffer <next>  storage for directory entries read from disk
aceDirentLength     -   really a constant: length in bytes of "aceDirentBuffer"
aceDirentBytes      4   bytes in file (usually inexact)
aceDirentDate       8   date of file in "YY:YY:MM:DD:HH:MM:SS:TW" format
aceDirentType       4   type of file in null-terminated string
aceDirentFlags      1   flags of file, "drwx*-et" format
aceDirentUsage      1   more flags of file, "ulshm---" format
aceDirentNameLen    1   length of name of file
aceDirentName      17   null-terminated name of file
aceExitData       256   storage for exit status from the last called prg
aceMouseLimitX      2
aceMouseLimitY      2
aceMouseScaleX      1
aceMouseScaleY      2
```
ERRNO: "errno" is used to return error codes from system calls.  When a system call ends in error, it sets the carry flag to "1", puts the error code in "errno", and returns to the user program, after undoing any system work completed at the time the error is encountered and aborting the operation.  An error code number is stored in binary in the single-byte
"errno" location. The symbolic names for the possible error codes are given in the next section. If no error occurs in a system call, the carry flag will be cleared on return from the call.  Note that not all system calls can run into errors, so not all set the carry flag accordingly.

ARGC: "aceArgc" is a two-byte unsigned number.  It gives the number of arguments passed to the application by the program (usually the command shell) that called the application.  The first argument is always the name of the application program, so the count will always be at least one.  Other arguments are optional.

ARGV: "aceArgv" is a two-byte RAM0 pointer.  Pay attention.  This pointer points to the first entry of an array of two-byte pointers which point to the null-terminated strings that are the arguments passed to the application program by the caller.  (A null-terminated string is one that ends with a zero byte).  To find the address of the N-th argument to an application, multiply N by two, add the "aceArgv" contents to that, and fetch the pointer from that address.  In this scheme, the ever-present application name is the 0-th argument.  The argv[argc] element of the argument vector will always contain a value of $0000, a null pointer.

MEM-TOP: "aceMemTop" is a two-byte RAM0 pointer.  This points to one byte past the highest byte that the application program is allowed to use.  All application programs are loaded into memory at address "aceToolAddress" (next section), and all memory between the end of the progam code and "aceMemTop" can be used for temporary variables, file buffers, etc.  The main problem with this approach is that there are no guarantees about how much memory your application will get to play with.  Many applications, such as simple file utilities, can simply use all available memory for a file buffer, but other programs, such as a file compressor, may have much greater demand for
"near" memory.

DIRENT-BUFFER: "aceDirentBuffer" is a buffer used for storing directory information read with the "dirread" system call, and is "aceDirentLength" bytes long.  Only a single directory entry is (logically) read from disk at a time.  The individual fields of a read directory entry are accessed by the fields described next.  This field is also used for returning disk name information and the number of bytes free on a disk drive (see the "dirread" system call).

DIRENT-BYTES: "aceDirentBytes" is a four-byte (32-bit) unsigned field.  As always, the bytes are addressed from least significant to most significant. This field gives the number of bytes in the file.  Note that this value may not be exact, since Commodore decided to store sizes in disk blocks rather than bytes.  For devices that report only block counts (i.e., every disk device currently supported), the number of bytes returned is the number of blocks multiplied by 254.  This field, as well and the other dirent fields are absolute addresses, not offsets from aceDirentBuffer.

DIRENT-DATE: "aceDirentDate" is an eight-byte array of binary coded decimal values, stored from most significant digits to least significant.  The first byte contains the BCD century, the second the year, and so on, and the last byte contains the number of tenths of seconds in its most significant nybble and a code for the day-of-week in its least significant nybble.  Sunday has code 0, Monday 1, etc., Saturday 6, and a code of 7 means "unknown".  This is the standard format for all dates used in ACE.  This format is abstracted as "YY:YY:MM:DD:HH:MM:SS:TW".  For disk devices that don't support dates, this field will be set to all zeroes.

DIRENT-TYPE: "aceDirentType" is a three-character (four-byte) null- terminated string.  It indicates what type the file is, in lowercase PETSCII.  Standard types such as "SEQ" and "PRG" will be returned, as well and other possibilities for custom device drivers.

DIRENT-FLAGS: "aceDirentFlags" is a one-byte field that is interpreted as consisting of eight independent one-bit fields.  The abstract view of the fields is "drwx*-et".  "d" means that the item is a subdirectory (otherwise it is a regular file), "r" means the item is readable, "w" means the item is writable, and "x" means the item is executable.  The "x" option is really not supported currently.  "*" means the item is improperly closed (a "splat" file in Commodore-DOS terminology).  The "-" field is currently undefined.
"e" means that the value given in the "aceDirentBytes" field is actually exact, and "t" means the file should be interpreted as being a "text" file
(otherwise, its type is either binary or unknown).  The bit fields are all booleans; a value of "1" means true, "0", false.  The "d" bit occupies the 128-bit position, etc.

DIRENT-USAGE: "aceDirentFlags" is a one-byte field very much like
"aceDirentFlags".  The abstract view of the fields is "ulshm---".  "u" indicates whether the directory entry is used (current) or not (deleted). The directory system calls will not read a directory entry that is deleted, so you will never see this bit not set; it is used internally.  "l" indicates whether the directory entry is for an actual file (==0, normal) or a "link" (==1) to another file.  The "s" and "h" bits indicate which type a link is:  "soft" or "hard", respectively.  These both work similarly to Unix hard and soft links.  The "m" flag indicates whether a file has been modified since the last time that a backup program cleared the "m" bit for the file, allowing incremental backups.

DIRENT-NAME-LEN: "aceDirentNameLen" is a one-byte number.  It gives the number of characters in the filename.  It is present for convenience.

DIRENT-NAME: "aceDirentName" is a 16-character (17-byte) null-terminated character string field.  It gives the name of the file or directory or disk.  Filenames used with Idun are limited to 16 characters.

 EXIT-DATA: "aceExitData" is a 256-byte array.  It is the 256-byte buffer allocated for user programs to give detailed return information upon exiting back to their parent program.  See the "exit" system call.  User programs are allowed to read and write this storage.  An example use of this feature would be a compiler program returning the line number and character position, and description of a compilation error to a text editor, so the editor can position the cursor and display the error message for user convenience.  The implementation of this feature may need to change in future versions of ACE.

#### 3. SYSTEM CONSTANTS

There are several symbolic constants that are used with the Idun system interface:
```
SYMBOL                   DESCRIPTION
-------------------      -------------------------
aceToolAddress           the start address of tools that run from the shell
aceID1                   the id characters used to identify Idun applications
aceID2                   ...
aceID3                   ...
aceMemNull               the far memory type code used to indicate null ptrs
aceMemREU                far mem type code for Ram Expansion Unit memory
aceMemTagged             far mem type code for tagged RAM memory
aceMemInternal           far mem type code for internal memory
aceErrStopped            error code for syscall aborted by STOP key
aceErrTooManyFiles       err: too many files already opened to open another
aceErrFileOpen           err: don't know what this means
aceErrFileNotOpen        err: the given file descriptor is not actually open
aceErrFileNotFound       err: named file to open for reading does not exist
aceErrDeviceNotPresent   err: the specified physical device is not online
aceErrFileNotInput       err: file cannot be opened for reading
aceErrFileNotOutput      err: file cannot be opened for writing
aceErrMissingFilename    err: pathname component is the null string
aceErrIllegalDevice      err: the specified device cannot do what you want
aceErrWriteProtect       err: trying to write to a disk that is write-protected
aceErrFileExists         err: trying to open for writing file that exists
aceErrFileTypeMismatch   err: you specified the file type incorrectly
aceErrNoChannel          err: too many open files on disk drive to open another
aceErrInsufficientMemory err: Idun could not allocate the memory you requested
aceErrOpenDirectory      err: you are trying to open a dir as if it were a file
aceErrDiskOnlyOperation  err: trying to perform disk-only op on char device
aceErrNullPointer        err: trying to dereference a null far pointer
aceErrInvalidFreeParms   err: bad call to "aceMemFree": misaligned/wrong size
aceErrFreeNotOwned       err: trying to free far memory you don't own
aceErrInvalidWindowParms err: invalid window dimensions were given
aceErrInvalidConParms    err: invalid console parameters were given
aceErrInvalidFileMode    err: opening a file for other-than "r","w", or "a"
aceErrNotImplemented     err: system call or option is not (yet) implemented
aceErrBloadTruncated     err: a bload operation stopped before exceeding limit
aceErrPermissionDenied   err: attempt to read or write a file without perms
aceErrNoGraphicsSpace    err: graphics area is not available for operation
aceErrBadProgFormat      err: specified program file has wrong format
chrBEL                   character code: bell
chrTAB                   character code: tab
chrBOL                   character code: beginning of line (return)
chrCR                    character code: carriage return (newline)
chrVT                    character code: vertical tab (down, linefeed)
chrBS                    character code: backspace (del)
chrCLS                   character code: clear screen (form feed)
chrBUL                   character code: bullet
chrVL                    character code: v_line
chrHL                    character code: h_line
chrCRS                   character code: cross
chrTL                    character code: tl_corner
chrTR                    character code: tr_corner
chrBL                    character code: bl_corner
chrBR                    character code: br_corner
chrLT                    character code: l_tee
chrRT                    character code: r_tee
chrTT                    character code: t_tee
chrBT                    character code: b_tee
chrHRT                   character code: heart
chrDIA                   character code: diamond
chrCLU                   character code: club
chrSPA                   character code: spade
chrSCI                   character code: s_circle
chrOCI                   character code: circle
chrLBS                   character code: pound
chrCHK                   character code: CLS/check
chrPI                    character code: pi
chrPM                    character code: +/-
chrDIV                   character code: divide
chrDEG                   character code: degree
chrCHE1                  character code: c_checker
chrCHE2                  character code: f_checker
chrSOL                   character code: solid_sq
chrCRE                   character code: cr_char
chrUP                    character code: up_arrow
chrDWN                   character code: down_arro
chrLA                    character code: left_arro
chrRA                    character code: right_arr
stdin                    file descriptor reserved for stdin input stream
stdout                   file descriptor reserved for stdout output stream
stderr                   file descriptor reserved for stderr output stream
```
"aceToolAddress", as discussed before, is the address that application programs are loaded into memory at.  They must, of course, be assembled to execute starting at this address.

The "aceMem" group of constants are for use with the "aceMemAlloc" system call, except for "aceMemNull", which may be used by application programs for indicating null far pointers.  The "aceMemAlloc" call allows you to specify what types of memory you are willing to accept.  This is important because the difference types of memory have different performance characteristics. Idun will try to give you the fastest memory that is available.  Ram Expansion Unit memory has startup and byte-transfer times of about 60 us (microseconds) and 1 us, respectively.  This is the fastest type of far memory.  Internal memory has a startup time of 24 us and a byte-transfer time of between 7 and 14 us (depending on whether accessing RAM0 or RAM1+).

The "aceErr" group gives the error codes returned by system calls.  The error codes are returned in the "errno" variable.  Not all possible error codes from Commodore disk drives are covered, but the important ones are. The "chr" group gives the character codes that have special control functions when printed using the "write" system call (below).

Finally, the "std" files group give the symbolic file descriptor identifiers of the default input, output, and error output file streams.

### SYSTEM CALLS

All system calls are called by setting up arguments in specified processor registers and memory locations, executing a JSR to the system call address, and pulling the return values out of processor registers and memory locations.

#### 1. FILE CALLS

```
NAME   :  open
PURPOSE:  open a file
ARGS   :  (zp) = pathname
          .A   = file mode ("r", "w", "a", "W", or "A")
RETURNS:  .A   = file descriptor number
          .CS  = error occurred flag
ALTERS :  .X, .Y, errno
```
Opens a file.  The name of the file is given by a pointer to a null-terminated string, and may contain device names and pathnames.  The file mode is a PETSCII character.  "r" means to open the file for reading, "w" means to open the file for writing, and "a" means to open the file for appending (writing, starting at the end of the file).  An error will be returned if you attempt to open for reading or appending a file that does not exist, or if you attempt to open for writing a file that does already exist.  On the other hand, calling with the capital letters "W" and "A" mean to force a write or append if needed, if the file either already exists or does not already exist, respectively.

The function returns a file descriptor number, which is a small unsigned integer that is used with other file calls to specify the file that has been opened.  File descriptors numbered 0, 1, and 2 are used for stdin, stdout, and stderr, respectively.  The file descriptor returned will be the minimum number that is not currently in use.  These numbers are system-wide (rather than local to a process as in Unix), and this has some implications for I/O redirection (see the "aceFileFdswap" call below).

Restrictions: only so many Kernal files allowed to be open on a disk device, and there is a system maximum of open files.  You will get a "too many files" error if you ever exceed this limit.  Also, because of the nature of Commodore-DOS, there may be even tighter restrictions on the number of files that can be simultaneously open on a single disk device, resulting in a "no channel" error.  Note that this call checks the status channel of Commodore disk drives on each open, so you don't have to (and should not anyway).

If the current program exits either by calling "exit" or simply by doing the last RTS, all files that were opened by the program and are still open will be automatically closed by the system before returning to the parent program.

```
NAME   :  close
PURPOSE:  close an open file
ARGS   :  .A   = File descriptor number
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

Closes an open file.  Not much to say about this one.
```
NAME   :  read
PURPOSE:  read data from an open file
ARGS   :  .X   = File descriptor number
          (zp) = pointer to buffer to store data into
          .AY  = maximum number of bytes to read
RETURNS:  .AY  = (zw) = number of bytes actually read in
          .CS  = error occurred flag
          .ZS  = EOF reached flag
ALTERS :  .X, errno
```

Reads data from the current position of an open file.  Up to the specified maximum number of bytes will be read.  You should not give a maximum of zero bytes, or you may misinterpret an EOF (end of file).  The buffer must be at least the size of the maximum number of bytes to read.  The data are not interpreted in any way, so it is the programmer's responsibility to search for carriage return characters to locate lines of input, if he so desires. However, for the console the input is naturally divided up into lines, so each call will return an entire line of bytes if the buffer is large enough.  There are no guarantees about the number of bytes that will be returned, except that it will be between 1 and the buffer size.  So, if you wish to read a certain number of bytes, you may have to make multiple read calls.

The call returns the number of bytes read in both the .AY register pair and in (zw), for added convenience.  A return of zero bytes read means that the end of the file has been reached.  An attempt to read beyond the end of file will simply give another EOF return.  End of file is also returned in the .Z flag of the processor.

```
NAME   :  write
PURPOSE:  write data to an open file
ARGS   :  .X   = file descriptor number
          (zp) = pointer to data to be written
          .AY  = length of data to be written in bytes
RETURNS:  .CS  = error occurred
ALTERS :  .A, .X, .Y, errno
```

Writes data at the current position of an open file.  For writing to the console device (where many text files will end up being displayed eventually), the following special control characters are interpreted:
```
CODE(hex)   CODE(dec)   NAME   DESCRIPTION
---------   ---------   ----   -----------
$07         7           BEL    ring the bell
$09         9           TAB    move cursor to next 8-char tab stop
$0a         10          BOL    move cursor to beginning of current line
$0d         13          CR     go to start of next line (newline)
$11         17          VT     go down one line (linefeed)
$14         20          BS     non-destructive backspace
$93         147         CLS    clear the screen and home the cursor
```
```
NAME   :  seek
PURPOSE:  seek to the given file position
ARGS   :  .X   = file descriptor number
          .AY  = new position
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

Seeks to the given file position. Seek call will only work with special device drivers which are actually designed to randomly access files, such as memory-mapped files. see: [toolMmapLoad](toolbox.md#toolmmap) in [toolbox.md](toolbox.md).

```
NAME   :  aceFileBload
PURPOSE:  binary load
ARGS   :  (zp) = pathname
          .AY  = address to load file
          (zw) = highest address that file may occupy, plus one
RETURNS:  .AY  = end address of load, plus one
          .CS  = error occurred flag
ALTERS :  .X, errno
```

Binary-load a file directly into memory.  If the file will not fit into the specified space, an error will be returned and the load truncated if the device supports truncation; otherwise, important data may be overwritten.

```
NAME   :  aceFileRemove
PURPOSE:  delete a file
ARGS   :  (zp) = pathname
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

Delete the named file.

```
NAME   :  aceFileRename
PURPOSE:  rename a file or directory
ARGS   :  (zp) = old filename
          (zw) = new filename
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

Renames a file or directory.  If a file with the new name already exists, then the operation will be aborted and a "file exists" error will be returned.  On most devices, the file to be renamed must be in the current directory and the new name may not include any path, just a filename.

```
NAME   :  aceFileInfo **DEPRECATED use aceMiscDeviceInfo
PURPOSE:  give information about file/device
ARGS   :  .X   = file descriptor number
          .A   = info-type flags ($00 for these returns,$01=ready,$02=dirinfo)
RETURNS:  .A   = device type code (0=console, 1=char-dev, 2=disk-dev)
          .X   = number of columns on device
          .Y   = number of rows per "page" of device
          .CS  = error occurred flag
ALTERS :  errno
```

```
NAME   :  aceFileIoctl
PURPOSE:  perform special io-device control operations
ARGS   :  .X   = file descriptor number
          .A   = flags
RETURNS:  .A   = device type
          .X   = columns
          .Y   = rows
ALTERS :  .A, .X, .Y
```

Performs device-specific io-control operations. Current use only with tty type devices to set the rows x columns for the virtual terminal (actually a pseudo-tty running on the RPi).

#### 2. DIRECTORY CALLS

```
NAME   :  aceDirOpen
PURPOSE:  open a directory for scanning its directory entries
ARGS   :  (zp) = directory pathname
RETURNS:  .A   = file descriptor number
          .CS  = error occurred flag
ALTERS :  .X, .Y, errno
```

This call opens a directory for reading its entries.  It returns a "file" descriptor number to you to use for reading successive directory entires with the "aceDirRead" call.  The pathname that you give to this call must be a proper directory name like "a:" or "c:2//c64/games/:", ending with a colon character.  You can have directories from multiple devices open for reading at one time, but you cannot have the directory of one device open multiple times.  Also note that you cannot pass wildcards to this call; you will receive the entire directory listing.is call; you will receive the entire directory listing.

```
NAME   :  aceDirClose
PURPOSE:  close a directory opened for scanning
ARGS   :  .A   = file descriptor number
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

Closes a directory that is open for reading.  You can make this call at any point while scanning a directory; you do not have to finish scanning an entire directory first.

```
NAME   :  aceDirRead
PURPOSE:  read the next directory entry from an open directory
ARGS   :  .X   = file descriptor number
RETURNS:  .Z   = end of directory flag
          .CS  = error occurred flag
          aceDirentBuffer = new directory entry data
ALTERS :  .A, .X, .Y, errno
```

Reads the next directory entry from the specified open directory into the system interface global variable "aceDirentBuffer" described earlier.  After opening a directory for reading, the first time you call this routine, you will receive the name of the disk (or directory).  The "aceDirentNameLen" and "aceDirentName" fields are the only ones that will contain information; the rest of the fields should be ignored.

Each subsequent call to this routine will return the next directory entry in the directory.  All of the "dirent" fields will be valid for these.

Then, after all directory entries have been read through, the last call will return a directory entry with a null (zero-length) name.  This corresponds to the "blocks free" line in a Commodore disk directory listing.  The
"aceDirentBytes" field for this last entry will be set to the number of bytes available for storage on the disk.  On a Commodore disk drive, this will be the number of blocks free multiplied by 254.  After reading this last entry, you should close the directory.

At any time, if something bizarre happens to the listing from the disk that is not considered an error (I don't actually know if this is possible or not), then the .Z flag will

```
NAME   :  aceDirIsdir
PURPOSE:  determine whether the given pathname is for a file or a directory
ARGS   :  (zp) = pathname
RETURNS:  .A   = device identifier
          .X   = is-a-disk-device flag
          .Y   = is-a-directory flag
          .CS  = error-occurred flag
ALTERS :  errno
```

Given a properly formatted directoryname or filename, this routine will return whether the name is for a file or a directory, whether the device of the file or directory is a disk or character device, and the system identifier for the device.  The two flags return $FF for true and $00 for false.  The device identifier is superfluous for now, but a "devinfo" call may be added later.  Note that this call does not necessarily indicate whether the file/directory actually exists or not.

```
NAME   :  aceDirChange
PURPOSE:  change the current working directory
ARGS   :  (zp) = new directory pathname
          .A   = home flag ($00=given pathname, $80=goto home directory)
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

Changes the current working directory to the named directory if called with a "home flag" value of $00.  Too bad the Commodore Kernal doesn't have a similar call.  Unlike the "cd" shell command, the argument has to be a properly formatted directory name.  Note that only directories in native partitions on CMD devices are supported by this command; the 1581's crummy idea of partitions is not supported.

If the given "home flag" is $80, then this call changes the current working directory back to the "home" directory that is defined in the ".acerc" file as the initial directory.

```
NAME   :  aceDirName
PURPOSE:  return specified system directory name/search path
ARGS   :  .A   = dir/path: 0=curDir, 1=homeDir, 2=execSearchPath,
                           3=configSearchPath, 4=tempDir
          (zp) = string buffer
RETURNS:  .CS  = error-occurred flag
ALTERS :  .A, .X, .Y, errno
```

Returns the null-terminated string for the requested directory or search path.  An argument of 0 means to return the current directory; 1 means to return the home directory; 2, the search path that is used to find executable programs; 3, the search path that is used to find configuration files (usually of the form ".xxxrc"); and 4, the directory to store temporary files.

Actually, search paths (arguments 2 and 3) are really a sequence of null- terminated strings (with each string representing one component of the whole path) terminated with an empty string.  This call should not cause any disk I/O to occur, so it can be called without hesitating about the overhead. The given string-buffer pointer must point to enough storage to hold the result sting(s).  For the current directory, it should be at least 81 characters in length, for the other directories, 32 characters, and for the search paths, 64 characters.


#### 3. SCREEN-CONTROL CALLS

This section describes the system calls that are available to application programmers for full-screen applications.  These calls are intended to be general enough to handle different screen hardware (the VIC and VDC chips and the VIC soft-80-column bitmap screen, and possibly others).  These calls are also designed to be efficient as possible, to discourage progammers from attempting to bypass using them.  Bypassing these calls would be a bad thing.

The calls are designed around the C-128/PET concept of a window.  There is only one active window on the display at a time, which may be is large as the entire screen or as small as a 1x1 character cell.  This window is very cheap to setup and tear down.  An application can have multiple windows on the screen by switching the active window around.

In the calls below, all mention "sw" in the arguments and return values refer to the "syswork" array.  For many calls, there is a "char/color/ high-attribute" argument.  This argument determines which parts of a screen location will be modified.  There are three components (bytes) to each screen location: the character code, the color code, and the special-attributes.  The character code is exactly the same as the PETSCII code for the character that you want to display (unlike the screen-code arrangement that Commodore chose).  There are 128 individual characters in the normal PETSCII positions, and 128 reversed images of the characters in the most sensible other positions.  The codes are as follows:
```
CODES (hex)   DESCRIPTION
-----------   -----------
$00-$1f       reverse lowercase letters
$20-$3f       digits and punctuation
$40-$5f       lowercase letters
$60-$7f       reverse graphics characters
$80-$9f       reverse uppercase letters
$a0-$bf       graphics characters
$c0-$df       uppercase letters
$e0-$ef       reverse digits and punctuation
```
But note that you can't necessarily count on the reversed characters being present with extended font sets; exotic other characters may be present in those positions instead.

There are sixteen color codes, occupying the upper and lower nybbles of the color byte.  The lower nybble specifies the foreground color of the corresponding character, and the upper nybble, the background color.  The VIC and VDC displays don't support background colors per-character, so the background color nybble is always ignored and the screen color is used instead.  The color codes are RGBI codes, as follows:
```
CODE(dec)   (hex)   (bin)   DESCRIPTION
---------   -----   -rgbi   -----------
        0      $0   %0000   black
        1      $1   %0001   dark grey
        2      $2   %0010   blue
        3      $3   %0011   light blue
        4      $4   %0100   green
        5      $5   %0101   light green
        6      $6   %0110   dark cyan on VDC, medium grey on VIC-II
        7      $7   %0111   cyan
        8      $8   %1000   red
        9      $9   %1001   light red
       10      $a   %1010   purple
       11      $b   %1011   light purple on VDC, orange on VIC-II
       12      $c   %1100   brown
       13      $d   %1101   yellow
       14      $e   %1110   light grey
       15      $f   %1111   white
```
Finally, there are the special-attribute bits.  Not all displays support attributes, and not all displays that support attributes support all of the attributes.  For displays that don't support attributes directly, some other action may be taken instead, like changing the display color, when you use the "aceWinPut" call.  The attributes have the following meanings (only four bits are used; the others are ignored but should always be set to zero):
```
BIT VALUE   (dec)   (hex)   DESCRIPTION
-avub----   -----   -----   -----------
%10000000     128     $80   alternate characterset (italic)
%01000000      64     $40   reverse character
%00100000      32     $20   underline
%00010000      16     $10   blink
```
These values are additive (or, should I say, "or-ative"); you can use any combination of them at one time.  Normally, you may wish to leave the high- attribute bits alone, unless you take the values to give them from the color palettes (next section).

Most screen operations allow you to select which of character, color, and/or attributes you wish to modify.  Characters and colors can be selected independently of each other, but attributes should only be selected when color is also selected, as colors and attributes generally "ride together", although on the soft-80 screen, attributes "ride with" the characters. Also, when you select color but not attributes, then attributes are interpreted as if you had selected them but with a value of $00 (all attributes off).  To specify which of you wish to have changed, set bits in the "char/color/attribute" argument to system calls.  The flags have the following values.  They are or-ative as well:
```
BIT VALUE   (dec)   (hex)   DESCRIPTION
-cah-----   -----   -----   -----------
%10000000     128     $80   modify character
%01000000      64     $40   modify color
%00100000      32     $20   modify attribute bits
```
The screen calls that deal with placing characters on the screen refer to screen locations using absolute addresses of locations in screen memory. This scheme is used for increased efficiency.  You can obtain information about the absolute screen address of the top left-hand corner of the current window and the number of screen addresses between successive rows, to figure out screen addresses for your applications.  For added convenience, there is a call which will accept row and column numbers and return the corresponding absolute screen address.  Each successive column of a row has an absolute screen address that is 1 higher than the previous, for all displays.

The screen-control system calls are as follows:

```
NAME   :  aceWinScreen
PURPOSE:  set the screen size
ARGS   :  .A   = number of text rows required, minimum
          .X   = number of text columns required, minimum
RETURNS:  .A   = number of text rows you get
          .X   = number of text columns you get
          .CS  = error occurred flag (requested size cannot be given)
ALTERS :  .Y, errno
```

This call selects an appropriate display device, screen, and layout for displaying text.  You ask for the minimum number of rows and columns you require on the screen, and the call returns to you what you receive.  If the system cannot match your minimum requirements, an error will be returned, and the current screen will be unchanged.  The clock speed of the processor will be changed to match the screen selected, if appropriate.  If you pass either number of rows or columns as 0, then the system default value for the current screen type will be used.  If you pass either parameter having value 255, then the system will use the maximum possible value.

```
NAME   :  aceWinMax
PURPOSE:  set window to maximum size
ARGS   :  <none>
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

Sets the current window to cover the entire screen.  No errors are possible.

```
NAME   :  aceWinSet
PURPOSE:  set dimensions of window
ARGS   :  .A   = number of rows in window
          .X   = number of columns in window
          sw+0 = absolute screen row of top left corner of window
          sw+1 = absolute screen column of top left corner of window
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

Sets the current window to the size you specify.  You will get an error return if the window will not fit on the screen or of it does not contain at least one character.  The absolute screen row and column values start from zero.

```
NAME   :  aceWinSize
PURPOSE:  return dimensions of window
ARGS   :  <none>
RETURNS:  .A   = number of rows in window
          .X   = number of columns in window
          sw+0 = absolute screen row of top left corner of window
          sw+1 = absolute screen column of top left corner of window
         (sw+2)= screen address of top left corner
          sw+4 = screen address increment between successive rows on screen
ALTERS :  <none>
```

Returns information about the current window.  The row-increment value is the number of character positions between successive physical rows on the screen.  The increment between successive positions on the same line is always 1.  No errors are possible.

```
NAME   :  aceWinCls
PURPOSE:  clear window
ARGS   :  .A   = char:$80/color:$40/attribute:$20 modification flags
          .X   = character fill value
          .Y   = color fill value
          sw+6 = attribute fill value
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

This call "clears" the current window by filling it with the character/ color/attributes you specify.  You can use the char/color/attr to limit what gets cleared.

```
NAME   :  aceWinPos
PURPOSE:  return screen address of given row and col
ARGS   :  .A   = row
          .X   = column
RETURNS: (sw+0)= screen memory address of position
ALTERS :  .A, .X, .Y
```

Given a row and column in the current window, returns the corresponding absolute screen-memory location for use with other calls.  No errors are checked for or returned, so garbage in, garbage out.

```
NAME   :  aceWinPut
PURPOSE:  put characters and color onto screen
ARGS   :  .A   = char:$80/color:$40/attribute:$20 modification flags
          .X   = length of character string
          .Y   = color
         (sw+0)= absolute screen address to start putting data at
         (sw+2)= character string pointer
          sw+4 = fill character
          sw+5 = total field length
          sw+6 = attribute flags
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

Puts text onto the screen.  The output region is given by the absolute starting screen address and the total field length.  This region must be contained on one line of the current window, or bad things will happen. Alternatively, you can put data to the screen in a region that is completely outside of the current window, provided that it is contained on one physical line of the display.  A pointer to the characters to be printed is given, as well as the length of the character array.  Control characters in this string are ignored; they are poked literally onto the screen, including the null character.  The length of the character string must be less than or equal to the total length of the field.  Remaining spaces in the field will be filled in with the "fill character".

The color of the total field length will be filled in with "color".  You can use the "char/color/attr" modification flags to specify what is to be changed.  If you were to, for example, specify that only the characters are to be put (and not colors nor attributes), then the call would execute faster.

```
NAME   :  aceWinGet
PURPOSE:  get characters and colors from screen into memory
ARGS   :  .A   = char:$80/color:$40/attribute:$20 modification flags
          .X   = length to get
         (sw+0)= absolute screen address to start getting from
         (sw+2)= character-storage pointer
         (sw+4)= color-storage pointer
         (sw+6)= attribute-storage pointer
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

This call fetches characters, colors, and/or attributes from the screen into the memory you specify.  Handling colors and attributes independently is a bit inefficient, but there is no other good way out of this if we want to support many display types.

```
NAME   :  aceWinScroll
PURPOSE:  scroll window
ARGS   :  .A   = flags: char:$80/color:$40/attribute:$20 + $08=up + $04=down
          .X   = number of rows to scroll up/down
          sw+4 = fill character
          sw+6 = fill attribute
          .Y   = fill color
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

Scrolls the contents of the current window up or down.  You can scroll any number of rows at a time.  After scrolling, the bottom (or top) rows will be filled with the fill character and color (the attribute to fill with will always be all off).  You can limit whether the characters and/or colors are to be scrolled by using the "flags" byte in the usual way, except that the
"color" flag also implies that "attribute" (since you would not normally want to scroll them separately, and it would be a lot of work).  Scrolling only the characters, for example, will normally be twice as fast as scrolling both characters and attributes.  Whether to scroll up or down is specified also using bits in the "flags" field, as indicated in the input arguments above.  If you specify multiple scroll directions in one call, your requests will be carried out, but the screen will end up as it was, with the top and bottom N liness cleared.

```
NAME   :  aceWinCursor
PURPOSE:  activate/deactivate cursor
ARGS   : (sw+0)= screen address to place cursor
          .A   = enable flag ($ff=cursor-on / $00=cursor-off)
          .Y   = color to show cursor in
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

Displays or undisplays the cursor at the given screen address.  This call returns immediately in either case.  No errors are returned.  Do not display anything in or scroll the window while the cursor is being displayed, do not display the cursor twice, and do not undisplay the cursor twice in a row or bad things will happen.  Actually, the screen-address argument will be ignored if you are undisplaying the cursor, so there is no need to provide it in that case.  When the system starts, the cursor will be in its undisplayed state (duh!).  You also get to specify the color you want the cursor to be shown in.

```
NAME   :  aceWinPalette
PURPOSE:  get standard color palette for current screen
ARGS   :  <none>
RETURNS:  sw+0 = main character color
          sw+1 = cursor color
          sw+2 = status character color
          sw+3 = separator character color
          sw+4 = highlight character color
          sw+5 = alert character color
          sw+6 = screen border color
          sw+7 = screen background color
ALTERS :  .A, .X, .Y
```

Returns the palette of colors that are recommended to be used in applications.  These colors are chosen by the user in the system configuration, so they can be interpreted as being what the user wants and expects applications to use.  A different selection is made by the user for each different screen type, and the palette returned will be for the screen type currently in use.  Eight colors are included in the palette, and you may interpret their meaning according to the application.  The suggested usages are given in the return arguments listed above.  I know that a lot of people out there like to use every color available, but there is a point where the use of color stops conveying useful information and starts to look like "angry fruit salad".

```
NAME   :  aceWinChrset
PURPOSE:  set/get character images/palette codes for the current character set
ARGS   :  .A   = flags: $80=put, $40=get, $20=chr/palette, $10=full/rvs,
                        $08=8-bit, $04=4-bit, $02=main, $01=alternate)
          .X   = character code/palette position to start from
          .Y   = number of chars to modify ($00 means 256)
          (zp) = data pointer
RETURNS:  .A   = flags: what's available, $10,$08,$04,$02,$01
ALTERS :  .X, .Y
```

Description too complicated for me to get into right now.
Out flags tells what exists, both put&get means ignore full/rvs.
Read the source code for more details.

```
NAME   :  aceWinOption
PURPOSE:  set/get character window/screen options
ARGS   :  .X   = option number to get/set
                 (1=screen color, 2=border color, 3=cursor style,
                  4=cursor-blink speed, 5=screen rvs, 6=cpu speed,
                  7=alter palette)
          .CS  = set option (.CC=get)
          .A   = value
          .Y   = extra value if needed
RETURNS:  .A   = return value of option
          .CS  = error-occurred flag
ALTERS :  .X, .Y, errno
```

You can use this call to set/get a number of screen options.  If you call with the carry flag clear, you will only read the option, and if you call with the carry flag set, you will both set and read the new option value. You may not always get the option you wanted to set (because of hardware limitations).  The .X register selects which option is to be set/gotten.  If the call returns with the carry flag set, it means either that you have requested an illegal option/value or that the requested option isn't available for the current screen (errno).

Option #1 is the screen color.  The active screen color goes into the lower nybble of the accululator.  Option #2 is the screen border color.  The active color goes into the bottom of the accumulator, but for the VDC screen, which has no border, it will be unchanged and always read as being black.  Option #3 is the cursor style.  The style code goes into the accumulator: $00=flashing block, $01=solid block, $02=flashing underline,
$03=solid underline.  The display driver will do the best it can with the screen hardware.  Option #4 is the cursor blink speed, and the flash speed in jiffies goes into the accumulator (the time to flash on and to flash off.  The flash-on and flash-off times are always equal, and equal to the given value).

Option #5 is to reverse the screen.  A value of $00 in the accumulator means that the screen isn't reveresed, and a value of $ff means that it is. Option #6 is to set the CPU speed.  Arguably, this option doesn't really belong with the screen drivers, but it's here anyway.  The number of MHz goes into the accumulator.  Option #7 is to read/set the color palette.  The palette position to read/change goes into .Y and the color goes into the accumulator.  The palette changes will be in effect for the current display driver for the full run of the system.
```
NAME   :  aceWinGrChrPut
PURPOSE:  Put character from graphical set
ARGS   :  .A   = char:$80/color:$40/attribute:$20 modification flags
          .Y   = color
         (sw+0)= absolute screen address to start putting data at
         (sw+2)= character pointer
         sw+5 = total field length
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

Output a character from the graphical set. This is used in the toolbox code to draw borders around text, such as in popup menus.


#### 4. CONSOLE CALLS

The calls in this section refer to the system "console", which includes the screen and keyboard.  The console-related calls are at a higher level than the calls in the previous section.

```
NAME   :  aceConWrite
PURPOSE:  write data to console
ARGS   :  (zp) = data to print
          .AY  = bytes of data to print
          .X   = initial prescroll & exit mode: $00=off, $01+=presc, $ff=ex-sc
RETURNS:  .X   = required scrolling: $00=none
          (zp) = data still to print, if not completed
          .AY  = bytes still to print, if not completed
ALTERS :  .A, .X, .Y
```

This call is the same as the "write" system call, except this always writes to the console, and no errors are possible, if you call it with .X==$00.  If .X equals any other value, then the screen will be scrolled up that many rows before printing begins and ... This feature is provided so that console-printing applications can implement scrollback buffers.

```
NAME   :  aceConPutlit
PURPOSE:  write literal character to console
ARGS   :  .A   = character
RETURNS:  <none>
ALTERS :  .A, .X, .Y, errno
```

This call is the same as "write"ing a single character to the console, except that the control characters are not interpreted but are displayed literally instead.

```
NAME   :  aceConPos
PURPOSE:  set cursor location
ARGS   :  .A   = row
          .X   = column
RETURNS:  .CS  = error encountered flag
ALTERS :  .A, .X, .Y
```

This call will set the screen location that the next console "read" or
"write" system call will operate from.  If the "cursor" position is outside the boundaries of the current window on the screen, an error will be returned.

```
NAME   :  aceConGetpos
PURPOSE:  get current cursor location
ARGS   :  <none>
RETURNS:  .A   = row
          .X   = column
ALTERS :  .Y
```

This call returns the current location of the console cursor.

```
NAME   :  aceConInput
PURPOSE:  inputs a line from the console
ARGS   :  (zp) = input buffer pointer / initial string pointer
          .Y   = number of characters in initial string
RETURNS:  .Y   = number of entered characters
          .CS  = error
ALTERS :  .A, .X
```

```
NAME   :  aceConStopkey
PURPOSE:  check if stop key is being held down
ARGS   :  <none>
RETURNS:  .CS  = stop key pressed
ALTERS :  .A, .X, .Y, errno
```

Indicates whether the STOP (RUN/STOP) key is currently being held down by the user.  If so, carry flag is set on return (and clear if not).  If the stop key is discovered to be pressed by this call, then the keyboard buffer will also be cleared.

```
NAME   :  aceConGetkey
PURPOSE:  get a key code from the keyboard buffer
ARGS   :  <none>
RETURNS:  .A   = keyboard character
          .X   = shift pattern
ALTERS :  .Y
```

Waits for the user to type a key (or takes a previous keystroke from the keyboard buffer).  Regular characters are returned in their regular PETSCII codes, but there are many special control keystrokes.  I still haven't figured out what all of the special codes should be, but all 256 possible character values will be covered.  Special codes like "page up", etc. should help in standardizing control keystrokes for applications.  Note that these definitions of keycodes is only suggested; your full-screen application can interpret them however it wants.  The key code is returned in the accumulator.  No errors are possible.

The tables below summarize the meanings of the various key codes.  Not all of the C64 keys have been decided yet.  Note that the keys for "@" to "_", used in association with shifting keys, are "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_".
("\" means the Pound key, "^" means the Uparrow key, and "_" means the Backarrow key). "CT" means Control, "SH" means Shift, "AL" means Alternate, and "CO" means Commodore.  On the C64, Alternate is obtained by holding down the Commodore and Control keys simultaneously, and "CS" below means to hold down the Commodore and Shift keys simultaneously.  The "CS" combination is used to make the functions of keys only provided on the C128's extended keyboard available on the C64.
```
CODE(s)   C128 KEY(s)    C64 KEY(s)     DESCRIPTION
-------   ------------   ------------   -----------
$20-$3f   SPIdun to "?"   SPIdun to "?"   Regular numbers and punctuation
$40-$5f   "@" to "_"     "@" to "_"     Regular lowercase letters
$60-$7f   AL-@ to AL-_   <undecided>    Alternate keys
$a0-$bf   CO-@ to CO-_   CO-@ to CO-_   Commodore keys
$c0       SH-*           SH-*           Back-quote (`)
$c1-$da   SH-A to SH-Z   SH-A to SH-Z   Regular uppercase letters
$db       SH-+           SH-+           Left curly brace ({)
$dc       SH-\ (Pound)   SH-\ (Pound)   Vertical bar (|)
$dd       SH-- (Minus)   SH-- (Minus)   Right curly brace (})
$de       SH-Uparrow     SH-Uparrow     Tilda (~)
$df       SH-Backarrow   SH-Backarrow   House character (DEL on most systems)
$e0-$ef   CT-@ to CT-_   CT-@ to CT-_   Control keys

CODE(s)   C128 KEY(s)    C64 KEY(s)     DESCRIPTION
-------   ------------   ------------   -----------
$00       <none>         <none>         <cannot be generated-I may change this>
$01       CT-RETURN      CT-RETURN      End of file
$02       SH-TAB         CS-R           Backtab
$03       STOP           STOP           Stop some operations
$04       HELP           CS-H           Context-sensitive help
$05       CT-2           CT-2           White
$06       SH-LEFT        CS-B           Word left
$07       SH-LINEFEED    CS-P           Menu exit
$08       CO-DEL         CO-DEL         Rubout character under cursor
$09       TAB            CS-T           Tab
$0a       LINEFEED       CS-L           Menu
$0b       SH-RIGHT       CS-N           Word right
$0c       CO-UP          CS-W           Goto top of document
$0d       RETURN         RETURN         Return
$0e       SH-ESCAPE      CS-D           Window control
$0f       CO-DOWN        CS-Z           Goto bottom of document
$10       CO-LEFT        CS-A           Goto beginning of line
$11       DOWN           DOWN           Cursor down
$12       CT-9           CT-9           Rvs
$13       HOME           HOME           Home
$14       DEL            DEL            Backspace
$15       CO-RIGHT       CS-S           Goto end of line
$16       CT-UP          CS-I           Page up
$17       CT-DOWN        CS-M           Page down
$18       CT-TAB         CS-Y           Tab set
$19       CT-LEFT        CS-J           Page left
$1a       CT-RIGHT       CS-K           Page right
$1b       ESCAPE         CS-E           Escape
$1c       CT-3           CT-3           Red
$1d       RIGHT          RIGHT          Cursor right
$1e       CT-6           CT-6           Green
$1f       CT-7           CT-7           Blue

CODE(s)   C128 KEY(s)    C64 KEY(s)     DESCRIPTION
-------   ------------   ------------   -----------
$80       CT-F1          CT-F1          Function key 9
$81       CO-1           CO-1           Orange/Purple(?)
$82       CT-F3          CT-F3          Function key 10
$83       SH-STOP        SH-STOP        Run
$84       SH-HELP        CS-G           Context-insensitive help
$85       F1             F1             Function key 1
$86       F3             F3             Function key 3
$87       F5             F5             Function key 5
$88       F7             F7             Function key 7
$89       SH-F1          SH-F1          Function key 2
$8a       SH-F3          SH-F3          Function key 4
$8b       SH-F5          SH-F5          Function key 6
$8c       SH-F7          SH-F7          Function key 8
$8d       SH-RETURN      SH-RETURN      <undecided>
$8e       CT-F5          CT-F5          Function key 11
$8f       CT-F7          CT-F7          Function key 12
$90       CT-1           CT-1           Black
$91       UP             UP             Cursor up
$92       CT-0           CT-0           Rvs off
$93       SH-HOME        SH-HOME        Clear screen
$94       SH-DELETE      SH-DELETE      Insert one space
$95       CO-2           CO-2           Brown
$96       CO-3           CO-3           Light red
$97       CO-4           CO-4           Dark gray
$98       CO-5           CO-5           Medium gray/dark cyan(?)
$99       CO-6           CO-6           Light green
$9a       CO-7           CO-7           Light blue
$9b       CO-8           CO-8           Light gray
$9c       CT-5           CT-5           Magenta
$9d       LEFT           LEFT           Cursor left
$9e       CT-8           CT-8           Yellow
$9f       CT-4           CT-4           Cyan
```
The shift pattern is recorded when keys are put into the keyboard buffer, and returned in the .X register by this call.
```
BIT VALUE   (dec)   (hex)   DESCRIPTION
---------   -----   -----   -----------
%00100000      32     $20   Extended key (C128 / Commodore+Shift on C64)
%00010000      16     $10   Caps Lock
%00001000       8     $08   Alternate
%00000100       4     $04   Control
%00000010       2     $02   Commodore
%00000001       1     $01   Shift
```
```
NAME   :  aceConKeyAvail
PURPOSE:  check if any key is available in the keyboard buffer
ARGS   :  <none>
RETURNS:  .A   = peeked keyboard character
          .X   = peeked shift pattern
          .Y   = keyboard type ($00=basic, $80=extended)
          .CC  = key is available (.CS if not)
ALTERS :  <none>
```

Returns whether a key is available in the keyboard buffer or not in the carry flag.  If there is a key, then the key and the shift pattern will be returned in the .A and .X registers, but not removed from the buffer so that they will be returned on the next "getkey" call.

The .Y register returns a code indicating what type of keyboard the machine has.  A value of $00 means that only a "basic" keyboard is available, and a value of $80 means that an "extended" keyboard is in use.  The C64 has a
"basic" keyboard and the C128 has an "extended" keyboard.  However, do not use this routine to tell whether you are running on a C64 or a C128, since alternate keyboards may be supported in the future.

```
NAME   :  aceConMouse
PURPOSE:  read the buttons and position of the mouse
ARGS   :  <nothing>
RETURNS:  .A   = mouse-button status: $80=left, $40=right, $20=middle
          .Y   = mouse-present flag: $80=yes
         (sw+0)= mouse X position
         (sw+2)= mouse Y position
ALTERS :  .A, .X, .Y
```

Returns the current mouse status [see: toolx/vdc/pointer.asm](../cbm/toolx/vdc/pointer.asm).

```
NAME   :  aceConJoystick
PURPOSE:  read the inputs of the two joysticks
ARGS   :  <nothing>
RETURNS:  .A   = button mask for joy1: $10=fire,$8=right,$4=left,$2=down,$1=up
          .X   = button mask for joy2: $10=fire,$8=right,$4=left,$2=down,$1=up
          .Y   = joysticks present: $80=joy1, $40=joy2
ALTERS :  <nothing>
```

The kernel will remap the meanings of "joy1" and "joy2" according to the system configuration.  You will normally want to use "joy1" if you are running a single-joystick application.

```
NAME   :  aceConGamepad
PURPOSE:  read/configure the inputs of up to two usb gamepad controllers
ARGS   :  .AY = ptr to byte array
          .CC = read controller
          .CS = configure controller
RETURNS:  4-byte array with controller button bits
ALTERS :  .A, .X, .Y
```

For reading the controllers, pass a pointer to a 4-byte array in .AY. The first two bytes of the array are for js0 and the last two bytes are for js1. For each gamepad, the low-order nybble of the low-order byte has the direction (e.g. D-pad) bits, and the high-order byte has the bits for the 8 supported buttons. The buttons are translated through a configuration option specific to each gamepad. Configuration is done in the idun-shell using the 'joys' command.

The mapping of the standard directions/buttons to the value returned from this procedure is as follows:
```
button X    X    X    X  Left Right Up  Down Strt Sel L-Tr  R-Tr  Y    X    B    A
bit   15   14   13   12   11   10   9    8    7    6    5    4    3    2    1    0    
```

In the case of configuring a gamepad, the carry-bit must be set, and the returned values are button numbers rather than a bitmask. For more details, [see: cmd/joys.asm.](../cbm/cmd/joys.asm)

```
NAME   :  aceConOption
PURPOSE:  read/modify console configuration settings
ARGS   :  .X=option from list below
          .A=new value (if modify)
          .CS=set/modify value
RETURNS:  .A=current value
ALTERS :  .A, .X
```

1=console-put mask,
2=character color, 3=character attributes, 4=fill color, 5=fill attribute,
6=cursor color, 7=force cursor wrap, 8=shift-keys for scrolling,
9=mouse scaling, 10=key-repeat delay, 11=key-repeat rate, 12=prescrool override,
13=screensaver timeout

```
NAME   :  aceConPutchar
PURPOSE:  put single character to console output
ARGS   :  .A   = character                
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

```
NAME   :  aceConPutctrl
PURPOSE:  put control character to console output
ARGS   :  .A   = control char.
          .X   = optional parameter
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

```
NAME   :  aceConSetHotkeys
PURPOSE:  set a handler for hotkeys input to the console
ARGS   :  .AY = pointer to the handler
RETURNS:  <none>
ALTERS :  .A, .Y
```

Normally setup by the toolbox so that applications can easily set/restore hotkey mappings [(see: toolbox.md)](toolbox.md). Set .AY to $0000 to disable.

#### 5. GRAPHICS CALLS

** UNDER CONSTRUCTION ** [(see: toolx/vdc/core.asm)](../cbm/toolx/vdc/core.asm)

#### 6. PROCESS-CONTROL CALLS

This section describes calls that are used to control the execution of processes (active programs).  From within one program, you can call for the execution of another program, have it execute, and then return to the calling program.  Since only one program is allowed in memory at a time, some special problems arise.


```
NAME   :  aceProcExec
PURPOSE:  execute external program as a child process
ARGS   :  (zp) = program name of executable
          (zw) = start address of argument vector
          .AY  = number of arguments
          .X   = reload from file or volatile storage (pages+, $00=file)
          [mp] = pointer to far memory volatile storage
         [sw+0]= "std" file redirections
RETURNS:  .A   = exit code
          .X   = number of bytes in "aceExitData" used
          (zp) = given argument count
          (zw) = given argument vector pointer
          [mp] = pointer to far memory volatile storage
          .CS  = error occurred flag
ALTERS :  .Y, errno
```

Calling this routine will cause a new "frame" to be set up on the "system stack" (lowering the available application area memory a little), the specified program to be loaded into memory over top of the current one, the new program to be executed, the old program to be reloaded from whatever disk unit it came from originally upon exit of the new program, and control to be returned to the old process with the return values from the executed program.  This is a complicated procedure and many things can go wrong.

The first thing that a process that wants to call another program must do is set up the arguments to be passed in.  All arguments must be null-terminated strings.  These arguments are to be put into high memory, starting from one less than the location pointed to by "aceMemTop" and working downward.  It does not matter in which order the strings are placed, as long as they are all grouped together.  Then, immediately below the strings comes the vector of two-byte RAM0 pointers that point to the strings.  This array must be in order, with the lowest entry pointing to the first (zero subscript) string, etc., the second highest entry pointing to the last string, and the highest entry containing the value $0000.  An asciigram follows:
```
  HIGHER ADDRESSES
|           |
|           | <--(aceMemTop)
+-----------+
|           |
| string    |
|           |         : collection of null-terminated strings
|  contents |
|           |
|           |
+-----------+
|   $0000   |         : argv[N] : null argument pointer
+-----------+
| strptrN-1 |         : argv[N-1]
+-----------+
| strptrN-2 |         : argv[N-2]
+-----------+
.           .
.           .
+-----------+
| strptr 1  |         : argv[1] : first actual argument
+-----------+
| strptr 0  | <--(zw) : argv[0] : filename of program to be executed
+-----------+
|           |
  LOWER ADDRESSES
```
The first entry should indicate the filename or command name of the program being executed, and the subsequent arguments are the actual input arguments to the program being called.  The address of the first argument vector table entry is loaded into (zw), and the number of arguments is loaded into .AY. Note that this value also includes the command name, so if, for example, you were to call program "wc" to count two filenames "hello" and "goodbye", then you would pass an argument count of 3.  The name pointed to by "argv[0]" does not actually have to be the literal command name, but the one pointed to by (zp) does.  If a relative executable name is given in (zp), then the search path will be used to locate the executable.  Oh, don't screw up the organization of the arguments or bad things will happen; there is no structure checking.

After setting up the arguments, you'll want to set up any redirections of stdin, stdout, or stderr you'll be needing.  Because there is only one open file table in the whole uni-tasking system, you'll have to manipulate existing entries using the "aceFileFdswap" system call described earlier. The open file table is inherited by the child process.  Note that if it closes any of the open files it inherited, then they are also closed to your use also.  If the child accidentally leaves open any files it opened, they will be closed by the system before you are reactivated.

Finally, before the call is made, you have to save any volatile local information into "far" memory.  All application zeropage and application area memory will be modified by the called program, so you must save whatever you will need to continue after the return to be able to continue. As mentioned earlier, all of the "far" memory that a parent program owns will be safe, so you can save your volatile information there, in any format you wish.  All you have to do is save the pointer to the far memory into the
[mp] pointer.  Upon return of the child process, the value you put into [mp] will be restored, and you can then restore your volatile information out of far storage.  If you wish to save no volatile information, then you can just leave garbage in the [mp] value, since it will not be interpreted by the system.

Alright, so now you call the "aceProcExec" primitive, the child program is loaded, executed, and it returns.

At this time, the parent program (that's you) is reloaded from wherever it was loaded originally and you are returned to the instruction immediately following the "jsr aceProcExec", with your processor stack intact but the rest of your volatile storage invalid.  Even if there is an error return
(carry flag set), your volatile storage will still need to be restored, since the application area may have been overwritten before the error was discovered.  In the case of an error return, the child process will not have been executed.  If the system is unable to reload the parent program (you), then an error return is given to your parent, and so on, as far back as necessary.  (This is a minor exception to the rule that an error return indicates that a child didn't execute; in this case, the child didn't complete).

You are also returned an "exit code", which will have application-specific meaning, although standard programs (e.g., shell script) interpret the value as: 0==normal exit, anything else==error exit.  The X register is also set to indicate the amount of "aceExitData" that is used, to allow for more complicated return values.

```
NAME   :  aceProcExecSub
PURPOSE:  execute internal subroutine as a separate process
ARGS   :  (zp) = address of subroutine
          (zw) = address of argument vector
          .AY  = argument count
          [mp] = far-memory pointer
         [sw+0]= "std" file redirections
RETURNS:  .A   = exit code
          .X   = number of bytes in "aceExitData" used
          (zp) = given argument count
          (zw) = given argument vector pointer
          [mp] = given far-memory pointer
          .CS  = error occurred flag
ALTERS :  .Y, errno
```

This call is very similar to "exec", except that it calls an internal subroutine rather than an external program.  Thus, you don't have to save or restore your volatile storage, or worry about loading the child or reloading the parent.  You do, however, set up the arguments and file redirections as you would for a full "aceProcExec".

```
NAME   :  aceProcExit
PURPOSE:  exit current program, return to parent
ARGS   :  .A   = exit code
          .X   = number of bytes in "aceExitData" used
RETURNS:  <there is no return, brah-ha-ha-ha-ha-ha!!!>
ALTERS :  <don't bloody well matter to the caller>
```

This call causes the current program to exit back to its parent. A program that exits simply by returning to its environment will give back an exit code of 0, which should be interpreted as a normal return.  If you wish to indicate a special return, you should use some exit code other than zero. Many utilities will interpret non-zero error codes as actual errors and may abort further operations because of this.

You may set up a return data in "aceExitData", up to 255 bytes worth, and load the number of bytes used into .X if you wish.  It is recommended that the first field of this data be a special identifier code so programs that cannot interpret your data will not try.  You cannot give any far pointers in your return data, since all far memory allocated to you will be freed by the system before returning to your parent.


#### 7. MEMORY CALLS

The calls given in this section are to be used for accessing "far" memory in ACE, which includes all REU, RAMLink, RAM1 and above, and sections of RAM0 that are not in the application program area.  Applications are not allowed to access "far" memory directly, because the practice of bypassing the operating system would undoubtedly lead to serious compatibility problems
(can you say "MS-DOS"?).

All of these calls use a 32-bit pointer that is stored in the zero-page argument field "mp" (memory pointer).  This field is to be interpreted as consisting of low and high words.  The low word, which of course comes first, is the offset into the memory "bank" that is contained in the high word.  Users may assume that offsets within a bank are continuous, so operations like addition may be performed without fear on offsets, to access subfields of a structure, for example.  You may not, however, make any interpretation of the bank word.  An application should only access far memory that it has allocated for itself via the "aceMemAlloc" call.


```
NAME   :  aceMemZpload
PURPOSE:  load zeropage storage from far memory
ARGS   :  [mp] = source far memory pointer
          .X   = destination zero-page address
          .Y   = transfer length
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

Load zero-page locations with the contents of far memory.  "mp", of course, gives the address of the first byte of far memory to be retrieved.  The X register is loaded with the first address of the storage space for the data on zero page.  It must be in the application zero-page space.  The Y register holds the number of bytes to be transferred, which, considering that transfers must be to the application zero-page storage, must be 126 bytes or less.  This routine will return a "reference through null pointer" if [mp] contains a null pointer.

```
NAME   :  aceMemZpstore
PURPOSE:  store zeropage data to far memory
ARGS   :  .X   = source zero-page address
          [mp] = destination far memory pointer
          .Y   = transfer length
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

This routine is the complement of "zpload"; this transfers data from zero page to far memory.  The arguments and restrictions are the same as
"zpload".

```
NAME   :  aceMemFetch
PURPOSE:  load near RAM0 storage from far memory
ARGS   :  [mp] = source far memory pointer
          (zp) = destination RAM0 pointer
          .AY  = transfer length
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

This routine will fetch up to 64K of data from far memory into RAM0 memory where it can be accessed directly by the processor.  The arguments should mostly speak for themselves.  You should not fetch into RAM0 memory that is not specifically allocated to the application.  You will get an error if you try to use a null far pointer.

```
NAME   :  aceMemStash
PURPOSE:  store near RAM0 data to far memory
ARGS   :  (zp) = source RAM0 pointer
          [mp] = destination far memory pointer
          .AY  = transfer length
RETURNS:  .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

This is the complement of "fetch" and operates analogously, except that it transfers data from RAM0 to far memory.

```
NAME   :  aceMemAlloc
PURPOSE:  allocate pages of far memory to current process
ARGS   :  .A   = requested number of pages to be allocated
          .X   = starting "type" of memory to search
          .Y   = ending "type" of memory to search, inclusive
RETURNS:  [mp] = far memory pointer to start of allocated memory
          .CS  = error occurred flag
ALTERS :  .A, .X, .Y, errno
```

This routine allocates a given number of contiguous far-memory pages for use by the application, and returns a pointer to the first byte of the first page.  On calling, the accumulator contains the number of pages to allocate
(a page is 256 contiguous bytes aligned on a 256-byte address (i.e., the low byte of a page address is all zeros)).

The X and Y registers contain the start and end "types" of far memory to search for the required allocation.  The possible types are mentioned in the System Constants section.  The numeric values for the "aceMem" constants are arranged in order of accessing speed.  So, if your application has speed requirements that dictate, for example, that RAMLink memory should not be used, then you would call "aceMemAlloc" with a search range of .X=0 to
.Y=aceMemInternal.  If you wanted to say you are willing to accept any memory the system can give to you, you would specify .X=0 to .Y=255.  The values of 0 and 255 will be converted to the fastest and slowest memory available.  Idun will give you the fastest type of memory, from what you specify as acceptable, that it can.

This routine will then search its available free memory for a chunk fitting your specifications.  If it cannot find one, the routine will return a "insufficient memory" error and a null pointer.  Note that this error may occur if there is actually the correct amount of memory free but just not in a big enough contiguous chunk.  If successful, this routine will return in "mp" a pointer to the first byte of the first page of the allocated memory.

If you call a subprogram with the "aceProcExec" call while the current program is holding far memory, that far memory will be kept allocated to your program and will be safe while the child program is executing.  If you don't deallocate the memory with "aceMemFree" before exiting back to your parent program, then the system will automatically deallocate all memory allocated to you.  So, have no fear about calling "exit" if you are in the middle of complicated far memory manipulation when a fatal error condition is discovered and you don't feel like figuring out what memory your program owns and deallocating it.

Some applications will want to have the most amount of memory to work with, and if there is free space in the application program area that the program is not using directly, then you may want to use that as "far" memory.  To do this, you will need to write your own stub routines that manage page allocation and deallocation requests to the near memory, and calls the "aceMemAlloc" and "aceMemFree" routines to manage the far memory.  Please note that you CANNOT simply free the unused memory of the application program area and expect the system to manage it.  Bad stuff would happen.

Some applications will want to have a byte-oriented memory allocation service rather than a page-oriented service.  You can build a byte-oriented service on top of the page-oriented service in your application programs that manage memory for the application and ask the system for pages whenever more memory is required by the application.  Note that this still means that allocated memory will be freed automatically when an application exits.  The
"sort" program implements this byte-oriented service, so you can check its source code to see how this is done (or to simply cut and paste the code into your own program).

```
NAME   :  aceMemFree
PURPOSE:  free pages of far memory allocated to current process
ARGS   :  [mp] = far memory pointer to start of memory to be freed
          .A   = number of pages to be freed
RETURNS:  .CS  = error occurred flag
ALTERS :  [mp], .A, .X, .Y, errno
```

This deallocates memory that was allocated to a process by using the
"aceMemAlloc" system call.  You will get an error return if you try to deallocate memory that you don't own.

```
NAME   :  aceMemStat
PURPOSE:  get "far" memory status plus process id
ARGS   :  .X   = zero-page address to store status information
RETURNS:  .A   = current process id
         [.X+0]= amount of "far" memory free
         [.X+4]= total amount of "far" memory
ALTERS :  .X, .Y
```

This call returns the current process id, the number of bytes of far memory currently free, and the total amount of far memory.


#### 8. TIME CALLS

```
NAME   :  aceTimeGetDate
PURPOSE:  get the current date and time
ARGS   : (.AY) = address of buffer to put BCD-format date into
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

Returns the current date and time in the BCD format described in the paragraph on "aceDirentDate".  It puts it into the at-least-eight-byte storage area pointed to by (.AY).

```
NAME   :  aceTimeSetDate
PURPOSE:  set the current date and time
ARGS   : (.AY) = address of date in BCD format
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

Sets the current date and time in the system.  (.AY) points to the BCD date string whose format is discussed in the paragraph on "aceDirentDate".  No validity checking is performed on the date given.


#### 9. TTY ACCESS CALLS

Any Idun device that is configured with "type=6" is available as a stream device. A stream can be used directly by this simple API, to send/receive bulk data to/from the endpoint. Thes devices are accessed using the "open" API. __Impotantly__, once such a device has been opened, all I/O via the idun-cartridge will be _only with this streaming device_; so, no I/O with, for example, a virtual drive, can be done until this stream is closed by calling the "close" API on its file descriptor.

```
NAME   :  aceTtyAvail
PURPOSE:  get count of bytes that may be immediately read
ARGS   :  <none>
RETURNS:  .A   = count
ALTERS :  .A
```

Returns a value from 0-255, where zero means no data is available.

```
NAME   :  aceTtyGet
PURPOSE:  receive up to 256 bytes from stream
ARGS   :  (.AY) = address of receive buffer
          .X    = number of bytes to receive (1-256), with 256 indicated by a zero
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

Copies all available data, up to the length given, into the buffer. If no data is available, then it will block until some data arrives.

```
NAME   :  aceTtyPut
PURPOSE:  send up to 256 bytes to stream
ARGS   :  (.AY) = address of send buffer
          .X    = number of bytes to send (1-256), with 256 indicated by a zero
RETURNS:  <none>
ALTERS :  .A, .X, .Y
aceTtyPut        = aceCallB+216 ;( .AY=SendBuffer, .X=SendBytes,
                                ;  : .CS, error
```

Copies specified number of bytes to the stream output. Always non-blocking.

#### 10. TAGGED MEMORY AND MEMORY-FILE CALLS

The tagged memory system is a convenience API that sits atop the normal far memory allocation routines (aceMemAlloc, aceMemStash, etc.). But rather than using far pointers to keep track of the memory blocks, they are given unique names. These names can even be filenames, thus providing a "memory-mapped file" feature for super-fast access to runtime data with easy load/save to the filesystem. The idun-shell `resident` command, as an example, uses this API to keep frequently used commands in memory.

Any tagged data block will occupy from 256 up to 65,280 bytes with storage using full page boundaries. Only a single byte "Pearson Hash" value is used to identify the block internally, so locating any one of the up to 256 blocks is very fast. Hash collissions are possible, but unlikely, and attempts to allocate a block that matches an existing hash value will return an error.

```
NAME   :  aceTagAlloc
PURPOSE:  allocate a block of memory with tagname
ARGS   :  (zp)  = pointer to null-terminated tagname
          (zw)  = size of block in bytes
RETURNS:  .CS, errno
ALTERS :  .A, .X, .Y
```

```
NAME   :  aceTagStash
PURPOSE:  copies RAM buffer to tagged memory block
ARGS   :  (zp)  = pointer to source RAM buffer
          (.AY) = pointer to null-terminated tagname
RETURNS:  .CS if tagname not found
ALTERS :  .A, .X, .Y
```

```
NAME   :  aceTagFetch
PURPOSE:  copies tagged memory block to RAM buffer
ARGS   :  (zp)  = pointer to destination RAM buffer
RETURNS:  .CS if tagname not found
ALTERS :  .A, .X, .Y
```

```
NAME   :  aceTagRealloc
PURPOSE:  (re)allocate a block of memory with tagname
ARGS   :  (zp)  = pointer to null-terminated tagname
          (zw)  = size of block in bytes
RETURNS:  .CS, errno
ALTERS :  .A, .X, .Y
```

Works the same as aceTagAlloc, but will not allocate additional memory or return an error if a matching tagname already exists.

#### 11. MISCELLANEOUS CALLS

```
NAME   :  aceIrqHook
PURPOSE:  Hook the kernel IRQ handler
ARGS   :  (.AY) = pointer to custom handler
RETURNS:  <nome>
ALTERS :  <none>
```

The kernel has its own IRQ handler that triggers every 1/60th second. This API allows an application to hook an additional handler to also be called at this same rate. _Note: if you just need to trigger a callback after some elapsed time, use the toolbox "tmo" calls that exist for this purpose instead_.

```
NAME   :  aceMiscSysType
PURPOSE:  get system model and memory
ARGS   :  <none>
RETURNS:  .A   = $80/$40 indicates C128/C64 mode, respectively
          .X   = number of internal 64KB RAM banks (1-4)
          .Y   = number of 64KB REU banks (4-255)
          sw+0 = size of VDC memory
ALTERS :  .A, .X, .Y
```

```
NAME   :  aceMiscRobokey
PURPOSE:  send keystroke to the idun-shell, as if typed
ARGS   :  .A   = keycode
RETURNS:  <none>
ALTERS :  .A, .X
```

```
NAME   :  aceMiscDeviceInfo
PURPOSE:  get disk device type & attributes
ARGS   :  (zp) = pointer to filename path
RETURNS:  .A   = IEC device address
          .X   = idun device type (1-8)
          sw+0 = idun device config flags (--dcrush)
          sw+1 = idun device index
          .CS  = is a virtual drive?
ALTERS :  .A, .X, .Y
```

```
NAME   :  aceRestart
PURPOSE:  restart system in one of four manners
ARGS   :  .A   = restart flag
          .X   = device type, if loading a prg
          (zp) = pointer to app/prg filename
RETURNS:  <never> returns!
ALTERS :  <yep>
```

This is the only kernel API call which does not return, since it will restart the computer running something else. The flag passed in .A is any one of the defined restart flags: aceRestartWarmReset, aceRestartExitBasic, aceRestartApplReset, or aceRestartLoadPrg. The difference between exiting to BASIC vs. a warm reset is simply whether you get to BASIC with or without a software reset of the CPU. The other two options are used to load an alternative application over top of the idun-shell (aceRestartApplReset) or to load a native C128 application and start it (aceRestartLoadPrg). In this final case, it is critical to set the .X value to "1" if the program is being loaded from a floppy disk device. Otherwise, it is assumed to be loaded via the idun-cartridge using a virtual drive.

```
NAME   :  aceMapperCommand
PURPOSE:  cause memory-mapper to execute pre-defined command
ARGS   :  .X   = command id
          .A   = command parameter
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

A lot of the functionality of the idun-cartridge is implemented by running arbitrary 6502 code within a non-maskable interrupt (NMI). These two aceMapper APIs allow an Idun application to invoke this process by specifying system or user-defined commands. For a list of available commands, see the `sys` and `usr` APIs of [luaref.md](luaref.md).


```
NAME   :  aceMapperProcmsg
PURPOSE:  receive arbitrary message from memory-mapper
ARGS   :  (.AY) = pointer to callback that processes the message
RETURNS:  <none>
ALTERS :  .A, .X, .Y
```

When this returns, the full message has been processed. It will invoke the callback as many times as needed to process all the data.

```
NAME   :  aceViceEmuCheck
PURPOSE:  determine if we are running in the vice emulator
ARGS   :  <none>
RETURNS:  .ZS = emulator detected
ALTERS :  .A
```

The memory-mapper functionality works in the emulator, but relies on this API to know whether real NMI interrupts are possible. In the emulator, these are simulated.

```
NAME   :  aceMiscUtoa
PURPOSE:  convert unsigned 32-bit number to a decimal PETSCII string
ARGS   :  .A   = minimum length for return string
          .X   = zero-page address of 32-bit number
          (zp) = pointer to string buffer to store string
RETURNS:  .Y   = length of string
ALTERS :  .A, .X
```

This is a utility call in the kernel.  It is really not necessary for it to be in the kernel, but so many programs make use of it that it makes sense for it to be factored out.  You give a pointer to a 32-bit unsigned value in zero page memory, a pointer to a buffer to store that string that is at least as long as necessary to store the value plus the null-character terminator that will be put on the end of the string, and a minimum length value for the string.  If the number requires fewer digits than the minimum length, the string will be padded with spaces on the left.  Since a 32-bit quantity can only contain an maximum of ten decimal digits, the string buffer will only need to be a maximum of eleven bytes in size.

```
NAME   :  aceMiscIoPeek
PURPOSE:  do a peek into the I/O space ($D000-$DFFF)
ARGS   :  (zw) = I/O-space address
          .Y   = offset from (zw)
RETURNS:  .A   = peeked value
          .CS  = error if operation not supported
ALTERS :  <nothing>
```

Does a peek into the system I/O-address space.  This is a pretty ugly call, but you should use this rather than peeking into the space directly because application programs aren't supposed to directly peek into there at all.

```
NAME   :  aceMiscIoPoke
PURPOSE:  do a peek into the I/O space ($D000-$DFFF)
ARGS   :  (zw) = I/O-space address
          .Y   = offset from (zw)
          .A   = value to poke
RETURNS:  .CS  = error if operation not supported
ALTERS :  <nothing>
```

Does a poke into the system I/O-address space.  This is a pretty ugly call, but you should use this rather than poking into the space directly because application programs aren't supposed to directly peek into there at all.


#### 12. IOCTL CALLS

Idun virtual floppies can be mounted, or their contents accessed on a sector-by-sector basis, using these APIs.

```
NAME   :  aceMountImage
PURPOSE:  mount a disk image file
ARGS   :  (zp) = pointer to null-terminated image filename
          .A   = R/W flag
RETURNS:  .CS  = errno
ALTERS :  .A, .X, .Y, errno
```

Idun currently supports .D64, .D71, and .T64 image files, and will likely add others. This API mounts an image file to a virtual drive, just as is done with the `mount` command in the shell. Set the .A flag to either "R" (for read-only) or "W" (for read/write) access to the mounted image.

```
NAME   :  aceDirectRead
PURPOSE:  read a sector from a virtual floppy
ARGS   :  .A   = number of sectors to read
          .X   = file descriptor of open direct channel
          (zp) = pointer to buffer
RETURNS:  .AY  = number of bytes read
          .CS, errno
ALTERS :  .A, .X, .Y
```

See source code for the [diskcopy](../cbm/cmd/diskcopy.asm) command for an example.

```
NAME   :  aceDirectWrite
PURPOSE:  write a sector to a virtual floppy
ARGS   :  .A   = number of sectors to write
          .X   = file descriptor of open direct channel
          (zp) = pointer to buffer
RETURNS:  .CS, errno
ALTERS :  .A, .X, .Y
```

### USER-PROGRAM ORGANIZATION

The Idun system itself is written using the ACME assembler, so it is recommended that applications be written in this also. Programs for Idun have a very simple structure. Below is the standard "hello, world" example program written for the ACME assembler:

```
!source "sys/acehead.asm"
!source "sys/toolhead.asm"
!to "hello", plain

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0

main = *
   lda #<helloMsg
   ldy #>helloMsg
   sta zp+0
   sty zp+1
   lda #<helloMsgEnd-helloMsg
   ldy #>helloMsgEnd-helloMsg
   ldx #stdout
   jsr write
   rts

helloMsg = *
   !pet "Hello, cruel world.", chrCR
helloMsgEnd = *
```
This would normally be put into a file called "hello.asm". First thing this program does is include the "acehead.asm" file. This is the ACME-assembler file that contains the header information declarations required to access the Idun system interface. Many programs will also inclode "toolhead.asm", which is the interface to the toolbox API [(see: toolbox.md)](toolbox.md). Next line gives the starting address to start assembling to; it must be "aceToolAddress", which is the address that Idun will load the program. Next line is a directive to the assembler to write the executable code to a "plain" binary file named "hello". Tools that run from the idun-shell should never have a two-byte header to specify their loading address in the way that Commodore PRG files do.

The next eight bytes of object code (which are the first eight bytes of a loaded program) describe the header required by Idun programs.  The first three bytes must be a JMP to the main routine of the program.  The next three bytes must have the values "aceID1", "aceID2", and "aceID3", respectively.  The next two bytes are the minimum stack requirements and flags, respectively.  The stack requirement is for the processor stack, and Idun will make sure your program has at least this much space before your program starts.  The flags field is currently undefined, but you must give it a value of 0.  And that's all there is to it.  The rest of the program can be organized however you want it to be.

In this example, we set up the arguments for the "write" system call to print the string "Hello, cruel world." plus a carriage return to standard output. Note that this string does not need a terminating null ($00) character since the write call takes a buffer length.  The program then returns to its calling environment via an RTS.  This will cause an implied "exit(0)" to be performed by the system, returning to the parent program.

Although this program does not take advantage of this, an application program may use zero-page locations $0002 through $007f for storage without fear of having the storage trodden upon by the system.

Finally, an application program starts at location "aceToolAddress" (plus six) and is allowed to use memory all the way up to one byte less than the address pointed to by "aceMemTop" for its own purposes.  Currently, this amount of space is on the order of magnitude of about 24K.  This will be increased in the future.

Application programs are not to access I/O features or even change the current memory configuration during execution.  All I/O and other unusual contortions must be performed by Idun system calls; otherwise, we could end up in as bad a shape as MS-DOS.
