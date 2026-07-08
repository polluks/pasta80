;
; Amstrad CPC firmware jumpblock entries
;
KM_WAIT_KEY      EQU $BB18
KM_READ_KEY      EQU $BB1B
KM_TEST_KEY      EQU $BB1E
TXT_OUTPUT       EQU $BB5A
TXT_WR_CHAR      EQU $BB5D
TXT_RD_CHAR      EQU $BB60
TXT_SET_GRAPHIC  EQU $BB63
TXT_WIN_ENABLE   EQU $BB66
TXT_GET_WINDOW   EQU $BB69
TXT_CLEAR_WINDOW EQU $BB6C
TXT_SET_COLUMN   EQU $BB6F
TXT_SET_ROW      EQU $BB72
TXT_SET_CURSOR   EQU $BB75
TXT_GET_CURSOR   EQU $BB78
TXT_CUR_ENABLE   EQU $BB7B
TXT_CUR_DISABLE  EQU $BB7E
TXT_CUR_ON       EQU $BB81
TXT_CUR_OFF      EQU $BB84
TXT_SET_PEN      EQU $BB90
TXT_SET_PAPER    EQU $BB96
MC_WAIT_FLYBACK  EQU $BD19
SCR_SET_MODE     EQU $BC0E

;
; Print character to screen
;
; Entry:  A (ASCII code)
; Exit:   -
; Uses:   IX preserved by firmware
;
__putc:
                push    ix
                call    TXT_OUTPUT
                pop     ix
                ret

;
; Print string to screen
;
; Entry:  HL (string address)
; Exit:   -
; Uses:   AF,BC
;
__puts:         ld      b,(hl)
                inc     b
                jr      __putschk
__putsloop:     ld      a,(hl)
                push    hl
                push    bc
                call    __putc
                pop     bc
                pop     hl
__putschk:      inc     hl
                djnz    __putsloop
                ret

;
; New line
;
; Entry:  -
; Exit:   -
; Uses:   -
;
__newline:
                ld      a,13
                call    __putc
                ld      a,10
                call    __putc
                ret

;
; Read a key from keyboard (blocking, using KM_WAIT_KEY)
; Returns keycode in L for Pascal ReadKey
;
__readkey:
                push    ix
                call    KM_WAIT_KEY
                pop     ix
                ld      l,a
                ld      h,0
                ret

;
; Read a key from keyboard buffer (KM_READ_KEY)
;
__readkey_fw:
                push    ix
                call    KM_READ_KEY
                pop     ix
                ld      l,a
                ld      h,0
                ret

;
; Read line from keyboard
;
__getline:
                ld      hl,__linebuf
                ld      (__lineptr),hl
                xor     a
                ld      (__linelen),a
__readline1:
                call    __readkey
                cp      ' '
                jr      c, __readline2
                cp      127
                jr      nc,__readline2
                ld      hl,(__lineptr)
                ld      (hl),a
                inc     hl
                ld      (__lineptr),hl
                ld      hl,__linelen
                inc     (hl)
                call    __putc
                jp      __readline1
__readline2:
                cp      127
                jr      nz, __readline3
                ld      hl,(__lineptr)
                dec     hl
                ld      (__lineptr),hl
                ld      hl,__linelen
                dec     (hl)
                ld      a,8
                call    __putc
                ld      a,' '
                call    __putc
                ld      a,8
                call    __putc
                jp      __readline1
__readline3:
                cp      13
                jr      nz,__readline1
                ld      hl,(__lineptr)
                ld      (hl),0
                ld      hl,__linebuf
                ld      (__lineptr),hl
                call    __newline
                ret

;
; Set text foreground color (TXT_SET_PEN)
;
; Entry:  L (pen number 0-15)
; Exit:   -
;
__textfg:       push    ix
                ld      a,l
                call    TXT_SET_PEN
                pop     ix
                ret

;
; Set text background color (TXT_SET_PAPER)
;
; Entry:  L (paper number 0-15)
; Exit:   -
;
__textbg:       push    ix
                ld      a,l
                call    TXT_SET_PAPER
                pop     ix
                ret

;
; Move cursor to column X, row Y
; TXT_SET_CURSOR: H=column (X), L=row (Y)
;
; Entry:  L = X (column), E = Y (row)
; Exit:   -
;
__gotoxy:       ld      h,l
                ld      l,e
                push    ix
                call    TXT_SET_CURSOR
                pop     ix
                ret

;
; Get cursor column (X)
; TXT_GET_CURSOR: H=column, L=row
;
; Entry:  -
; Exit:   HL = column
;
__wherex:       push    ix
                call    TXT_GET_CURSOR
                pop     ix
                ld      l,h
                ld      h,0
                ret

;
; Get cursor row (Y)
; TXT_GET_CURSOR: H=column, L=row
;
; Entry:  -
; Exit:   HL = row
;
__wherey:       push    ix
                call    TXT_GET_CURSOR
                pop     ix
                ld      h,0
                ret

;
; Clear screen (send control code 12 = FF = clear window)
;
__clrscr:       ld      a,12
                jp      __putc

;
; Clear to end of line (send control code 18 = DC2)
;
__clreol:       ld      a,18
                jp      __putc

;
; Clear to end of screen (send control code 20 = DC4)
;
__clreos:       ld      a,20
                jp      __putc

;
; Cursor on
;
__cursor_on:
                push    ix
                call    TXT_CUR_ON
                pop     ix
                ret

;
; Cursor off
;
__cursor_off:
                push    ix
                call    TXT_CUR_OFF
                pop     ix
                ret

;
; Keyboard test (returns HL=1 if key pressed, HL=0 if not)
;
; Entry:  -
; Exit:   HL = 1 if key pressed, 0 otherwise
;
__keypressed:   push    ix
                call    KM_TEST_KEY
                pop     ix
                ld      hl,0
                ret     nc
                inc     l
                ret

;
; Wait for one VSync (approx 20ms)
;
__delayvsync:   push    ix
                call    MC_WAIT_FLYBACK
                pop     ix
                ret

;
; Check for Ctrl-C break (non-blocking)
;
__checkbreak:
                push    ix
                call    KM_TEST_KEY
                pop     ix
                ret     nc
                cp      3
                ret     nz
                push    ix
                call    KM_READ_KEY
                pop     ix
                rst     0

;
; Startup
;
__init:         ld      sp,$BE00
                call    main

;
; Shutdown
;
__done:         rst     0
