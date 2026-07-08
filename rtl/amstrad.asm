;
; Amstrad CPC firmware entry points
;
TXT_OUTPUT       EQU $BB5A
KM_READ_KEY      EQU $BB1B
KM_TEST_KEY      EQU $BB18
TXT_SET_CURSOR   EQU $BB5D
TXT_GET_CURSOR   EQU $BB60
TXT_CLEAR_WINDOW EQU $BB66
TXT_SET_PEN      EQU $BB63
TXT_SET_PAPER    EQU $BB64
MC_WAIT_FLYBACK  EQU $BB4D
SCR_SET_MODE     EQU $BC0E

;
; Print character to screen
;
; Entry:  A (ASCII code)
; Exit:   -
; Uses:   IX
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
; Read a key from keyboard (blocking)
;
__readkey:
__readkey1:     push    ix
                call    KM_TEST_KEY
                pop     ix
                jr      nc,__readkey1
                push    ix
                call    KM_READ_KEY
                pop     ix
                ret

;
; Read line from keyboard
;
__getline:
                ld      hl,__linebuf
                ld      (__lineptr),hl
                xor     a
                ld      (__linelen),a
__readline1:    call    __readkey
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
; Set text foreground color
;
; Entry:  L (color 0-15)
; Exit:   -
; Uses:   IX
;
__textfg:       push    ix
                ld      a,l
                call    TXT_SET_PEN
                pop     ix
                ret

;
; Set text background color
;
; Entry:  L (color 0-15)
; Exit:   -
; Uses:   IX
;
__textbg:       push    ix
                ld      a,l
                call    TXT_SET_PAPER
                pop     ix
                ret

;
; Move cursor to column X, row Y
;
; Entry:  L = X (column), E = Y (row)
; Exit:   -
; Uses:   IX
;
__gotoxy:       ld      h,e
                push    ix
                call    TXT_SET_CURSOR
                pop     ix
                ret

;
; Get cursor column
;
; Entry:  -
; Exit:   HL (column)
; Uses:   IX
;
__wherex:       push    ix
                call    TXT_GET_CURSOR
                pop     ix
                ld      h,0
                ret

;
; Get cursor row
;
; Entry:  -
; Exit:   HL (row)
; Uses:   IX
;
__wherey:       push    ix
                call    TXT_GET_CURSOR
                pop     ix
                ld      l,h
                ld      h,0
                ret

;
; Clear screen
;
; Entry:  -
; Exit:   -
; Uses:   IX
;
__clrscr:       push    ix
                ld      hl,0
                ld      de,$4F18
                call    TXT_CLEAR_WINDOW
                pop     ix
                ret

;
; Clear to end of line
;
; Entry:  -
; Exit:   -
; Uses:   IX
;
__clreol:       push    ix
                call    TXT_GET_CURSOR
                ld      a,h
                ld      h,l
                ld      l,a
                ld      d,79
                ld      e,a
                call    TXT_CLEAR_WINDOW
                pop     ix
                ret

;
; Clear to end of screen
;
; Entry:  -
; Exit:   -
; Uses:   IX
;
__clreos:       push    ix
                call    TXT_GET_CURSOR
                ld      a,h
                ld      h,l
                ld      l,a
                ld      d,79
                ld      e,24
                call    TXT_CLEAR_WINDOW
                pop     ix
                ret

;
; Cursor on/off (no-op on CPC)
;
__cursor_on:
__cursor_off:
                ret

;
; Keyboard test (returns NZ if key pressed, A=keycode, Cy=1 if pressed)
;
__keypressed:   push    ix
                call    KM_TEST_KEY
                pop     ix
                ret

;
; Read key (blocking, returns A=keycode)
;
__readkey_fw:   push    ix
                call    KM_READ_KEY
                pop     ix
                ret

;
; Wait for one VSync (approx 20ms)
;
; Entry: -
; Exit:  -
;
__delayvsync:   push    ix
                call    MC_WAIT_FLYBACK
                pop     ix
                ret

;
; Check for Ctrl-C break
;
__checkbreak:
                push    ix
                call    KM_TEST_KEY
                pop     ix
                ret     nc
                push    ix
                call    KM_READ_KEY
                pop     ix
                cp      3
                ret     nz
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
