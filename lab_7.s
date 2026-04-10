# Variables using .equ to better keep track of data instead of memorizing address values
.equ base, 0x640
.equ port_A, base + 0          # Port A selects which digit is displayed
.equ port_B, base + 1          # Port B selects which segments are lit on the given digit
.equ port_C, base + 2
.equ ctrl, base + 3           # Control register used to configure the 8255

                                # X g f e d c b a (Turn segment on means that bit must be 1 in the byte)
.equ blank, 0x00
.equ display_S, 0x6D            # S = a,c,d,f,g
.equ display_H, 0x76            # H = b,c,e,f,g
.equ display_E, 0x79            # E = a,d,e,f,g

.section .data

# 6 Possible frames and 48 bytes for the data using their names instead of actual addresses so we can easily increment/decrement the address to get the current segment
frames:
    .byte display_S, display_H, display_E, blank, blank, blank, blank, blank
    .byte blank, display_S, display_H, display_E, blank, blank, blank, blank
    .byte blank, blank, display_S, display_H, display_E, blank, blank, blank
    .byte blank, blank, blank, display_S, display_H, display_E, blank, blank
    .byte blank, blank, blank, blank, display_S, display_H, display_E, blank
    .byte blank, blank, blank, blank, blank, display_S, display_H, display_E

.section .text
.global _start

_start:
    # Configure the 8255 Control by sending the proper command byte to set all ports to output which is 0b10000000
    movb $0x80, %al          # Send the proper Command byte to the al register as only the accumulator register can be used for IO
    movw $ctrl, %dx          # Set the dx register equal to the address of the control register in the 8255 
    outb %al, %dx          # Output the command byte to the control register in the 8255

main_loop:
    # ---------- move left to right ----------
    movw $frames, %si        # Set the source index register equal to the first byte in the frames label (Will display the letter S) (This will hold the current byte)
    movw $6, %di             # Counter to keep track of the total number of frames which is 6 with each having 8 bytes

shift_right:                 # Display each frame by showing each digit very quickly 1 by 1 and then moving to the next frame until the letter E reaches the 8th digit
    call display_frame       # Display the current frame (8 bytes)
    addw $8, %si             # Add 8 to the SI register so that the address it holds is now equal to the next frame (The first frame was 8 bytes)
    decw %di                 # Decrement the counter for the frames so it knows when to start shift SHE in the other direction
    jne shift_right          # If the counter doesn't equal 0 after being decremented restart the loop

    # ---------- move right to left ----------
    subw $16, %si            # In order to set the current frame to go backwards subtract 16 instead of 8 from the current address so it doesn't sit on the same one for double the length
    movw $4, %di             # Reset the counter for the number of shifts until it S reaches the first digit

shift_left:                  # Same as shift right but in the opposite direction
    call display_frame       # Display the current frame
    subw $8, %si             # Shift the frame left by 1 digit
    decw %di                 # Decrement the counter 
    jne shift_left           # If the counter doesn't equal 0 after being decremented restart the loop to shift left

    jmp main_loop            # If the counter does equal 0 after being decrement restart the main loop



display_frame:
    # Save the values of these original registers so they can be later popped off the stack to these values and modified inbetween
    pushw %ax                # ax register always should hold the data being inputted or data outputted to the IO device
    pushw %cx                # Will be used as a counter to loop through all 8 digits
    pushw %dx                # dx register always should hold the address of the IO device
    pushw %si                # Holds the address of the current byte in the frame

    movw $8, %cx             # Counter to loop to each digit which is 8 digits
    movb $0x7F, %ah          # Only a single digit can be displayed at a time so all except 1 digit out of 8 should be inactive with it starting as the most right digit
    movw $port_A, %dx        # Set the dx register to the address of port A so we can later alternate between outputting between ports A and B

digit_loop:
    # Output the correct segment out of port B
    incw %dx                 # Set the dx register (output register) to port B (1 address higher than A)
    movb (%si), %al          # Set the value of the al register to the current byte in the frame 
    outb %al, %dx          # Output the byte out of port B to set the digit to the correct segment

    # enable the current digit on Port A
    decw %dx                 # Set the dx register to Port A
    movb %ah, %al            # Set the al register to be the ah which held which which digit should be active
    outb %al, %dx          # Output the active digit out of port A

    incw %si                 # Move to the next byte in the frame
    rorb $1, %ah             # Shift the ah register right by 1 which will ensure the next right digit from the previous will now be on
    decw %cx                 # Decrement the counter
    jne digit_loop           # If the counter didn't hit 0 after decrementing repeat as not all 8 digits have been displayed

    # Pop all the registers off the stack and return back to the call display frame
    popw %si
    popw %dx
    popw %cx
    popw %ax
    ret