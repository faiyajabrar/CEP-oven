                ORG 0
                ; DISPLAY SETUP
                LCD_P EQU P2
                LCD_RS EQU P1.4
                LCD_RW EQU P1.5
                LCD_E EQU P1.6

                LCD_DELAY_L0_LOC EQU 6FH
                ;LCD_DELAY_L1_LOC EQU 6EH

                ; LCD DELAY
                LCD_DELAY_L0_COUNT    EQU 22H
                ;LCD_DELAY_L1_COUNT    EQU 10H

                ; KEYPAD SETUP
                KEY_SINGLE_PRESS_BIT    EQU     7FH   ; bool ( BIT ADDRESSABLE )
                KEYPAD_P                EQU     P3    ; PORT = C(7654)R(3210)


                ; 7 SEG DISPLAY SETUP
                M_7SEG_DISP_OUT_PORT        EQU     P0
                M_7SEG_DISP_INDEX_0         EQU     50H
                ; NUMBER OF DISPLAY WILL BE USED
                M_7SEG_DISP_DIGITS_NO       EQU     3

                IF M_7SEG_DISP_DIGITS_NO > 0
                M_7SEG_DISP_DIGITS_0_PORT   EQU     P1.0
                ENDIF
                IF M_7SEG_DISP_DIGITS_NO > 1
                M_7SEG_DISP_DIGITS_1_PORT   EQU     P1.1
                ENDIF
                IF M_7SEG_DISP_DIGITS_NO > 2
                M_7SEG_DISP_DIGITS_2_PORT   EQU     P1.2
                ENDIF
                IF M_7SEG_DISP_DIGITS_NO > 3
                M_7SEG_DISP_DIGITS_3_PORT   EQU     P1.3
                ENDIF

                M_7SEG_DELAY_L0_LOC         EQU     66H
                M_7SEG_DELAY_L1_LOC         EQU     67H
                M_7SEG_DELAY_L2_LOC         EQU     68H

                M_7SEG_DELAY_L0_COUNT       EQU     0FFH
                M_7SEG_DELAY_L1_COUNT       EQU     04H
                M_7SEG_DELAY_L2_COUNT       EQU     01H



                ; COUNTER SETUP
                COUNTER_ADDR_IN_0       EQU 60H
                COUNTER_ADDR_IN_1       EQU 61H
                COUNTER_ADDR_IN_2       EQU 62H

                COUNTER_ADDR_REG     EQU R1
                COUNTER_DIGIT_NO    EQU 03H
                COUNTER_DIGIT_REG   EQU R3

                SEC_DELAY_REG       EQU R7

                COUNTER_L0_LOC         EQU     63H
                COUNTER_L1_LOC         EQU     64H
                COUNTER_L2_LOC         EQU     65H

                ;COUNTER_L0_COUNT       EQU     0FFH
                ;COUNTER_L1_COUNT       EQU     04H
                ;COUNTER_L2_COUNT       EQU     01H

                ; OVEN SETUP
                OVEN_START_PIN              EQU P1.3
                OVEN_PAUSE_PIN              EQU P1.7
                OVEN_TIME_GREATER_60_BIT    EQU 7EH     ; bool ( BIT ADDRESSABLE )

                

                MOV SP, #70H
                MOV PSW, #00H



; ============== MAIN CODE START =====================
MAIN:           ; MAIN CODE START
                LCALL LCD_INIT      ; SETUP LCD DISPLAY
                CLR KEY_SINGLE_PRESS_BIT
    OVEN_LOOP:
                LCALL OVEN_INIT     ; SETUP OVEN PINS AS OUTPUT(0), INPUT(1)
                
                LCALL LCD_CLR
                ;LCALL LCD_CSR
                ;LCALL LCD_CI
                
                MOV DPTR, #LCD_STR
                LCALL LCD_STR_PRINT ; LCD STRING DISPLAY

                LCALL LCD_CL2

                
    LCALL COUNTER_INPUT

    LCALL OVEN_CHECK_TIME_60

    LCALL OVEN_WAIT_START_END    ; PRESS 'ON/C' IN KEYPAD TO START/END

; SECOND DELAY
    LCALL M_7SEG_INIT
    LCALL COUNTER_INIT

  COUNTER:
    MOV SEC_DELAY_REG, #12H
    SEC_DELAY_L0:
                MOV R4, #01H
    SEC_DELAY_L1:
                MOV R5, #01H
        SEC_DELAY_L2:
                MOV R6, #01H
            SEC_DELAY_L3:
                ; EMERGENCY PAUSE
                LCALL EMERGENCY_STOP

                ; 7SEG DISPLAY CODE
                LCALL COUNTER_DISPLAY_7SEG

                DJNZ R6, SEC_DELAY_L3
                DJNZ R5, SEC_DELAY_L2
                DJNZ R4, SEC_DELAY_L1
                DJNZ SEC_DELAY_REG, SEC_DELAY_L0

            ; CONDITION APPLIED FOR TIME > 60S
            JNB OVEN_TIME_GREATER_60_BIT, COUNTER_CONTINUE
            MOV A, COUNTER_L1_LOC
            RRC A
            JC COUNTER_CONTINUE
            LCALL OVEN_PRINT_GREATER_60
    
    COUNTER_CONTINUE:
        DJNZ COUNTER_L0_LOC, COUNTER
                MOV COUNTER_L0_LOC, #0AH
        DJNZ COUNTER_L1_LOC, COUNTER
                MOV COUNTER_L1_LOC, #0AH
        DJNZ COUNTER_L2_LOC, COUNTER
                ;MOV COUNTER_L2_LOC, #0AH

    LCALL OVEN_STOP

    LCALL OVEN_BUZZER

    LCALL LCD_CLR
    ; LCALL LCD_CSR
    ;LCALL LCD_CI

    ;LCD STRING DISPLAY
    MOV DPTR, #LCD_END_STR
    LCALL LCD_STR_PRINT

    LCALL OVEN_WAIT_START_END    ; PRESS 'ON/C' IN KEYPAD TO START/END

    JMP OVEN_LOOP    ; STRAT OVER

    ;IC_HOLD:    JMP IC_HOLD
    MAIN_END:   LJMP PROG_END;END
; ============== MAIN CODE END ========================



; ============== SUBROUTINE / FUNCTIONS ===============
; OVEN INTEGRATE
EMERGENCY_STOP: JB OVEN_PAUSE_PIN, EMERGENCY_END
                LCALL OVEN_STOP
                LCALL LCD_CLR
                LCALL LCD_CL1
                ;LCD STRING DISPLAY
                MOV DPTR, #LCD_OVEN_EMERGENCY_STOP
                LCALL LCD_STR_PRINT
                
                LCALL LCD_CL2
                ;LCD STRING DISPLAY
                MOV DPTR, #LCD_OVEN_REMAINING_TIME
                LCALL LCD_STR_PRINT
                LCALL OVEN_LCD_TIME_PRINT
    ; WAIT
    OVEN_PAUSE: JNB OVEN_PAUSE_PIN, OVEN_PAUSE
                LCALL OVEN_START
                
    EMERGENCY_END:
                RET

OVEN_BUZZER:    ; NOT_START & NOT_PAUSE == OVEN_END
                ; NOR(START , PAUSE) == OVEN_END
                CLR OVEN_START_PIN
                CLR OVEN_PAUSE_PIN
                RET

OVEN_INIT:      ; SETUP OVEN PINS
                CLR OVEN_START_PIN      ; OVEN PIN AS OUTPUT(0)
                SETB OVEN_PAUSE_PIN     ; OVEN PIN AS INPUT(1)
                CLR OVEN_TIME_GREATER_60_BIT   ; CLEAR OVEN_TIME_LESS_60 BOOL
                RET

OVEN_CHECK_TIME_60: ; CHECK IF TIME IS GREATER THAN 60 SEC
                MOV A, COUNTER_ADDR_IN_2
                JNZ OVEN_TIME_G_60
                MOV A, COUNTER_ADDR_IN_1
                CLR C
                SUBB A, #06H
                JNC OVEN_TIME_G_60
                CLR OVEN_TIME_GREATER_60_BIT
                RET
    OVEN_TIME_G_60:
                SETB OVEN_TIME_GREATER_60_BIT
                RET

OVEN_LCD_TIME_PRINT:
                MOV A, COUNTER_L2_LOC
                DEC A
                LCALL LCD_WRITE_NUM
                MOV A, COUNTER_L1_LOC
                DEC A
                LCALL LCD_WRITE_NUM
                MOV A, COUNTER_L0_LOC
                DEC A
                LCALL LCD_WRITE_NUM
                RET

OVEN_WAIT_START_END:; PRESS 'ON/C' IN KEYPAD TO START/END
                    ;MOV A, #'S'
                    ;LCALL LCD_WRITE_DATA
                LCALL KEY_GET
                CJNE A, #'C', OVEN_WAIT_START_END
                LCALL OVEN_START        ; START THE OVEN
                RET

OVEN_START:     SETB OVEN_START_PIN     ; START THE OVEN
                LCALL LCD_CLR
                LCALL LCD_CL1
                ;LCD STRING DISPLAY
                MOV DPTR, #LCD_OVEN_RUNNING
                LCALL LCD_STR_PRINT

                JNB OVEN_TIME_GREATER_60_BIT, NOT_TIME_G_60
                LCALL OVEN_PRINT_GREATER_60
                RET
    NOT_TIME_G_60:
                LCALL LCD_CL2
                ;LCD STRING DISPLAY
                MOV DPTR, #LCD_NOT_TIME_G_60_STR
                LCALL LCD_STR_PRINT
                RET

OVEN_PRINT_GREATER_60:
                LCALL LCD_CL2
                ;LCD STRING DISPLAY
                MOV DPTR, #LCD_TIME_G_60_STR
                LCALL LCD_STR_PRINT
                
                MOV A, COUNTER_L2_LOC
                DEC A
                MOV B, #0AH
                MUL AB
                ADD A, COUNTER_L1_LOC
                DEC A
                RRC A
                LCALL LCD_WRITE_NUM
                RET

OVEN_STOP :     CLR  OVEN_START_PIN     ; STOP  THE OVEN
                RET

COUNTER_INIT:
                MOV COUNTER_L2_LOC, COUNTER_ADDR_IN_2
                MOV COUNTER_L1_LOC, COUNTER_ADDR_IN_1
                MOV COUNTER_L0_LOC, COUNTER_ADDR_IN_0
                INC COUNTER_L2_LOC
                INC COUNTER_L1_LOC
                INC COUNTER_L0_LOC
                RET

COUNTER_INPUT:  ; TAKE INPUT AS INDEX 2
                LCALL KEY_GET_NUM
                MOV COUNTER_ADDR_IN_2 , A
                MOV A, COUNTER_ADDR_IN_2
                LCALL LCD_WRITE_NUM

                ; TAKE INPUT AS INDEX 1
                LCALL KEY_GET_NUM
                MOV COUNTER_ADDR_IN_1 , A
                MOV A, COUNTER_ADDR_IN_1
                LCALL LCD_WRITE_NUM

                ; TAKE INPUT AS INDEX 0
                LCALL KEY_GET_NUM
                MOV COUNTER_ADDR_IN_0 , A
                MOV A, COUNTER_ADDR_IN_0
                LCALL LCD_WRITE_NUM
                RET

COUNTER_DISPLAY_7SEG:

                ; LCALL LCD_CLR
                ; LCALL LCD_CI

                ; MOV A, COUNTER_ADDR_IN_2
                ; LCALL LCD_WRITE_NUM

                ; MOV COUNTER_ADDR_REG, COUNTER_ADDR
                MOV A, COUNTER_L2_LOC
                DEC A
                LCALL M_7SEG_DISP_OUT_2

                ;MOV A, #'2'
                ;LCALL LCD_WRITE_DATA

                ; INC COUNTER_ADDR_REG

                ; MOV A, @COUNTER_ADDR_REG
                ; LCALL LCD_WRITE_NUM

                MOV A, COUNTER_L1_LOC
                DEC A
                LCALL M_7SEG_DISP_OUT_1

                ;MOV A, #'1'
                ;LCALL LCD_WRITE_DATA

                ; INC COUNTER_ADDR_REG

                ; MOV A, @COUNTER_ADDR_REG
                ; LCALL LCD_WRITE_NUM

                MOV A, COUNTER_L0_LOC
                DEC A
                LCALL M_7SEG_DISP_OUT_0

                ;MOV A, #'0'
                ;LCALL LCD_WRITE_DATA

                ; MOV A, #'C'
                ; LCALL LCD_WRITE_DATA
                RET

; FOR LCD
LCD_STR_PRINT:  ;MOV DPTR, #LCD_STR
    LSP_AGAIN:
                CLR A ;set A=0 (match found)
                MOVC A, @A+DPTR ;get ASCII code from table
                JZ LSP_END
                LCALL LCD_WRITE_DATA
                INC DPTR
                SJMP LSP_AGAIN
    LSP_END:    RET


LCD_DELAY:      ;PUSH LCD_DELAY_L0_LOC
                ;PUSH LCD_DELAY_L1_LOC
                MOV LCD_DELAY_L0_LOC, #LCD_DELAY_L0_COUNT
    LCD_DELAY_L0:  
    ;             MOV LCD_DELAY_L1_LOC, #LCD_DELAY_L1_COUNT
    ; LCD_DELAY_L1:  
    ;             DJNZ LCD_DELAY_L1_LOC, LCD_DELAY_L1
                DJNZ LCD_DELAY_L0_LOC, LCD_DELAY_L0
                ;POP LCD_DELAY_L1_LOC
                ;POP LCD_DELAY_L0_LOC
                
                RET

LCD_CMD:        LCALL LCD_READY     ;send command to LCD
                MOV LCD_P, A        ;copy reg A to port 1
                CLR LCD_RS              ;LCD_RS=0 for command
                CLR LCD_RW              ;R/W=0 for write
                SETB LCD_E              ;LCD_E=1 for high pulse
                LCALL LCD_DELAY     ;give LCD some time
                CLR LCD_E               ;LCD_E=0 for H-to-L pulse
                LCALL LCD_DELAY     ;give LCD some time
                RET


LCD_WRITE_DATA: LCALL LCD_READY     ;write data to LCD
                MOV LCD_P, A        ;copy reg A to port1
                SETB LCD_RS             ;LCD_RS=1 for data
                CLR LCD_RW              ;R/W=0 for write
                SETB LCD_E              ;LCD_E=1 for high pulse
                LCALL LCD_DELAY     ;give LCD some time
                CLR LCD_E               ;LCD_E=0 for H-to-L pulse
                LCALL LCD_DELAY     ;give LCD some time
                RET

LCD_WRITE_NUM:  LCALL LCD_READY     ;write data to LCD
                ADD A, #30H         ; CONVERT ASCII NUM
                MOV LCD_P, A        ;copy reg A to port1
                SETB LCD_RS             ;LCD_RS=1 for data
                CLR LCD_RW              ;R/W=0 for write
                SETB LCD_E              ;LCD_E=1 for high pulse
                LCALL LCD_DELAY     ;give LCD some time
                CLR LCD_E               ;LCD_E=0 for H-to-L pulse
                LCALL LCD_DELAY     ;give LCD some time
                RET

LCD_READY:      SETB LCD_P.7
                CLR LCD_RS
                SETB LCD_RW

    LCD_WAIT:   CLR LCD_E
                LCALL LCD_DELAY
                SETB LCD_E
                JB LCD_P.7, LCD_WAIT
                RET

LCD_INIT:       MOV A, #38H         ;init. LCD 2 lines, 5x7 matrix
                ACALL LCD_CMD
                LCALL LCD_COFF      ;dispplay on, cursor on
                LCALL LCD_CMD
                RET

LCD_CL1:        MOV A, #80H         ; CURSOR AT BEGINNING OF LINE 1
                LCALL LCD_CMD
                RET

LCD_CL2:        MOV A, #0C0H         ; CURSOR AT BEGINNING OF LINE 2
                LCALL LCD_CMD
                RET

LCD_CON:        MOV A, #0FH         ; Display on, cursor blinking
                LCALL LCD_CMD
                RET

LCD_COFF:       MOV A, #0CH         ; Display on, cursor off
                LCALL LCD_CMD
                RET

LCD_CLR:        MOV A, #01H         ; Clear Display screen
                LCALL LCD_CMD
                RET

LCD_CD:         MOV A, #04H         ; Decrement cursor (shift cursor to left)
                LCALL LCD_CMD
                RET

LCD_CI:         MOV A, #06H         ; Increment cursor (shift cursor to right)
                LCALL LCD_CMD
                RET

LCD_CSL:        MOV A, #10H         ; Shift cursor position to left
                LCALL LCD_CMD
                RET

LCD_CSR:        MOV A, #14H         ; Shift cursor position to left
                LCALL LCD_CMD
                RET

; FOR KEYPAD
KEY_GET_NUM:
                LCALL KEY_GET
                CLR C
                SUBB A, #30H
                RET

KEY_GET:       MOV KEYPAD_P, #0F0H
               LCALL KEY_CHECK_COL     ; B = COLUMN INDEX
               ;MOV B, A
               LCALL KEY_CHECK_ROW     ; A = ROW INDEX
               PUSH 0F0H
               MOV B, #04H
               MUL AB
               POP 0F0H
               ADD A, B
               MOV DPTR, #KEYPAD_DATA
               MOVC A, @A+DPTR
               RET
      ; END KEY_GET

KEY_CHECK_COL:  MOV A, KEYPAD_P
                ANL A, #0F0H
                CJNE A, #0F0H, KEY_CHECK_SINGLE_PRESS
                CLR KEY_SINGLE_PRESS_BIT
                JMP KEY_CHECK_COL
    KEY_CHECK_SINGLE_PRESS:
                JB KEY_SINGLE_PRESS_BIT, KEY_CHECK_COL
    KEY_CHC_0:  MOV B, #00H
                CJNE A, #0E0H, KEY_CHC_1
                JMP KEY_CHC_END
    KEY_CHC_1:  
                INC B
                CJNE A, #0D0H, KEY_CHC_2
                JMP KEY_CHC_END
    KEY_CHC_2:  
                INC B
                CJNE A, #0B0H, KEY_CHC_3
                JMP KEY_CHC_END
    KEY_CHC_3:  
                INC B
                ;CJNE A, #0F7H, KEY_CHC_END
                ;JMP KEY_CHC_END
    KEY_CHC_END:
                SETB KEY_SINGLE_PRESS_BIT
                RET

KEY_CHECK_ROW: PUSH 0F0H
    KEY_CHR_0:
               MOV B, #00H
               SETB KEYPAD_P.0
               MOV A, KEYPAD_P
               ANL A, #0F0H
               CJNE A, #0F0H, KEY_CHR_1
               JMP KEY_CHR_END
    KEY_CHR_1:
               INC B
               SETB KEYPAD_P.1
               MOV A, KEYPAD_P
               ANL A, #0F0H
               CJNE A, #0F0H, KEY_CHR_2
               JMP KEY_CHR_END
    KEY_CHR_2:
               INC B
               SETB KEYPAD_P.2
               MOV A, KEYPAD_P
               ANL A, #0F0H
               CJNE A, #0F0H, KEY_CHR_3
               JMP KEY_CHR_END
    KEY_CHR_3:
               INC B
               ; SETB KEYPAD_P.3
               ; MOV A, KEYPAD_P
               ; ANL A, #0F0H
               ; CJNE A, #0F0H, KEY_CHR_END
    KEY_CHR_END:
                MOV A, B
                POP 0F0H
                RET

; MULTIPLE 7 SEGMENT DISPLAY

M_7SEG_INIT:    ; SETUP OUTPUT(0) PORTS FOR 7 SEG DISPLAY
                MOV M_7SEG_DISP_OUT_PORT, #00H

                IF M_7SEG_DISP_DIGITS_NO > 0
                CLR M_7SEG_DISP_DIGITS_0_PORT
                ENDIF
                IF M_7SEG_DISP_DIGITS_NO > 1
                CLR M_7SEG_DISP_DIGITS_1_PORT
                ENDIF
                IF M_7SEG_DISP_DIGITS_NO > 2
                CLR M_7SEG_DISP_DIGITS_2_PORT
                ENDIF
                IF M_7SEG_DISP_DIGITS_NO > 3
                CLR M_7SEG_DISP_DIGITS_3_PORT
                ENDIF
                RET

IF M_7SEG_DISP_DIGITS_NO > 0
M_7SEG_DISP_OUT_0:
                LCALL GET_INDEX_VALUE
                MOV M_7SEG_DISP_OUT_PORT, A
                CPL M_7SEG_DISP_DIGITS_0_PORT
                LCALL M_7SEG_DELAY
                CPL M_7SEG_DISP_DIGITS_0_PORT
                RET
ENDIF
IF M_7SEG_DISP_DIGITS_NO > 1
M_7SEG_DISP_OUT_1:
                LCALL GET_INDEX_VALUE
                MOV M_7SEG_DISP_OUT_PORT, A
                CPL M_7SEG_DISP_DIGITS_1_PORT
                LCALL M_7SEG_DELAY
                CPL M_7SEG_DISP_DIGITS_1_PORT
                RET
ENDIF
IF M_7SEG_DISP_DIGITS_NO > 2
M_7SEG_DISP_OUT_2:
                LCALL GET_INDEX_VALUE
                MOV M_7SEG_DISP_OUT_PORT, A
                CPL M_7SEG_DISP_DIGITS_2_PORT
                LCALL M_7SEG_DELAY
                CPL M_7SEG_DISP_DIGITS_2_PORT
                RET
ENDIF
IF M_7SEG_DISP_DIGITS_NO > 3
M_7SEG_DISP_OUT_3:
                LCALL GET_INDEX_VALUE
                MOV M_7SEG_DISP_OUT_PORT, A
                CPL M_7SEG_DISP_DIGITS_3_PORT
                LCALL M_7SEG_DELAY
                CPL M_7SEG_DISP_DIGITS_3_PORT
                RET
ENDIF

GET_INDEX_VALUE:
                MOV DPTR, #M_7SEG_ARRAY
                MOVC A, @A+DPTR
                CPL A   ; COMLEMENT IF NEEDED
                
M_7SEG_DELAY:
                NOP
                NOP
                NOP
                MOV M_7SEG_DELAY_L0_LOC, #M_7SEG_DELAY_L0_COUNT
    M_7SEG_DELAY_L0:
                MOV M_7SEG_DELAY_L1_LOC, #M_7SEG_DELAY_L1_COUNT
    M_7SEG_DELAY_L1:
                MOV M_7SEG_DELAY_L2_LOC, #M_7SEG_DELAY_L2_COUNT
    M_7SEG_DELAY_L2:
                DJNZ M_7SEG_DELAY_L2_LOC, M_7SEG_DELAY_L2
                DJNZ M_7SEG_DELAY_L1_LOC, M_7SEG_DELAY_L1
                DJNZ M_7SEG_DELAY_L0_LOC, M_7SEG_DELAY_L0
                RET



; =================== DATA LOOK UP TABLE =============================
    ; END OF THE STRING HAS TO BE 0
    LCD_STR:  DB 'L', 'C', 'D', ' ', 'D', 'I', 'S', 'P', 'L', 'A', 'Y',  0
                ;NOP
    KEYPAD_DATA:
               DB '7', '8', '9', '/', '4', '5', '6', '*', '1', '2', '3', '-', 'C', '0', '=', '+' , 0
               ;NOP
    M_7SEG_ARRAY:
                DB 3FH, 06H, 5BH, 4FH, 66H, 6DH, 7DH, 07H, 7FH, 6FH, 77H, 7CH, 39H, 5EH, 79H, 71H, 0
                ;   0 ,  1 ,  2 ,  3 ,  4 ,  5 ,  6 ,  7 ,  8 ,  9 ,  A ,  b ,  C ,  d ,  E ,  F ;
                ;NOP
    LCD_END_STR:
    		DB 'O', 'v', 'e', 'n', ' ', 'Q', 'u', 'e', 's', 't', ' ', 'C', 'o', 'm', 'p', 'l', 'e', 't', 'e', '!', 0

LLCD_END_STR:
    DB 'T','a','s','k',' ','D','o','n','e','!', 0

LCD_OVEN_EMERGENCY_STOP:
    DB 'E','M','E','R','G','E','N','C','Y',' ','S','T','O','P','!', 0

LCD_OVEN_REMAINING_TIME:
    DB 'T','i','m','e',' ','L','e','f','t',':', 0

LCD_OVEN_RUNNING:
    DB 'O','v','e','n',' ','O','N', 0

LCD_NOT_TIME_G_60_STR:
    DB 'W','a','i','t',' ','a',' ','b','i','t', 0

LCD_TIME_G_60_STR:
    DB 'T','i','m','e',' ','=',' ','2','0','s',' ','x', 0


PROG_END:
                END

