What is ERAM?
=============

ERAM is a 4.0 Megabyte expansion memory available to your Commodore with an idun-cartridge. It works similarly to "GeoRAM", but is not compatible and will need a different driver for GEOS. ERAM is not normally used for running code; it's for faster and more convenient access to large data sets, and for sharing memory with the ARM CPU when used with hybrid applications (i.e. apps that use Linux or Lua). You can think of ERAM as poviding "Extra", "External", or "Expansion" memory, but for much more than just a "RAM Disk".

Using ERAM from software can be done in multiple ways. You can program it directly using a simple hardware interface controlled by two registers. Or, you can use one of two builtin APIs: the low-level "Stash API" or the high-level "New API".

## High-level ERAM API (New/Mmap)

This API makes it very simple to use ERAM in an application or tool written for the idun-cartridge. There are only 3 routines.

1. **new** - Combines a memory allocation with a memory stash operation. The data in local memory is transferred to ERAM. If an allocation size, but no data is provided, then it's just an alloc with the ERAM initialized to zeroes.
2. **memtag** - Previously allocated memory (using `new`) is paired with a hashtag, giving the memory in ERAM a name. This allows the data in memory to be opened as a file using a filename like "_:hashtag".
3. **mmap** - Combines loading a file into memory with the above hash tagging. A file is instantly loaded to ERAM from the SD card, without passing the data through local memory. So, it's VERY fast. Then, the data in ERAM is accessed using any of the file API, Low-level ERAM API, or hardware interface.

### File style API for tagged ERAM

As mentioned above, a memory buffer in ERAM can be assigned a name, and then treated as a file in a call to the `open` routine. The key is to prefix the filename for `open` with the device previx `_:`. This tells the `open` call to locate the file in ERAM. You can then use other file routines (`read`, `seek`, etc.) To access the data in a simple and familiar way. Since the data is in ERAM, access is even faster than the normal file access (already pretty fast). But even better is that it's a random access memory buffer that can also be shared by software running on the ARM CPU. This opens many exciting possibilities for future applications.

## Low-level ERAM API (Stash/Fetch)

ERAM is also compatible with the existing, low-level `aceMem*` API calls which still work with local RAM banks too. The routines are `aceMemAlloc, aceMemStash, aceMemFetch, and aceMemFree`. You should note that ERAM is automatically garbage collected when a process exits, so calls to `aceMemFree` are unnecessary and ignored when using ERAM. This API is familiar to many Commodore programmers because it is the same approach used for additional local RAM banks and the REU. You are free to mix & match calls to this API with the ones from the New API and with direct hardware access, if needed. You just have to be sure that you address the ERAM buffers correctly, which is done by treating all far memory pointers as 32-bit values.

*far memory pointer (mp)*
| ptr byte | mp+0        | mp+1 | mp+2       | mp+3        |
| -------- | ----------- | ---- | ---------- | ----------- |
|          | byte offset | page | bank/block | memory type |

The memory type is either `aceMemInternal` or `aceMemERAM`.

## Hardware interface

Like GeoRAM, ERAM uses two registers in the cartridge IO space to select one page (256 bytes) of the external RAM at a time. The page contents are also accessed using IO space. The registers used to specify the block/page are $defe & $deff.  The definition for each register is pretty simple:

8-bit byte addr | 6-bit Page addr  | 8-bit Block addr
--------------  | ---------------- | -----------------
   $DFxx        | $DEFE (*bits 0-5)|      $DEFF
* $DEFE bit 6 indicates Ready
* $DEFE bit 7 indicates Write mode
* $DEFF is a write-only register

This scheme provides a total of 22 address bits, thus supporting 4 MiB of ERAM. The 8-bit value stored to $DEFF selects 1 of 256 16 KiB blocks, and the 6-bit value stored to $DEFE selects 1 of 64 pages, each of size 256 bytes. Then, the individual byte is read using an 8-bit offset from $DF00. The memory appears one page at a time in $DFxx.

Bit 7 of the Page addr register is used to enable writing to the memory. If this bit is not set, then the memory in $DFxx is read only. If it is set then the memory is write only.

Bit 6 of the Page addr register is used as the "Ready bit". A "1" in this bit location indicates selected ERAM page is ready for access (at $DFxx). After modifying either register, you MUST wait on the Ready bit set to access the page data.

The initial setup following reset will have the first page of the last block selected- which we can write as "$ff/0". This page is special- it holds the Freemap, which is a list of the number of free pages in each of the 256 ERAM blocks. The Freemap is treated as a read-only page since it is updated automatically by the cartridge. Each time you select a block/page and write some data to it, the Freemap gets updated to reflect the pages you have used.

Updating the value of either register will cause the Ready Bit to go low, temporarily. Depending on many factors, the delay before the Ready Bit goes high, and you can access the data, could be from a few Commodore machine cycles to multiple milliseconds. If you attempt to access the page data without waiting for the Ready Bit, you will read invalid data and any writes will be lost. So don't do this.

In practice, you should first write the Block addr to $DEFF for the 16KiB Block you want to work with. Wait on the Ready bit to go high, and at that time the first page of the Block is available to read in $DFxx. To select a different page, write the Page addr to $DEFE and again wait on the Ready bit. If you want to write a page, then OR the Page addr with $80 before writing it to the Page addr.

```
    lda #$01
    sta $deff   ;select block #1
-   bit $defe
    bvc -       ;waiting on ready
    lda #$04
    sta $defe   ;select page #4
-   bit $defe
    bvc -       ;waiting on ready
    ;now access the data in $dDFxx
    lda $df00
    ... and such ...
```
For the common use-case of accessing consecutive pages, you can normally just do "inc $defe", then wait on the Ready bit. You have to be cognizant of the rollover. Use this simple code to safely advance to the next Page while accounting for rollover.

```
    lda $defe
    cmp #$ff        ;check if last page of block
    bne +
    ;need to select next 16 KiB block in $deff
    lda next
    sta $deff       ;0th page will automatically select
    jmp w           ;jump to wait for Ready
+   inc $defe
w:  bit $defe
    bvc w
    ;all done; access the next page in $DFxx
```
### Block caching and performance

The Block you are currently working with is always held in a cache. This allows reading/writing of all pages in the current Block with fast switching between the pages of the Block. However, anytime you change the Block addr, any modified data in the cache must be stored and then the newly selected Block has to be loaded to the cache. Depending on how many pages are used, this can be a slow operation. Therefore, you should only change the Block addr sparingly to not incur this overhead, except when necessary. In practice, you should use the APIs provided in order to get good performance without having to worry much about caching or deal with the hardware interface.
