.code16

.equ BASE,   0x640
.equ PORTA,  BASE+0          # digit select (lab reverses A/B)
.equ PORTB,  BASE+1          # segment data
.equ PORTC,  BASE+2
.equ CTRL,   BASE+3

.equ BLANK,  0x00
.equ SEG_S,  0x6D            # S = a,c,d,f,g
.equ SEG_H,  0x76            # H = b,c,e,f,g
.equ SEG_E,  0x79            # E = a,d,e,f,g

.section .data

# 6 frames for moving "SHE" across an 8-digit display
frames:
    .byte SEG_S, SEG_H, SEG_E, BLANK, BLANK, BLANK, BLANK, BLANK
    .byte BLANK, SEG_S, SEG_H, SEG_E, BLANK, BLANK, BLANK, BLANK
    .byte BLANK, BLANK, SEG_S, SEG_H, SEG_E, BLANK, BLANK, BLANK
    .byte BLANK, BLANK, BLANK, SEG_S, SEG_H, SEG_E, BLANK, BLANK
    .byte BLANK, BLANK, BLANK, BLANK, SEG_S, SEG_H, SEG_E, BLANK
    .byte BLANK, BLANK, BLANK, BLANK, BLANK, SEG_S, SEG_H, SEG_E

.section .text
.global _start

_start:
    call init_8255

main_loop:
    # ---------- move left to right ----------
    movw $frames, %bx        # BX = address of current frame
    movw $6, %di             # 6 total frames

forward_frame:
    movw $40, %bp            # refresh this frame many times so it is visible

forward_refresh:
    movw %bx, %si            # SI = address of current 8-byte frame
    call show_frame
    decw %bp
    jne forward_refresh

    addw $8, %bx             # next frame (8 bytes per frame)
    decw %di
    jne forward_frame

    # ---------- move right to left ----------
    subw $16, %bx            # after loop BX is past frame 6; back up to frame 5
    movw $4, %di             # show frames 5,4,3,2

reverse_frame:
    movw $40, %bp

reverse_refresh:
    movw %bx, %si
    call show_frame
    decw %bp
    jne reverse_refresh

    subw $8, %bx             # previous frame
    decw %di
    jne reverse_frame

    jmp main_loop


# ------------------------------------------------------------
# init_8255
# Programs 8255 control register:
#   D7 = 1   mode set
#   D6-D5=0  Group A Mode 0
#   D4 = 0   Port A output
#   D3 = 0   Port C upper output
#   D2 = 0   Group B Mode 0
#   D1 = 0   Port B output
#   D0 = 0   Port C lower output
# Control word = 10000000b = 0x80
# ------------------------------------------------------------
init_8255:
    movb $0x80, %al
    movw $CTRL, %dx
    outb %al, (%dx)
    ret


# ------------------------------------------------------------
# show_frame
# Input:
#   SI = address of current 8-byte frame
#
# For this lab:
#   Port A = digit select
#   Port B = segment data
#
# Select pattern starts at 0x7F and rotates right:
#   01111111, 10111111, 11011111, ...
# so one digit is active at a time.
# ------------------------------------------------------------
show_frame:
    pushw %ax
    pushw %cx
    pushw %dx
    pushw %si

    movw $8, %cx             # 8 digits
    movb $0x7F, %ah          # first digit select pattern

digit_loop:
    # turn all digits off first
    movw $PORTA, %dx
    movb $0xFF, %al
    outb %al, (%dx)

    # send segment byte to Port B
    incw %dx                 # DX = PORTB
    movb (%si), %al
    outb %al, (%dx)

    # enable the current digit on Port A
    decw %dx                 # DX = PORTA
    movb %ah, %al
    outb %al, (%dx)

    call delay_short

    incw %si                 # next byte in this frame
    rorb $1, %ah             # next digit select pattern
    loop digit_loop

    # blank display after finishing one scan
    movw $PORTA, %dx
    movb $0xFF, %al
    outb %al, (%dx)

    popw %si
    popw %dx
    popw %cx
    popw %ax
    ret


# ------------------------------------------------------------
# delay_short
# Small software delay so each digit stays on briefly.
# ------------------------------------------------------------
delay_short:
    pushw %cx
    movw $2000, %cx

delay_loop:
    loop delay_loop

    popw %cx
    ret
