
start tok64 resc/boot.prg
10 POKE 53280,12:POKE 53281,11:c=50081
20 iec=155:drv=156:PRINT CHR$(142);CHR$(147)
30 PRINT"{yellow}{cm r}{cm a}CI{cm r} {cm r}UCI{space*16}basic commands";
40 PRINT"BB {125*2} B{125} {125} {light gray}drive {reverse on}c:{reverse off}{space*7}cd";CHR$(34);"/directory";CHR$(34);
50 PRINT"{yellow}BB {125}B B{125} {125}{space*19}{light gray}";CHR$(34);":disk.img";CHR$(34);
60 PRINT"{brown}BB {125}B B{125} {125} {light gray}iec{space*3}{reverse on}10{reverse off}{space*7}dos=goto shell";
70 PRINT"{brown}{cm e}{cm z}CKJCK{cm e} {cm e}{space*16}{light gray}@$=directory{space*2}";
80 PRINT"cursor to change,{space*9}@<drv> switch ";
90 PRINT"<return> to accept.{space*7}run ";CHR$(34);"prgname";CHR$(34);
100 GOSUB230
110 GETa$:IF a$="" THEN 110
120 IF a$="{up}" THEN POKE iec,PEEK(iec)+1
130 IF a$="{down}" THEN POKE iec,PEEK(iec)-1
140 IF a$="{left}" THEN GOSUB 330
150 IF a$="{right}" THEN GOSUB 270
160 IF a$=CHR$(13) THEN 210
170 GOSUB 230:GOTO 110
210 PRINT CHR$(14);"{home}{down}{yellow}Commodore "
211 rf=PEEK(65408):IFrfAND128 THEN rom$="ROM"
212 IFrf<128 THEN rom$="CBM"
214 ver$="v"+CHR$(PEEK(c+171))+CHR$(PEEK(c+172))+CHR$(PEEK(c+173))+CHR$(PEEK(c+174))+CHR$(PEEK(c+175))
215 PRINT "{up}          "
216 PRINT " {orange}Forever  "
217 PRINT "{up}          "
218 PRINT "{yellow}"+ver$+" "+rom$+"{white}"
219 PRINT CHR$(17);CHR$(17);
220 SYS50606
230 PRINT CHR$(19);CHR$(18);CHR$(17);CHR$(17);SPC(17);CHR$((PEEK(drv)+64));
240 PRINT CHR$(157);CHR$(17);CHR$(17);
250 i$=STR$(PEEK(iec)):IF LEN(i$)<3 THEN i$=i$+" "
255 PRINT i$
260 RETURN
270 d = PEEK(drv)+1
280 FOR i=d TO 30
290 t = PEEK(c+i*4)
300 IF t=4 OR t=7 THEN POKE drv,i:RETURN
310 NEXT i
320 RETURN
330 d = PEEK(drv)-1
340 FOR i=d TO 1 STEP -1
350 t = PEEK(c+i*4)
360 IF t=4 OR t=7 THEN POKE drv,i:RETURN
370 NEXT i
380 RETURN
stop tok64
(bastext 1.0)
