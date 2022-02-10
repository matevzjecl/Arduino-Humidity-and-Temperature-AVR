#define __SFR_OFFSET 0x00

#include "avr/io.h"
#include "avr/sfr_defs.h"

.global DHT11_sensor
.global init_serial
.global LCD_write

DHT11_sensor:

  agn: RCALL delay_2s      ; čakanje 2sec da se DHT senzor pripravi
  
  SBI   DDRB, 4            ; pin 10 nastavimo za output
                           ; nastavljanje PWM pinov za LED
  SBI DDRE, 5              
  SBI DDRE, 3
  SBI DDRB, 5
  SBI DDRB, 6
  CBI   PORTB, 4           ; senzorju pošljemo vrednost 0
  
                           ; nastavljanje delovanje PWM pinov
  ldi   r24, 0b10001011
  sts   TCCR3A, r24
  ldi   r24, 0b10100011
  sts   TCCR1A, r24
  
  RCALL delay_20ms       ; 20ms zakasnitev
  SBI   PORTB, 4         ; senzorju pošljemo vrednost 1
  CBI   DDRB, 4          ; pin 10 nastavimo za input
  
  w1: SBIC  PINB, 4
  RJMP  w1               ; čakanje vrednosti 0 pina 10 (senzorja)
  w2 : SBIS  PINB, 4
  RJMP  w2               ; čakanje vrednosti 1 pina 10 (senzorja)
  w3 : SBIC  PINB, 4
  RJMP  w3               ; čakanje vrednosti 0 pina 10 (senzorja)
  
  RCALL DHT11_reading    ; branje prvih 8 bitov podatkov (celoštevilski del vlage)
  MOV   R19, R18
  RCALL DHT11_reading    ; branje drugih 8 bitov podatkov (decimalni del vlage)
  MOV   R30, R18
  RCALL DHT11_reading    ; branje tretjih 8 bitov podatkov (celoštevilski del temperature)
  MOV   R21, R18
  RCALL DHT11_reading    ; branje četrtih 8 bitov podatkov (decimalni del temperature)
  MOV   R22, R18
  RCALL DHT11_reading    ; branje zadnjih 8 bitov podatkov (preverjanje pravilnost podatkov, checksum)

                         ; vsi podatki se seštejejo in preverjajo enakost z checksum
  LDI     R23, 0
  ADD     R23, R19
  ADD     R23, R30
  ADD     R23, R21
  ADD     R23, R22
  CP      R23, R18
  BRNE    agn
                        ; pisanje podatkov za temperaturo na LCD
  LDI   R16, 0x85
  RCALL command_wrt
  MOV   R16, R21
  RCALL decimal_ascii
  LDI   R16, '.'
  RCALL data_wrt
  MOV   R16, R22
  RCALL decimal_ascii
  LDI   R16, 223
  RCALL data_wrt
  LDI   R16, 'C'
  RCALL data_wrt

                      ; pisanje podatkov za vlago na LCD
  LDI   R16, 0xC6
  RCALL command_wrt
  MOV   R16, R19
  RCALL decimal_ascii
  LDI   R16, '.'
  RCALL data_wrt
  MOV   R16, R30
  RCALL decimal_ascii
  LDI   R16, '%'
  RCALL data_wrt
                      ; prižiganje LED glede na vrednosti
  LDI     R20, 255
  LDI     R24, 85
  LDI     R25, 0

  CPI     R21, 20
  BRSH    temp_mid
  BRLO    temp_low
  
  temp_high:
  STS     OCR3C, R20
  STS     OCR1B, R25  
  RJMP    hum
  temp_mid:
  CPI     R21, 26
  BRSH    temp_high
  STS     OCR3C, R24
  STS     OCR1B, R25 
  RJMP    hum

  temp_low:
  CPI     R21, 15
  BRLO    temp_low2
  STS     OCR1B, R24
  STS     OCR3C, R25
  RJMP    hum

  temp_low2:
  STS     OCR1B, R20
  STS     OCR3C, R25

  hum:
  CPI     R19, 40
  BRSH    hum_mid
  BRLO    hum_low
  

  hum_high:
  STS     OCR1A, R20
  STS     OCR3A, R25

  RJMP    con
  hum_mid:
  CPI     R19, 55
  BRSH    hum_high

  STS     OCR1A, R24
  STS     OCR3A, R25
  RJMP    con

  hum_low:
  CPI     R19, 30
  BRLO    hum_low2
  STS     OCR3A, R24
  STS     OCR1A, R25
  RJMP    con

  hum_low2:
  STS     OCR3A, R20
  STS     OCR1A, R25


  con:

  RJMP  agn           ; program se vrne na ponovno branje podatkov iz senzorja
  
                      ;podprogram za branje 5x po 8 bitov iz senzorja
  DHT11_reading:
  LDI   R17, 8       
  CLR   R18           
  
  w4: SBIS  PINB, 4
  RJMP  w4            ; program čaka na odziv senzorja (vrednost 1)
  RCALL delay_timer0  ; 50 us zakasnitev
  
                      ; shranjevanje vsakega bita posebej v register R18
  SBIS  PINB, 4       
  RJMP  skp           
  SEC                 
  ROL   R18           
  RJMP  w5            
  skp : LSL   R18     
  
  w5: SBIC  PINB, 4
  RJMP  w5            ; program čaka na odziv senzorja (vrednost 0)
  
  DEC   R17           
  BRNE  w4            
RET                 

                         ; podprogram za pisanje podatkov na LCD, program se začne s tem podprogramom
LCD_write:
  LDI   R16, 0xFF
  OUT   DDRA, R16         ; nastavljanje porta A za podatke LCD
  LDI   R16, 0xFF
  OUT   DDRC, R16         ; nastavljanje porta C za ukaze LCD
  CBI   PORTC, 0          
  RCALL delay_ms          ; čakanje da se LCD prižge

                          ; klicanje podprograma za inicializacijo LCD, prikaz začetnega teksta in podprogram senzorja
  RCALL LCD_init          
  
  RCALL disp_message      
  
  RCALL DHT11_sensor
RET

                          ; podprogram za incializacijo LCD
LCD_init:
  LDI   R16, 0x33         ; inicializacija LCD za 4-bitne podatke
  RCALL command_wrt       
  RCALL delay_ms
  LDI   R16, 0x32         
  RCALL command_wrt
  RCALL delay_ms
  LDI   R16, 0x28         ; LCD 2 vrstice
  RCALL command_wrt
  RCALL delay_ms
  LDI   R16, 0x0C         
  RCALL command_wrt
  LDI   R16, 0x01         ; počisti LCD
  RCALL command_wrt
  RCALL delay_ms
  LDI   R16, 0x06         ; premakni kurzor desno
  RCALL command_wrt
RET

                          ; podprogram za izvedbo ukazov
command_wrt:
  MOV   R27, R16
  ANDI  R27, 0xF0         
  OUT   PORTA, R27        ; port A nastavi kot output
  CBI   PORTC, 1          
  SBI   PORTC, 0          
  RCALL delay_short       
  CBI   PORTC, 0          
  RCALL delay_us          
  
  MOV   R27, R16
  SWAP  R27               
  ANDI  R27, 0xF0         
  OUT   PORTA, R27       
  SBI   PORTC, 0          
  RCALL delay_short       
  CBI   PORTC, 0         
  RCALL delay_us          
RET
                        ; podprogram za pisanje na LCD
data_wrt:
  MOV   R27, R16
  ANDI  R27, 0xF0         
  OUT   PORTA, R27        
  SBI   PORTC, 1          
  SBI   PORTC, 0          
  RCALL delay_short       
  CBI   PORTC, 0          
  RCALL delay_us         
  
  MOV   R27, R16
  SWAP  R27               
  ANDI  R27, 0xF0        
  OUT   PORTA, R27       
  SBI   PORTC, 0          
  RCALL delay_short      
  CBI   PORTC, 0          
  RCALL delay_us          
RET

                          ; podprogram za pisanje začetnega teksta na LCD
disp_message:
  LDI   R16, 'T'          
  RCALL data_wrt          
  LDI   R16, 'e'
  RCALL data_wrt
  LDI   R16, 'm'
  RCALL data_wrt
  LDI   R16, 'p'
  RCALL data_wrt
  LDI   R16, ':'
  RCALL data_wrt

  LDI   R16, 0xC0        
  RCALL command_wrt
  RCALL delay_ms

  LDI   R16, 'V'
  RCALL data_wrt
  LDI   R16, 'l'
  RCALL data_wrt
  LDI   R16, 'a'
  RCALL data_wrt
  LDI   R16, 'g'
  RCALL data_wrt
  LDI   R16, 'a'
  RCALL data_wrt
  LDI   R16, ':'
  RCALL data_wrt
RET

                  ; podprogrami za zakasnitev
delay_short:
  NOP
  NOP
RET

delay_us:
  LDI   R20, 90
  ll2:   RCALL delay_short
  DEC   R20
  BRNE  ll2
RET


delay_seconds:       
  LDI   R20, 255      
  ll4: LDI   R21, 255 
  ll5: LDI   R22, 20  
  ll6: DEC   R22      
  BRNE  ll6           
  DEC   R21           
  BRNE  ll5           
  DEC   R20          
  BRNE  ll4          
RET                 
                         
delay_2s:           ; delay 2s
  LDI   R21, 255
  l6: LDI   R22, 255
  l7: LDI   R23, 164
  l8: DEC   R23
  BRNE  l8
  DEC   R22
  BRNE  l7
  DEC   R21
  BRNE  l6
RET

delay_ms:
  LDI   R21, 40
  ll3:   RCALL delay_us
  DEC   R21
  BRNE  ll3
RET

delay_20ms:             ; delay 20ms
  LDI   R21, 255
  l3: LDI   R22, 210
  l4: LDI   R23, 2
  l5: DEC   R23
  BRNE  l5
  DEC   R22
  BRNE  l4
  DEC   R21
  BRNE  l3
RET


delay_timer0:           
  CLR   R20
  OUT   TCNT0, R20      
  LDI   R20, 100
  OUT   OCR0A, R20     
  LDI   R20, 0b00001010
  OUT   TCCR0B, R20     
  
  l2: IN    R20, TIFR0 
  SBRS  R20, OCF0A      
  RJMP  l2              
  
  CLR   R20
  OUT   TCCR0B, R20     
  
  LDI   R20, (1 << OCF0A)
  OUT   TIFR0, R20     
RET

                  ; podprogram za pretvorbo vrednosti v ASCII
decimal_ascii:
  LDI R17, 0
  PUSH R19
  LDI R19, 48
  first:
  CPI R16, 10
  BRLO disp
  SUBI R16, 10
  INC R17
  RJMP first
  disp:
  PUSH R16
  ADD R17, R19
  MOV R16, R17
  RCALL data_wrt
  
  POP R16
  ADD R16, R19
  RCALL data_wrt
  POP R19
RET
