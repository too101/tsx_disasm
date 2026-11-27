; ==============================================================================
; TESTTSX.COM — ทดสอบ INT 69h API ของ THAI.COM (TSX 3.51)
;
;   แอสเซมเบิล : nasm -f bin testtsx.asm -o testtsx.com
;   เงื่อนไข   : THAI.COM ต้องติดตั้งอยู่ก่อน (เช็คจากเวกเตอร์ INT 69h = 0000:01A4h
;               ซึ่งต้องชี้ที่ offset 0C0Ch = ลายเซ็นของ hook69)
;
;   ลำดับการทดสอบ
;     1. ตรวจว่า TSX อยู่จริง            (อ่าน IVT)
;     2. ตั้งโหมด: LF เดี่ยว (AH=05h), แสดงผล 3 ระดับ (AH=04h), แป้นไทย (AH=03h)
;     3. รายงานโหมดที่อ่านได้ก่อนตั้ง      (AH=00h/01h/02h)
;     4. พิมพ์ข้อความไทย (รหัส KU) ผ่าน INT 10h AH=0Eh ให้ TSX จัดระดับ
;        - "ทุ่ง กู้ ปั้น ปู่" : สระบน วรรณยุกต์ ลิเกเจอร์ (ั+้ -> EB) และสระล่าง
;     5. AH=08h อ่านคีย์ 1 ตัว (ไม่ echo)  -> แสดงรหัส KU เป็นเลขฐานสิบหก
;     6. AH=09h อ่านคีย์ + echo (กด ESC จบ)
;     7. AH=0Ah อ่านข้อความทั้งบรรทัด     -> แสดง [จำนวน] + รหัส KU ในบัฟเฟอร์
;     8. ตรวจบั๊กที่พบจากการถอด: หลัง AH=0Ah, [disp3] ต้องยังเป็น FFh
;        แต่จะกลายเป็น 0Dh (sv_ax ถูก f0A เขียนทับ)
;     9. คืนค่าโหมดเดิม (แสดงผล 1 ระดับ + แป้นอังกฤษ) แล้วจบ
;
;   หมายเหตุ: ข้อความไทยแสดงถูกต้องต้องมีฟอนต์ไทยในการ์ดจอ/ฟอนต์โหลด
;   (บน DOSBox จะเห็นเป็นอักขระ CP437 แทน แต่กลไกการจัดระดับยังทำงานครบ)
; ==============================================================================

        org 100h

start:
; ---------- 1. ตรวจว่า TSX ติดตั้งอยู่ ----------
        xor     ax, ax
        mov     es, ax
        mov     ax, [es:0x01A4]         ; offset ของเวกเตอร์ INT 69h
        cmp     ax, 0x0C0C              ; ต้องชี้ที่ hook69
        je      inst_ok
        mov     si, m_noinst
        call    puts
        int     0x20                    ; ไม่มี TSX -> จบ (ข้อความ CR LF เอง เพราะยังไม่ผ่าน hook)

inst_ok:
; ---------- 2. อ่านโหมดปัจจุบันเก็บไว้ แล้วตั้งโหมดทดสอบ ----------
        mov     ah, 0                   ; f01: โหมดแป้นพิมพ์
        int     0x69
        push    ax
        mov     ah, 1                   ; f02: AL = disp3, AH = dlf
        int     0x69
        push    ax
        mov     ah, 2                   ; f03: โหมดเครื่องพิมพ์
        int     0x69
        push    ax

        mov     ah, 5                   ; f06: LF เดี่ยว (แบบแน่น)
        xor     dl, dl
        int     0x69
        mov     ah, 4                   ; f05: แสดงผล 3 ระดับ
        mov     dl, 0xFF
        int     0x69
        mov     ah, 3                   ; f04: แป้นพิมพ์ไทย
        mov     dl, 0xFF
        int     0x69

; ---------- 3. รายงานโหมดที่อ่านได้ก่อนตั้ง (พิมพ์ผ่าน TSX แล้ว, CR แล้ว TSX เติม LF ให้) ----------
        mov     si, m_kbd
        call    puts
        pop     ax
        call    hexb
        call    crlf
        mov     si, m_disp
        call    puts
        pop     ax
        push    ax
        call    hexb                    ; AL = disp3 เดิม
        mov     al, '/'
        call    putc
        pop     ax
        mov     al, ah                  ; AH = dlf เดิม
        call    hexb
        call    crlf
        mov     si, m_prn
        call    puts
        pop     ax
        call    hexb
        call    crlf

; ---------- 4. พิมพ์ข้อความไทยแบบ 3 ระดับ ----------
        mov     si, t_levels            ; "ทุ่ง กู้ ปั้น ปู่" (B9 DD E1 -> merge เป็น EB)
        call    puts
        call    crlf                    ; เว้น 2 แถว เพื่อไม่ให้บรรทัดถัดไปทับสระบน/ล่าง
        call    crlf
        mov     si, t_plain             ; "ทดสอบการแสดงผลสามระดับ"
        call    puts

; ---------- 5. AH=08h: อ่านคีย์ 1 ตัว ไม่แสดงผล ----------
        mov     si, m_read8
        call    puts
        mov     ah, 8
        int     0x69
        push    ax
        mov     si, m_code
        call    puts
        pop     ax
        call    hexb
        call    crlf

; ---------- 6. AH=09h: อ่านคีย์ + echo จนกด ESC ----------
        mov     si, m_read9
        call    puts
keyloop:
        mov     ah, 9
        int     0x69                    ; AL = รหัส KU (echo ให้แล้วโดย TSX)
        cmp     al, 0x1B                ; ESC ?
        je      keydone
        push    ax
        mov     si, m_code
        call    puts
        pop     ax
        call    hexb
        call    crlf
        jmp     keyloop
keydone:
        call    crlf

; ---------- 7. AH=0Ah: อ่านข้อความทั้งบรรทัด ----------
        mov     si, m_readA
        call    puts
        mov     dx, buf
        mov     ah, 0x0A
        int     0x69                    ; f0B: อ่านจน ENTER (บังคับแสดงผล 3 ระดับระหว่างพิมพ์)

; ---------- 8. ตรวจบั๊ก disp3 ----------
        mov     ah, 1
        int     0x69                    ; f02: AL = [disp3] หลังอ่านบรรทัด
        push    ax
        mov     si, m_after
        call    puts
        pop     ax
        call    hexb
        mov     si, m_bug
        call    puts

; ---------- แสดงข้อมูลในบัฟเฟอร์: [จำนวน] ตามด้วยรหัส KU .. CR ----------
        mov     si, m_buf
        call    puts
        mov     bx, buf
        xor     cx, cx
        mov     cl, [bx]
        mov     al, cl
        call    hexb
        mov     al, ':'
        call    putc
        inc     bx
bufloop:
        mov     al, [bx]
        call    hexb
        mov     al, ' '
        call    putc
        inc     bx
        loop    bufloop
        call    crlf

; ---------- 9. คืนค่าโหมด แล้วจบ ----------
        mov     ah, 4                   ; f05: แสดงผล 1 ระดับ
        xor     dl, dl
        int     0x69
        mov     ah, 3                   ; f04: แป้นพิมพ์อังกฤษ
        xor     dl, dl
        int     0x69
        mov     si, m_done
        call    puts
        int     0x20

; ============================== subroutines ==============================
; puts: พิมพ์สตริงที่ DS:SI (จบด้วย 0) ทีละตัวด้วย INT 10h AH=0Eh ผ่าน TSX
puts:   lodsb
        or      al, al
        jz      puts_r
        call    putc
        jmp     puts
puts_r: ret

; putc: พิมพ์ AL ด้วย teletype (ผ่าน hook INT 10h ของ TSX)
putc:   push    ax
        push    bx
        push    cx
        mov     ah, 0x0E
        mov     bx, 0x0007
        int     0x10
        pop     cx
        pop     bx
        pop     ax
        ret

; crlf: ส่งเพียง CR — ในโหมด 3 ระดับ TSX เติม LF ให้เองแล้ว
crlf:   mov     al, 0x0D
        call    putc
        ret

; hexb: พิมพ์ AL เป็นเลขฐานสิบหก 2 หลัก
hexb:   push    ax
        shr     al, 1
        shr     al, 1
        shr     al, 1
        shr     al, 1
        call    hexd
        pop     ax
        and     al, 0x0F
        call    hexd
        ret
hexd:   cmp     al, 10
        jb      hexd_d
        add     al, 'A'-'0'-10
hexd_d: add     al, '0'
        call    putc
        ret

; ============================== messages ==============================
m_noinst: db 'THAI.COM (TSX) is not resident - run THAI.COM first.', 13, 10, 0
m_hello:  db 'TSX resident: INT 69h vector = xxxx:0C0C - ok', 13, 0
m_kbd:    db 'kbd  mode was 0x', 0
m_disp:   db 'disp mode was 0x', 0
m_prn:    db 'prn  mode was 0x', 0
m_read8:  db 'AH=08h read 1 key (no echo) - press a key:', 13, 0
m_read9:  db 'AH=09h read+echo - type keys, ESC ends:', 13, 0
m_readA:  db 'AH=0Ah line read - type Thai text then ENTER:', 13, 0
m_code:   db '  code = 0x', 0
m_after:  db 'disp3 after AH=0Ah = 0x', 0
m_bug:    db '  (known bug: expected FFh)', 13, 0
m_buf:    db 'buffer: [count]=', 0
m_done:   db 'Restored 1-level display + English keyboard. Test done.', 13, 0

; ============================== ข้อความไทย (รหัส KU) ==============================
; "ทุ่ง กู้ ปั้น ปู่"  — สระล่าง วรรณยุกต์ ลิเกเจอร์ สระล่าง
;   ทุ่ง = B5 D7 E0 A5   กู้ = A1 D8 E1   ปั้น = B9 DD E1 B7 (ั+้ -> EB โดย merge)   ปู่ = B9 D8 E0
t_levels: db 0xB5, 0xD7, 0xE0, 0xA5, ' ', 0xA1, 0xD8, 0xE1, ' ', 0xB9, 0xDD, 0xE1, 0xB7, ' ', 0xB9, 0xD8, 0xE0, 13, 0
; "ทดสอบการแสดงผลสามระดับ"
t_plain:  db 0xB5, 0xB2, 0xC7, 0xCA, 0xB8, 0xA1, 0xCE, 0xC1, 0xD1, 0xC7, 0xB2, 0xA5, 0xBA, 0xC3
          db 0xC7, 0xCE, 0xBF, 0xC1, 0xCC, 0xB2, 0xDD, 0xB8, 13, 0

buf:      times 256 db 0
