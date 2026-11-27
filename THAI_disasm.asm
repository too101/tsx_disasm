;
; ##############################################################################
;  THAI.COM  —  TSX (Thai System Extensions)  v3.51
;  ส่วนที่อยู่ถาวรในหน่วยความจำ (TSR) ของระบบจัดการภาษาไทย "รหัสเกษตร" (KU code)
;  สำหรับ IBM PC / XT / PCjr  —  คณะวิศวกรรมศาสตร์ มหาวิทยาลัยเกษตรศาสตร์  Copyright 1984
;  บทความประกอบ: ไมโครคอมพิวเตอร์ ฉบับ 21/2529 หน้า 93-97 (อธิบาย TSX รุ่น 3.52)
; ------------------------------------------------------------------------------
;  ต้นฉบับ : THAI.COM  5,298 ไบต์   md5 d4db5c5ddd4bfc4bdeed613ba632bcc9
;  วิธีได้มา: ถอดด้วย capstone (โหมด 16 บิต) แล้วใส่ชื่อ label และคำอธิบายจากการไล่โค้ดทีละ routine
;  รูปแบบ  : syntax ของ NASM (org 100h, cpu 186) — ทุกไบต์ของไฟล์ถูกแสดงครบพร้อมที่อยู่และค่าฐานสิบหก
;            แอสเซมเบิลกลับด้วย NASM 3.02 (-f bin) ได้ไบนารีตรงกับ THAI.COM ทุกไบต์ (5,298 ไบต์)
;            หมายเหตุ: คำสั่ง reg-reg 10 จุดที่ต้นฉบับใช้รูป RM ถูกคงไว้เป็น db (NASM emit รูป MR)
;
;  ทำอะไร  : ดัก 3 interrupt ของ BIOS และเปิด API ผ่าน INT 69h
;    INT 16h (AH=00h)     อ่านคีย์: ALT+F1..F10 = คีย์ลัด ; โหมดไทยแปล ASCII -> รหัส KU
;    INT 10h (AH=09h,0Eh) แสดงผล 3 ระดับ (สระบน/วรรณยุกต์พิมพ์ที่แถวบน สระล่างที่แถวล่าง)
;                          และรับคำสั่งด้วยรหัส 80h..85h
;    INT 17h (AH=00h)     พิมพ์ 3 ระดับ (หนึ่งบรรทัดข้อความ = 3 แถวพิมพ์ซ้อนกัน)
;    INT 69h              API (AH = หมายเลขฟังก์ชัน 00h..0Ah — ตัวจัดการบวก 1 แล้วค้นตาราง fntab)
;
;  ผังหน่วยความจำ (ที่อยู่เมื่อโหลดเป็น .COM ที่ PSP:0100h):
;    0100h  จุดเข้า (jmp install)                    05C5h  hook INT 16h + คีย์ลัด + รหัสสั่งเครื่องพิมพ์
;    0104h  ตัวแปรสถานะ (ถึง 0119h)                   07C9h  hook INT 10h + แสดงผล 3 ระดับ
;    011Ah  ktbl  ASCII -> KU (80h ไบต์)               0A68h  hook INT 17h + พิมพ์ 3 ระดับ
;    019Ah  lvl_u/lvl_m/lvl_l บัฟเฟอร์พิมพ์ (×100h)     0BD6h  พื้นที่เซฟรีจิสเตอร์ + fntab
;    049Ah  lbuf  บัฟเฟอร์บรรทัดจอภาพ (FFh ไบต์)       0C0Ch  hook INT 69h + ฟังก์ชัน
;    0599h  keytab  ALT+Fn (รายการละ 4 ไบต์)            0DF8h  banner + cmdlist + ข้อความเมนู
;                                                           14DAh  install (ถูกทิ้งหลัง INT 27h)
;
;   INT 69h  (AH = หมายเลขฟังก์ชัน, DL = พารามิเตอร์ — ตัวจัดการบวก AH ด้วย 1 แล้วค้นตาราง fntab):
;     AH   routine  ความหมาย
;     00h  f01      อ่านโหมดแป้นพิมพ์    -> AL = 00h อังกฤษ / FFh ไทย
;     01h  f02      อ่านโหมดแสดงผล      -> AL = 00h 1 ระดับ / FFh 3 ระดับ ; AH = 00h LF เดี่ยว / FFh LF คู่
;     02h  f03      อ่านโหมดเครื่องพิมพ์  -> AL = 00h 1 ระดับ / FFh 3 ระดับ
;     03h  f04      ตั้งโหมดแป้นพิมพ์    DL = 00h อังกฤษ / FFh หรือ 01h ไทย (พร้อมตั้งรูปเคอร์เซอร์)
;     04h  f05      ตั้งโหมดแสดงผล      DL = 00h 1 ระดับ / FFh หรือ 01h 3 ระดับ
;     05h  f06      จำนวนบรรทัด         DL = 00h LF เดี่ยว / FFh หรือ 01h LF คู่ (สลับจอ 8&12 บรรทัด)
;     06h  f07      ตั้งโหมดเครื่องพิมพ์  DL = FFh หรือ 01h -> 3 ระดับ ; DL = 00h -> ส่งรหัสระยะบรรทัด 1 ระดับ
;                                 (แต่โหมดยังเป็น 3 ระดับเพราะค่าที่เขียนที่ prn1_init เป็น FFh)
;     07h  f08      เลือกชนิดเครื่องพิมพ์ DL = 0 FX100 / 1 CITOH / 2 LQ1500
;     08h  f09      อ่านคีย์ (ไม่แสดงผล)  -> AL = รหัส KU, AH = scan code
;     09h  f0A      อ่านคีย์ + แสดงผล     -> AL = รหัส KU
;     0Ah  f0B      อ่านข้อความ 1 บรรทัด  DS:DX = บัฟเฟอร์ ([0] = จำนวน, ตามด้วยรหัส KU .. CR)
;     (03h..07h : ค่า DL นอกเหนือจากที่ระบุ = ไม่เปลี่ยนค่าเดิม) ; AH ตั้งแต่ 0Bh ขึ้นไป = ไม่ทำอะไร
;
;  INT 10h (AH=09h/0Eh) เมื่อ AL = รหัสคำสั่ง:  80h แสดงผล 1 ระดับ | 81h โหมดอังกฤษ | 82h แสดงผล 3 ระดับ
;                                         83h โหมดไทย | 84h พิมพ์ 1 ระดับ | 85h พิมพ์ 3 ระดับ
;  ALT+F1..F10 (ลำดับเดียวกัน): 1 ระดับจอ, อังกฤษ, 3 ระดับจอ, ไทย, 1 ระดับพิมพ์, 3 ระดับพิมพ์,
;                              สลับจอโมโน/สี, สลับ 8/12 บรรทัด, ตัวอักษรปกติ, ตัวอักษรหนาแน่น
;
;  รหัสภาษาไทย (KU code) ที่ใช้ภายในและแสดงผล — เรียงตามลำดับพจนานุกรม:
;         0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
;    Ah         ก   ข   ค   ฆ   ง   จ   ฉ   ช   ซ   ฌ   ฎ   ฏ   ฐ   ฑ   ฒ
;    Bh     ?   ณ   ด   ต   ถ   ท   ธ   น   บ   ป   ผ   ฝ   พ   ฟ   ภ   ม
;    Ch     ย   ร   ฤ   ล   ว   ศ   ษ   ส   ห   ฬ   อ   ฮ   ะ   ?   า   ำ
;    Dh     เ   แ   โ   ใ   ไ   ๆ   ?  ◌ุ  ◌ู  ◌ิ  ◌ี  ◌ึ  ◌ื  ◌ั   ?   ?
;    Eh    ◌่  ◌้  ◌๊  ◌๋  ◌์                                            
;         E6h..FEh = ตัวอักษรประกอบ วรรณยุกต์ x สระบน (ดู merge)   EBh = ั้ (พิมพ์ตรงได้ด้วยปุ่ม '&')
;    ลำดับสเกลใน merge: [DEh] +06h  ิ +0Eh  ั +0Ah  ี +13h  ึ +17h  ื +1Bh  (เช่น ่+ี = F3h, ้+ั = EBh)
;  หลักฐาน: ตัวอักษร 27 ตัวยืนยันได้ตรงๆ จากข้อความไทยใน banner; ที่เหลืออนุมานจากตำแหน่งปุ่มบนแป้นพิมพ์ดีด
;    ไทยแบบ Kedmanee (แถวอักษรของ ktbl ตรงกันเกือบทั้งหมด) ร่วมกับลำดับพจนานุกรม และตารางลิเกเจอร์ของ merge
;    '?' = ไม่ทราบแน่ชัด: B0h (Shift+','), CDh (ไม่มีปุ่ม), D6h (Shift+O),
;            DEh (ไม่มีปุ่ม) กับ DFh (Shift+H) = ็ และ ํ แต่ไม่ปรากฏว่าตัวไหนเป็นตัวไหน
;    หมายเหตุ: ตาราง KU2STD.H ใน github.com/kytulendu/STUFF ให้ค่าต่างจากไฟล์นี้ (เช่น A3h: ไฟล์นี้ = ค
;      แต่ตารางนั้น = ง , B9h: ไฟล์นี้ = ป แต่ตารางนั้น = ไ) — ตารางข้างต้นมาจาก THAI.COM โดยตรง
;    แถวล่างของ ktbl ต่างจาก Kedmanee: x=ป c=แ v=อ b=ิ n=ื m=ท ,=ม .=ใ /=ฝ
;
;  ข้อสังเกตที่พบจากการถอด:
;    1. ใช้ opcode 83h /r ที่ tbl_find และ fn_find — เป็นคำสั่งของ 80186 ขึ้นไป ทั้งที่แบนเนอร์เขียนว่า PC/XT/PCjr
;       บน 8086/8088 แท้ opcode 83h ทำงานเหมือน 81h ทำให้การค้นตารางผิดพลาด
;    2. ที่ prn1_init (0D26h) เขียน [prn3]=FFh ทั้งที่เส้นทางนี้คือ "พิมพ์ 1 ระดับ" (น่าจะตั้งใจเป็น 00h)
;       ผลคือ INT 69h AH=07h DL=00h ไม่ได้เปลี่ยนเป็นพิมพ์ 1 ระดับจริง และ AH=08h จะดันโหมดเป็น 3 ระดับ
;       ถ้าเดิมอยู่ในโหมด 1 ระดับ
;    3. รายการ COMMAND 134-137 (เลือกความกว้าง 80/132/160/256 คอลัมน์) มีข้อความแต่ไม่มีโค้ดรองรับ
;       ความกว้างถูกตั้งไว้คงที่ 132 คอลัมน์ ([pwid]=131)
;    4. หมายเลขฟังก์ชัน (AH) ตรงกับตารางในบทความ (3.52) ตั้งแต่ 00h..07h เพราะตัวจัดการบวก AH ด้วย 1 ก่อนค้น
;       fntab; ส่วนท้ายต่างกันหนึ่งตำแหน่ง: ไฟล์นี้ 08h อ่านคีย์, 09h อ่านคีย์+แสดงผล, 0Ah อ่านบรรทัด,
;       0Bh ไม่มีฟังก์ชัน — ส่วนบทความระบุ 08h อ่านรหัสคีย์ ALT+Fn, 09h อ่านคีย์, 0Ah อ่านคีย์+แสดงผล,
;       0Bh อ่านบรรทัด (น่าจะมีการเพิ่มฟังก์ชันใน 3.52)
;    5. hook10 กับ AH=09h ไม่เลื่อนเคอร์เซอร์หลังพิมพ์ (ใช้ได้จริงกับ AH=0Eh ซึ่ง DOS ใช้)
;    6. โค้ด/ข้อมูลที่ไม่ถูกใช้: cur_right, cur_row, cur_col, pad114 และไบต์ 90h ท้ายบัฟเฟอร์พิมพ์แต่ละอัน
;       (เป็นค่าที่ปรากฏในไฟล์ ไม่มีโค้ดอ่าน)
;    7. คีย์ลัด ALT+Fn ถูกกล้น (ไม่ส่งให้โปรแกรม) และมีเสียงบี๊บทุกครั้งที่กด
;    8. INT 69h AH=0Ah: ค่า [disp3] เดิมที่เขียนเก็บไว้ที่ sv_ax ก่อนวนอ่านถูก f0A เขียนทับด้วย AX ของ
;       คีย์ล่าสุดทุกครั้ง เมื่อจบฟังก์ชันจึงอ่าน sv_ax กลับมาได้ AL = 0Dh (CR) แล้วใส่กลับ [disp3] —
;       โหมดการแสดงผลเดิมจึงหายไป (0Dh ทำให้ hook10 แสดงผลแบบ 1 ระดับ) และ AX ที่ผู้เรียกได้รับกลับ
;       คือ scan code : 0Dh ของ ENTER แทนค่าเดิม
;    9. บทความระบุคู่ค่าจำนวนบรรทัดว่า AH=00h -> 8 บรรทัด, FFh -> 12 บรรทัด ซึ่งกลับข้างกับตรรกะ LF ใน
;       ไฟล์นี้ (dlf=FFh พิมพ์ LF เพิ่ม = เว้นแถวมากขึ้น = บรรทัดต่อจอน้อยลง) — น่าจะต่างกันเพราะคนละเวอร์ชัน
;   10. การลบ (Backspace) ไม่ทำงานระหว่าง AH=0Ah อ่านบรรทัด: f0A เรียก putc3_store โดยตรง (ข้าม
;       dispatch ของ putc3) BS จึงถูกเก็บเป็นไบต์ 08 ใน lbuf และนับในจำนวนตัวอักษร — ตรวจสอบด้วย
;       emulator แล้ว (lbuf = B5 B2 C7 CA B8 08 0D, count=7) — routine ลบ backspace/bs_lower/bs_upper
;       ทำงานเฉพาะเส้นทางแสดงผล: โปรแกรมพิมพ์ BS เองผ่าน INT 10h AH=09h/0Eh เท่านั้น (ลบลง lbuf+จอ
;       แบบ 3 ระดับครบ: ลบ ุ/ู ที่แถวล่าง, ลบสระบน/ลิเกเจอร์ที่แถวบนพร้อมคืนสระที่ซ้อนอยู่ข้างใต้)
; ##############################################################################

        cpu 186
        org 100h

; จุดเข้าของ .COM: ข้ามไปยังส่วนติดตั้งที่ท้ายไฟล์ (ส่วนนั้นไม่ต้องคงไว้หลัง INT 27h)
    jmp near install                                  ; 0100  E9 D7 13
    nop                                               ; 0103  90
;
; ---- ตัวแปรสถานะของ TSR (ค่าเริ่มต้นตอนโหลด) ----
prn_type  db 0x01           ; 0104  ชนิดเครื่องพิมพ์ : 0 = FX100 , 1 = CITOH , 2 = LQ1500 (ค่าเริ่มต้น 1)
kbd_mode  db 0x00           ; 0105  โหมดแป้นพิมพ์ : 00h = อังกฤษ (ไม่แปลรหัส) , FFh = ไทย (ASCII -> KU)
disp3  db 0x00              ; 0106  การแสดงผล : 00h = 1 ระดับ (ส่งตรงให้ BIOS) , FFh = 3 ระดับ (putc3)
dlf  db 0x00                ; 0107  00h = LF เดี่ยว (12 บรรทัด/จอ) , FFh = LF คู่ (8 บรรทัด/จอ)
mono  db 0x00               ; 0108  ชนิดจอ (รูปเคอร์เซอร์) : 00h = จอสี (บรรทัดสแกน 5-6) , FFh = จอโมโน (9-10)
noskip  db 0x00             ; 0109  FFh = ปิดกฎเว้นวรรค 3 ครั้งหลังสระบน (space_skip) — ถูกสลับทุกครั้งที่กด Backspace
col  db 0x00                ; 010A  เลขคอลัมน์ปัจจุบันของบรรทัดบนจอ (ใช้ตัดบรรทัดที่ 80)
spc3  db 0x00               ; 010B  จำนวนเว้นวรรคติดกันหลังสระบน (space_skip)
tspc  db 0x00               ; 010C  จำนวนเว้นวรรคติดกันในโหมดไทย (ครบ 3 -> A0h)
upr  db 0x00                ; 010D  จำนวนสระบน/วรรณยุกต์ที่พิมพ์แล้วในคอลัมน์ปัจจุบัน
blen  db 0x00               ; 010E  จำนวนไบต์ที่เก็บใน lbuf
upc  db 0x00                ; 010F  สระบน/วรรณยุกต์ตัวล่าสุดของคอลัมน์ (ใช้ใน merge)
pspc  db 0x00               ; 0110  จำนวนเว้นวรรคติดกันของเครื่องพิมพ์ (p_space)
prn3  db 0x00               ; 0111  โหมดเครื่องพิมพ์ : 00h = 1 ระดับ (ส่งตรงให้ BIOS) , FFh = 3 ระดับ
pmark  db 0x00              ; 0112  จำนวนสระบน/ล่างที่พบในคำปัจจุบัน (เครื่องพิมพ์)
ppos  db 0x00               ; 0113  ตำแหน่งคอลัมน์ปัจจุบันในบัฟเฟอร์เครื่องพิมพ์
pad114  db 0x50             ; 0114  ไม่มีโค้ดอ้างถึง (ค่า 50h = 80 เหลืออยู่ในไฟล์)
pwid  db 0x83               ; 0115  ความกว้างบรรทัดของเครื่องพิมพ์ = 131 (132 คอลัมน์) — ไม่มีโค้ดเปลี่ยนค่า
pbuf  dw 0x0000             ; 0116  บัฟเฟอร์ระดับที่กำลังใช้ (lvl_u / lvl_m / lvl_l)
cur_row  db 0x00            ; 0118  ตำแหน่งเคอร์เซอร์ล่าสุด — ถูกเขียนใน putc_norm แต่ไม่มีโค้ดอ่าน
cur_col  db 0x00            ; 0119
;
; ---- ktbl: ตาราง XLAT แปลรหัสจากแป้นพิมพ์ ASCII -> รหัส KU  (ใช้เมื่อ [kbd_mode]=FFh โหมดไทย) ----
;     ดัชนี = รหัส ASCII ของคีย์  (00h..20h คงค่าเดิม, 7Ch..FFh -> 20h)
;
;     คีย์      -> KU    ตัวอักษร        คีย์      -> KU    ตัวอักษร
;     '!' -> 2Eh '.'                   '"' -> 5Fh '_'                
;     '#' -> 32h '2'                   '$' -> 33h '3'                
;     '%' -> 34h '4'                   '&' -> EBh ั้                 
;     ''' -> A5h ง                     '(' -> 36h '6'                
;     ')' -> 37h '7'                   '*' -> 35h '5'                
;     '+' -> 39h '9'                   ',' -> BFh ม                  
;     '-' -> A2h ข                     '.' -> D3h ใ                  
;     '/' -> BBh ฝ                     '0' -> A6h จ                  
;     '1' -> C3h ล                     '2' -> 2Dh '-'                
;     '3' -> 2Fh '/'                   '4' -> BEh ภ                  
;     '5' -> B4h ถ                     '6' -> D7h ◌ุ                 
;     '7' -> DBh ◌ึ                    '8' -> A3h ค                  
;     '9' -> B3h ต                     ':' -> A9h ซ                  
;     ';' -> C4h ว                     '<' -> B0h ?                  
;     '=' -> A8h ช                     '>' -> C9h ฬ                  
;     '?' -> 20h ' '                   '@' -> 31h '1'                
;     'A' -> C2h ฤ                     'B' -> 3Fh '?'                
;     'C' -> A7h ฉ                     'D' -> ADh ฐ                  
;     'E' -> ACh ฏ                     'F' -> D2h โ                  
;     'G' -> AAh ฌ                     'H' -> DFh ?                  
;     'I' -> B1h ณ                     'J' -> E3h ◌๋                 
;     'K' -> C6h ษ                     'L' -> C5h ศ                  
;     'M' -> 2Ch ','                   'N' -> E4h ◌์                 
;     'O' -> D6h ?                     'P' -> ABh ฎ                  
;     'Q' -> 30h '0'                   'R' -> AFh ฒ                  
;     'S' -> A4h ฆ                     'T' -> B6h ธ                  
;     'U' -> E2h ◌๊                    'V' -> CBh ฮ                  
;     'W' -> 22h '"'                   'X' -> 29h ')'                
;     'Y' -> 25h '%'                   'Z' -> 28h '('                
;     '[' -> B8h บ                     '\' -> (คงเดิม)               
;     ']' -> C3h ล                     '^' -> D8h ◌ู                 
;     '_' -> 38h '8'                   '`' -> 20h ' '                
;     'a' -> BDh ฟ                     'b' -> D9h ◌ิ                 
;     'c' -> D1h แ                     'd' -> A1h ก                  
;     'e' -> CFh ำ                     'f' -> B2h ด                  
;     'g' -> D0h เ                     'h' -> E1h ◌้                 
;     'i' -> C1h ร                     'j' -> E0h ◌่                 
;     'k' -> CEh า                     'l' -> C7h ส                  
;     'm' -> B5h ท                     'n' -> DCh ◌ื                 
;     'o' -> B7h น                     'p' -> C0h ย                  
;     'q' -> D5h ๆ                     'r' -> BCh พ                  
;     's' -> C8h ห                     't' -> CCh ะ                  
;     'u' -> DAh ◌ี                    'v' -> CAh อ                  
;     'w' -> D4h ไ                     'x' -> B9h ป                  
;     'y' -> DDh ◌ั                    'z' -> BAh ผ                  
;     '{' -> AEh ฑ                     '|' -> 20h ' '                
ktbl:
    db 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F ; 011A  ................
    db 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F ; 012A  ................
    db 0x20, 0x2E, 0x5F, 0x32, 0x33, 0x34, 0xEB, 0xA5, 0x36, 0x37, 0x35, 0x39, 0xBF, 0xA2, 0xD3, 0xBB ; 013A  ................
    db 0xA6, 0xC3, 0x2D, 0x2F, 0xBE, 0xB4, 0xD7, 0xDB, 0xA3, 0xB3, 0xA9, 0xC4, 0xB0, 0xA8, 0xC9, 0x20 ; 014A  ................
    db 0x31, 0xC2, 0x3F, 0xA7, 0xAD, 0xAC, 0xD2, 0xAA, 0xDF, 0xB1, 0xE3, 0xC6, 0xC5, 0x2C, 0xE4, 0xD6 ; 015A  ................
    db 0xAB, 0x30, 0xAF, 0xA4, 0xB6, 0xE2, 0xCB, 0x22, 0x29, 0x25, 0x28, 0xB8, 0x5C, 0xC3, 0xD8, 0x38 ; 016A  ................
    db 0x20, 0xBD, 0xD9, 0xD1, 0xA1, 0xCF, 0xB2, 0xD0, 0xE1, 0xC1, 0xE0, 0xCE, 0xC7, 0xB5, 0xDC, 0xB7 ; 017A  ................
    db 0xC0, 0xD5, 0xBC, 0xC8, 0xCC, 0xDA, 0xCA, 0xD4, 0xB9, 0xDD, 0xBA, 0xAE, 0x20, 0x20, 0x20, 0x20 ; 018A  ................
;     (หลัง 0196h เป็น 20h จนครบตาราง)
;
; ---- บัฟเฟอร์ 3 ระดับสำหรับเครื่องพิมพ์ (แต่ละอัน 100h ไบต์) ----
lvl_u:
    times 0FFh db 0x20                                    ; 019A  ระดับบน   : สระบน / วรรณยุกต์  — พิมพ์เป็นแถวแรก
    db 0x90                 ; 0299  ค่าในไฟล์ — ไม่มีโค้ดอ่าน (p_clear เขียนทับเป็น 20h)
lvl_m:
    times 0FFh db 0x20                                    ; 029A  ระดับกลาง : พยัญชนะ สระ ตัวเลข  — พิมพ์เป็นแถวที่สอง
    db 0x90                 ; 0399  ค่าในไฟล์ — ไม่มีโค้ดอ่าน (p_clear เขียนทับเป็น 20h)
lvl_l:
    times 0FFh db 0x20                                    ; 039A  ระดับล่าง  : ุ ู               — พิมพ์เป็นแถวที่สาม
    db 0x90                 ; 0499  ค่าในไฟล์ — ไม่มีโค้ดอ่าน (p_clear เขียนทับเป็น 20h)
;
; ---- lbuf: บัฟเฟอร์บรรทัดของจอภาพ (เก็บตัวอักษรที่พิมพ์ในบรรทัดปัจจุบันตามลำดับ) ----
lbuf:
    times 0FFh db 0x20                                   ; 049A
;
; ---- keytab: ALT+Fn -> routine  (หาโดย tbl_find; รายการละ dw scan code, dw routine) ----
keytab:
    dw 0x6800               ; 0599  ALT+F1  (AX: AL=00h, AH=scan code 68h)
    dw fn_disp1
    dw 0x6900               ; 059D  ALT+F2  (AX: AL=00h, AH=scan code 69h)
    dw fn_english
    dw 0x6A00               ; 05A1  ALT+F3  (AX: AL=00h, AH=scan code 6Ah)
    dw fn_disp3
    dw 0x6B00               ; 05A5  ALT+F4  (AX: AL=00h, AH=scan code 6Bh)
    dw fn_thai
    dw 0x6C00               ; 05A9  ALT+F5  (AX: AL=00h, AH=scan code 6Ch)
    dw fn_prn1
    dw 0x6D00               ; 05AD  ALT+F6  (AX: AL=00h, AH=scan code 6Dh)
    dw fn_prn3
    dw 0x6E00               ; 05B1  ALT+F7  (AX: AL=00h, AH=scan code 6Eh)
    dw fn_mono
    dw 0x6F00               ; 05B5  ALT+F8  (AX: AL=00h, AH=scan code 6Fh)
    dw fn_lines
    dw 0x7000               ; 05B9  ALT+F9  (AX: AL=00h, AH=scan code 70h)
    dw fn_prn_norm
    dw 0x7100               ; 05BD  ALT+F10  (AX: AL=00h, AH=scan code 71h)
    dw fn_prn_cond
    dw 0x0000               ; 05C1  (จบตาราง)
    dw key_none
; ============================== hook INT 16h ===============================
; hook16_jmp: ส่งต่อไปยัง INT 16h ตัวเดิมของ BIOS — เวกเตอร์เดิม (segment:offset) ถูกเก็บไว้ที่
;             old16_vec ซึ่งเป็น operand ของคำสั่ง jmp นี้เอง (setup เขียนทับตอนติดตั้ง)
hook16_jmp:
    jmp 0:0                                           ; 05C5  EA 00 00 00 00
old16_vec equ hook16_jmp+1
; hook16: ดักเฉพาะ AH=00h (อ่านคีย์และรอ) ส่วน AH อื่น (01h, 02h, 10h ...) ส่งต่อ BIOS ทันที
;         => โปรแกรมที่อ่านคีย์ด้วย AH=01h/10h จะได้คีย์ดิบโดยไม่ผ่านการแปลของ TSX
hook16:
    sti                                               ; 05CA  FB
    cmp ah, 0                                         ; 05CB  80 FC 00
    jne hook16_jmp                                    ; 05CE  75 F5
    push ds                                           ; 05D0  1E
    push bx                                           ; 05D1  53
    push cx                                           ; 05D2  51
    push dx                                           ; 05D3  52
    push es                                           ; 05D4  06
    push di                                           ; 05D5  57
    call kbd_read                                     ; 05D6  E8 07 00
    pop di                                            ; 05D9  5F
    pop es                                            ; 05DA  07
    pop dx                                            ; 05DB  5A
    pop cx                                            ; 05DC  59
    pop bx                                            ; 05DD  5B
    pop ds                                            ; 05DE  1F
    iret                                              ; 05DF  CF
; kbd_read: อ่านคีย์ 1 ตัวจาก BIOS แล้วประมวลผล (AX = AH:scan code, AL:รหัส ASCII)
;   ALT+Fn (AL=00)      : เรียก routine ตามตาราง keytab, บี๊ป แล้วอ่านคีย์ใหม่ — คีย์ถูกกลืน
;                         (routine ปิดท้ายด้วย STC ; ไม่พอคีย์ รายการปิดท้ายของตารางชี้ไป key_none ล้าง CF)
;   ENTER / รหัส < 20h  : ส่งคืนเดิม พร้อมล้างตัวนับเว้นวรคภาษาไทย (tspc)
;   SPACE (โหมดไทย)    : เว้นวรรคที่ 3 ติดกันให้รหัส A0h แทน 20h  (ดู thai_space)
;   โหมดไทย            : แปล ASCII -> รหัส KU ด้วย XLAT จากตาราง ktbl ; โหมดอังกฤษ : ส่งคืนเดิม
kbd_read:
    push cs                                           ; 05E0  0E
    pop ds                                            ; 05E1  1F
kbd_again:
    call bios_key                                     ; 05E2  E8 31 00
    cmp al, 0xd                                       ; 05E5  3C 0D   ; ENTER ?
    je key_done                                       ; 05E7  74 24
    push bx                                           ; 05E9  53
    push si                                           ; 05EA  56
    mov si, keytab                                    ; 05EB  BE 99 05   ; SI = keytab ; เทียบ AX ทั้ง word (AL=00, AH=scan code)
    call tbl_find                                     ; 05EE  E8 30 00
    call bx                                           ; 05F1  FF D3   ; BX = routine ของคีย์นี้ (key_none ถ้าไม่พบ)
    pop si                                            ; 05F3  5E
    pop bx                                            ; 05F4  5B
    jae kbd_check                                     ; 05F5  73 05   ; CF=0 : ไม่ใช่คีย์ฟังก์ชัน
    call beep                                         ; 05F7  E8 A3 01   ; CF=1 : เป็น ALT+Fn ที่จัดการแล้ว -> บี๊บ แล้วอ่านคีย์ใหม่
    jmp short kbd_again                               ; 05FA  EB E6
kbd_check:
    cmp al, 0x20                                      ; 05FC  3C 20   ; รหัสควบคุม -> ส่งคืนเดิม
    jb key_done                                       ; 05FE  72 0D
    je key_space                                      ; 0600  74 11   ; เว้นวรรค
    cmp byte [kbd_mode], 0                            ; 0602  80 3E 05 01 00   ; FFh = โหมดไทย
    je key_done                                       ; 0607  74 04
    mov bx, ktbl                                      ; 0609  BB 1A 01   ; XLAT: AL = [BX+AL]  (BX = ktbl)
    xlatb                                             ; 060C  D7
key_done:
    mov byte [tspc], 0                                ; 060D  C6 06 0C 01 00
    ret                                               ; 0612  C3
key_space:
    jmp near thai_space                               ; 0613  E9 98 01
; bios_key: เรียก INT 16h ตัวเดิม (AH=00h) ผ่านเวกเตอร์ old16_vec โดยจำลอง interrupt (pushf)
bios_key:
    push bx                                           ; 0616  53
    mov ah, 0                                         ; 0617  B4 00
    pushf                                             ; 0619  9C
    mov bx, old16_vec                                 ; 061A  BB C6 05
    call far [bx]                                     ; 061D  FF 1F
    pop bx                                            ; 061F  5B
    ret                                               ; 0620  C3
; tbl_find: หา AX ในตาราง [SI] (รายการละ dw key, dw routine)
;           หาไม่พบจะหยุดที่รายการปิดท้าย (key=0) ซึ่งชี้ไป key_none
;           หมายเหตุ: ใช้ opcode 83h /r ซึ่งเป็นคำสั่งของ 80186 ขึ้นไป — บน 8086/8088 แท้ opcode 83h
;           ทำงานเหมือน 81h (imm16) ทำให้การค้นหานี้เสีย (เช่นเดียวกับ fn_find ที่ 0C6Ah)
tbl_find:
    cmp word [si], 0                                  ; 0621  83 3C 00
    je tbl_found                                      ; 0624  74 09
    cmp ax, word [si]                                 ; 0626  3B 04
    je tbl_found                                      ; 0628  74 05
    add si, 4                                         ; 062A  83 C6 04
    jmp short tbl_find                                ; 062D  EB F2
tbl_found:
    mov bx, word [si + 2]                             ; 062F  8B 5C 02
    ret                                               ; 0632  C3
; fn_disp1: (ALT+F1 / INT 10h AL=80h) เลือกการแสดงผลแบบ 1 ระดับ — ส่งรหัสทุกตัวให้ BIOS ทีละช่องโดยไม่จัดระดับ
fn_disp1:
    mov byte [disp3], 0                               ; 0633  C6 06 06 01 00
    stc                                               ; 0638  F9
    ret                                               ; 0639  C3
; fn_disp3: (ALT+F3 / INT 10h AL=82h) เลือกการแสดงผลแบบ 3 ระดับ — สระบน/วรรณยุกต์พิมพ์ที่แถวเหนือ สระล่างที่แถวใต้
fn_disp3:
    mov byte [disp3], 0xff                            ; 063A  C6 06 06 01 FF
    stc                                               ; 063F  F9
    ret                                               ; 0640  C3
; fn_prn1: (ALT+F5 / INT 10h AL=84h) เลือกเครื่องพิมพ์แบบ 1 ระดับ แล้วสั่งระยะบรรทัดเริ่มต้นตามชนิดเครื่องพิมพ์
fn_prn1:
    mov byte [prn3], 0                                ; 0641  C6 06 11 01 00
    cmp byte [prn_type], 1                            ; 0646  80 3E 04 01 01   ; prn_type
    je prn1_citoh                                     ; 064B  74 0C
    jb prn1_fx                                        ; 064D  72 05
    call pr_esc1                                      ; 064F  E8 CB 00   ; 2 = LQ1500 -> ESC '1'
    jmp short prn1_done                               ; 0652  EB 08
prn1_fx:
    call pr_esc2                                      ; 0654  E8 D1 00   ; 0 = FX100  -> ESC '2'
    jmp short prn1_done                               ; 0657  EB 03
prn1_citoh:
    call pr_escA                                      ; 0659  E8 D7 00   ; 1 = CITOH  -> ESC 'A'
prn1_done:
    stc                                               ; 065C  F9
    ret                                               ; 065D  C3
; fn_prn3: (ALT+F6 / INT 10h AL=85h) เลือกเครื่องพิมพ์แบบ 3 ระดับ (หนึ่งบรรทัดข้อความ = 3 แถวพิมพ์ซ้อนกัน)
;          แล้วสั่งระยะบรรทัดแบบถี่ๆ ตามชนิดเครื่องพิมพ์
fn_prn3:
    mov byte [prn3], 0xff                             ; 065E  C6 06 11 01 FF
    cmp byte [prn_type], 1                            ; 0663  80 3E 04 01 01   ; prn_type
    je prn3_citoh                                     ; 0668  74 0C
    jb prn3_fx                                        ; 066A  72 05
    call pr_esc3_14                                   ; 066C  E8 CF 00   ; 2 = LQ1500 -> ESC '3' 14h
    jmp short prn3_done                               ; 066F  EB 08
prn3_fx:
    call pr_esc3_17                                   ; 0671  E8 DA 00   ; 0 = FX100  -> ESC '3' 17h
    jmp short prn3_done                               ; 0674  EB 03
prn3_citoh:
    call pr_escT16                                    ; 0676  E8 E5 00   ; 1 = CITOH  -> ESC 'T' '1' '6'
prn3_done:
    stc                                               ; 0679  F9
    ret                                               ; 067A  C3
; fn_lines: (ALT+F8) สลับ [dlf]
;           0  = LF เดี่ยว (12 บรรทัด/จอ) ; FFh = LF คู่ (8 บรรทัด/จอ — เว้นแถวว่างให้สระล่างของบรรทัดหนึ่ง
;           ไม่ทับกับสระบนของบรรทัดถัดไป)
fn_lines:
    cmp byte [dlf], 0xff                              ; 067B  80 3E 07 01 FF
    je lines_off                                      ; 0680  74 07
    mov byte [dlf], 0xff                              ; 0682  C6 06 07 01 FF
    jmp short lines_done                              ; 0687  EB 05
lines_off:
    mov byte [dlf], 0                                 ; 0689  C6 06 07 01 00
lines_done:
    stc                                               ; 068E  F9
    ret                                               ; 068F  C3
; fn_mono: (ALT+F7) สลับ [mono] แล้วตั้งรูปเคอร์เซอร์ (INT 10h AH=01h) เฉพาะเมื่ออยู่ในโหมดอังกฤษ
;          [mono]=FFh -> บรรทัดสแกน 9-10 (จอโมโน 14 เส้น) ; [mono]=0 -> บรรทัดสแกน 5-6 (จอสี 8 เส้น)
fn_mono:
    cmp byte [mono], 0                                ; 0690  80 3E 08 01 00
    je mono_set                                       ; 0695  74 16
    mov byte [mono], 0                                ; 0697  C6 06 08 01 00
    cmp byte [kbd_mode], 0xff                         ; 069C  80 3E 05 01 FF
    je mono_done                                      ; 06A1  74 1E
    mov ah, 1                                         ; 06A3  B4 01
    mov cx, 0x90a                                     ; 06A5  B9 0A 09
    call call_old10                                   ; 06A8  E8 FA 00
    jmp short mono_done                               ; 06AB  EB 14
mono_set:
    mov byte [mono], 0xff                             ; 06AD  C6 06 08 01 FF
    cmp byte [kbd_mode], 0xff                         ; 06B2  80 3E 05 01 FF
    je mono_done                                      ; 06B7  74 08
    mov ah, 1                                         ; 06B9  B4 01
    mov cx, 0x506                                     ; 06BB  B9 06 05
    call call_old10                                   ; 06BE  E8 E4 00
mono_done:
    stc                                               ; 06C1  F9
    ret                                               ; 06C2  C3
; fn_prn_norm: (ALT+F9) เลือกตัวอักษรขนาดปกติ — FX100/LQ1500: DC2 ; CITOH: ESC 'N'
fn_prn_norm:
    cmp byte [prn_type], 1                            ; 06C3  80 3E 04 01 01   ; prn_type
    je norm_citoh                                     ; 06C8  74 0C
    jb norm_fx                                        ; 06CA  72 05
    call pr_dc2                                       ; 06CC  E8 A4 00   ; 2 = LQ1500 -> DC2
    jmp short norm_done                               ; 06CF  EB 08
norm_fx:
    call pr_dc2b                                      ; 06D1  E8 A5 00   ; 0 = FX100  -> DC2
    jmp short norm_done                               ; 06D4  EB 03
norm_citoh:
    call pr_escN                                      ; 06D6  E8 A4 00   ; 1 = CITOH  -> ESC 'N'
norm_done:
    stc                                               ; 06D9  F9
    ret                                               ; 06DA  C3
; fn_prn_cond: (ALT+F10) เลือกตัวอักษรหนาแน่น (condensed) — FX100/LQ1500: DC4 ; CITOH: ESC 'Q'
fn_prn_cond:
    cmp byte [prn_type], 1                            ; 06DB  80 3E 04 01 01   ; prn_type
    je cond_citoh                                     ; 06E0  74 0C
    jb cond_fx                                        ; 06E2  72 05
    call pr_dc4                                       ; 06E4  E8 A1 00   ; 2 = LQ1500 -> DC4
    jmp short cond_done                               ; 06E7  EB 08
cond_fx:
    call pr_dc4b                                      ; 06E9  E8 A2 00   ; 0 = FX100  -> DC4
    jmp short cond_done                               ; 06EC  EB 03
cond_citoh:
    call pr_escQ                                      ; 06EE  E8 A1 00   ; 1 = CITOH  -> ESC 'Q'
cond_done:
    stc                                               ; 06F1  F9
    ret                                               ; 06F2  C3
; fn_english: (ALT+F2 / INT 10h AL=81h) เลือกโหมดแป้นพิมพ์ภาษาอังกฤษ ([kbd_mode]=0) และตั้งรูปเคอร์เซอร์ตาม [mono]
fn_english:
    mov byte [kbd_mode], 0                            ; 06F3  C6 06 05 01 00
    mov ah, 1                                         ; 06F8  B4 01   ; เคอร์เซอร์ 9-10 (โมโน)
    mov cx, 0x90a                                     ; 06FA  B9 0A 09
    cmp byte [mono], 0                                ; 06FD  80 3E 08 01 00   ; 5-6 เมื่อ [mono]=0 (จอสี)
    je eng_cursor                                     ; 0702  74 03
    mov cx, 0x506                                     ; 0704  B9 06 05
eng_cursor:
    call call_old10                                   ; 0707  E8 9B 00
    stc                                               ; 070A  F9
    ret                                               ; 070B  C3
; fn_thai: (ALT+F4 / INT 10h AL=83h) เลือกโหมดแป้นพิมพ์ภาษาไทย ([kbd_mode]=FFh)
;          รูปเคอร์เซอร์ = บล็อกเต็มช่อง (CX=000Ch : บรรทัดสแกน 0-12)
fn_thai:
    mov byte [kbd_mode], 0xff                         ; 070C  C6 06 05 01 FF
    mov ah, 1                                         ; 0711  B4 01
    mov cx, 0xc                                       ; 0713  B9 0C 00
    call call_old10                                   ; 0716  E8 8C 00
    stc                                               ; 0719  F9
    ret                                               ; 071A  C3
; key_none: ค่าเริ่มต้นเมื่อไม่พบคีย์ในตาราง — ล้าง CF แล้วกลับ (คีย์ธรรมดา)
key_none:
    clc                                               ; 071B  F8
    ret                                               ; 071C  C3
; pr_esc1: ส่ง ESC '1' ให้เครื่องพิมพ์ (LQ1500: ระยะบรรทัดแบบ 1 ระดับ)
pr_esc1:
    mov al, 0x1b                                      ; 071D  B0 1B
    call bios_print                                   ; 071F  E8 C9 03
    mov al, 0x32                                      ; 0722  B0 32
    call bios_print                                   ; 0724  E8 C4 03
    ret                                               ; 0727  C3
; pr_esc2: ส่ง ESC '2' ให้เครื่องพิมพ์ (FX100: 1 ระดับ)
pr_esc2:
    mov al, 0x1b                                      ; 0728  B0 1B
    call bios_print                                   ; 072A  E8 BE 03
    mov al, 0x32                                      ; 072D  B0 32
    call bios_print                                   ; 072F  E8 B9 03
    ret                                               ; 0732  C3
; pr_escA: ส่ง ESC 'A' ให้เครื่องพิมพ์ (CITOH: 1 ระดับ)
pr_escA:
    mov al, 0x1b                                      ; 0733  B0 1B
    call bios_print                                   ; 0735  E8 B3 03
    mov al, 0x41                                      ; 0738  B0 41
    call bios_print                                   ; 073A  E8 AE 03
    ret                                               ; 073D  C3
; pr_esc3_14: ส่ง ESC '3' 14h (LQ1500: 3 ระดับ)
pr_esc3_14:
    mov al, 0x1b                                      ; 073E  B0 1B
    call bios_print                                   ; 0740  E8 A8 03
    mov al, 0x33                                      ; 0743  B0 33
    call bios_print                                   ; 0745  E8 A3 03
    mov al, 0x14                                      ; 0748  B0 14
    call bios_print                                   ; 074A  E8 9E 03
    ret                                               ; 074D  C3
; pr_esc3_17: ส่ง ESC '3' 17h (FX100: 3 ระดับ)
pr_esc3_17:
    mov al, 0x1b                                      ; 074E  B0 1B
    call bios_print                                   ; 0750  E8 98 03
    mov al, 0x33                                      ; 0753  B0 33
    call bios_print                                   ; 0755  E8 93 03
    mov al, 0x17                                      ; 0758  B0 17
    call bios_print                                   ; 075A  E8 8E 03
    ret                                               ; 075D  C3
; pr_escT16: ส่ง ESC 'T' '1' '6' (CITOH: 3 ระดับ)
pr_escT16:
    mov al, 0x1b                                      ; 075E  B0 1B
    call bios_print                                   ; 0760  E8 88 03
    mov al, 0x54                                      ; 0763  B0 54
    call bios_print                                   ; 0765  E8 83 03
    mov al, 0x31                                      ; 0768  B0 31
    call bios_print                                   ; 076A  E8 7E 03
    mov al, 0x36                                      ; 076D  B0 36
    call bios_print                                   ; 076F  E8 79 03
    ret                                               ; 0772  C3
; pr_dc2: ส่ง DC2 (12h)
pr_dc2:
    mov al, 0x12                                      ; 0773  B0 12
    call bios_print                                   ; 0775  E8 73 03
    ret                                               ; 0778  C3
; pr_dc2b: เหมือน pr_dc2
pr_dc2b:
    call pr_dc2                                       ; 0779  E8 F7 FF
    ret                                               ; 077C  C3
; pr_escN: ส่ง ESC 'N'
pr_escN:
    mov al, 0x1b                                      ; 077D  B0 1B
    call bios_print                                   ; 077F  E8 69 03
    mov al, 0x4e                                      ; 0782  B0 4E
    call bios_print                                   ; 0784  E8 64 03
    ret                                               ; 0787  C3
; pr_dc4: ส่ง DC4 (14h)
pr_dc4:
    mov al, 0xf                                       ; 0788  B0 0F
    call bios_print                                   ; 078A  E8 5E 03
    ret                                               ; 078D  C3
; pr_dc4b: เหมือน pr_dc4
pr_dc4b:
    call pr_dc4                                       ; 078E  E8 F7 FF
    ret                                               ; 0791  C3
; pr_escQ: ส่ง ESC 'Q'
pr_escQ:
    mov al, 0x1b                                      ; 0792  B0 1B
    call bios_print                                   ; 0794  E8 54 03
    mov al, 0x51                                      ; 0797  B0 51
    call bios_print                                   ; 0799  E8 4F 03
    ret                                               ; 079C  C3
; beep: ส่งเสียงบี๊ป (BEL ผ่าน INT 10h ตัวเดิม — ไม่ผ่าน hook ของตัวเอง)
beep:
    mov al, 7                                         ; 079D  B0 07
    mov ah, 0xe                                       ; 079F  B4 0E
    call bios10                                       ; 07A1  E8 7C 00
    ret                                               ; 07A4  C3
; call_old10: เรียก INT 10h ตัวเดิมด้วย AX ปัจจุบัน (ใช้ตั้งรูปเคอร์เซอร์ AH=01h)
call_old10:
    push bx                                           ; 07A5  53
    mov bx, old10_vec                                 ; 07A6  BB E1 07
    pushf                                             ; 07A9  9C
    call far [bx]                                     ; 07AA  FF 1F
    pop bx                                            ; 07AC  5B
    ret                                               ; 07AD  C3
; thai_space: โหมดไทย — เว้นวรรคติดกันครั้งที่ 3 ให้รหัส A0h แล้วเริ่มนับใหม่ ; โหมดอังกฤษ : คืน 20h ตามปกติ
;             (A0h ทำหน้าที่เป็น "เว้นวรรคไทย" — ตอนพิมพ์ hook17 จะเปลี่ยนเป็น 20h)
thai_space:
    cmp byte [kbd_mode], 0                            ; 07AE  80 3E 05 01 00
    je ts_plain                                       ; 07B3  74 0B
    cmp byte [tspc], 2                                ; 07B5  80 3E 0C 01 02
    jae ts_a0                                         ; 07BA  73 05
    inc byte [tspc]                                   ; 07BC  FE 06 0C 01
ts_plain:
    ret                                               ; 07C0  C3
ts_a0:
    mov al, 0xa0                                      ; 07C1  B0 A0
    mov byte [tspc], 0                                ; 07C3  C6 06 0C 01 00
    ret                                               ; 07C8  C3
; ============================== hook INT 10h ===============================
; hook10: ดักเฉพาะ AH=09h (เขียนตัวอักษร+สี) และ AH=0Eh (teletype) ฟังก์ชันอื่นส่งต่อ BIOS ทันที
hook10:
    sti                                               ; 07C9  FB
    cmp ah, 9                                         ; 07CA  80 FC 09
    je hook10_go                                      ; 07CD  74 05
    cmp ah, 0xe                                       ; 07CF  80 FC 0E
    jne hook10_jmp                                    ; 07D2  75 0C
hook10_go:
    push ds                                           ; 07D4  1E
    push dx                                           ; 07D5  52
    push cx                                           ; 07D6  51
    push bx                                           ; 07D7  53
    call hook10_work                                  ; 07D8  E8 0A 00
    pop bx                                            ; 07DB  5B
    pop cx                                            ; 07DC  59
    pop dx                                            ; 07DD  5A
    pop ds                                            ; 07DE  1F
    iret                                              ; 07DF  CF
; hook10_jmp: ส่งต่อไป INT 10h ตัวเดิม (เวกเตอร์เดิมอยู่ที่ old10_vec = operand ของ jmp นี้)
hook10_jmp:
    jmp 0:0                                           ; 07E0  EA 00 00 00 00
old10_vec equ hook10_jmp+1
; hook10_work: AL = 80h..85h เป็นรหัสคำสั่ง (ดูรายการ COMMAND ในข้อความเปิดโปรแกรม) :
;     80h แสดงผล 1 ระดับ | 81h โหมดอังกฤษ | 82h แสดงผล 3 ระดับ | 83h โหมดไทย
;     84h พิมพ์ 1 ระดับ   | 85h พิมพ์ 3 ระดับ
;     (รายการ 134-137 "เลือกความกว้าง 80/132/160/256 คอลัมน์" มีข้อความอยู่ใน cmdlist แต่ไม่มีโค้ดรองรับ)
;     นอกจากนี้: [disp3]=FFh -> putc3 (จัดระดับ 3 ระดับ) ; ไม่งั้นส่งตรงให้ BIOS (bios10)
hook10_work:
    push cs                                           ; 07E5  0E
    pop ds                                            ; 07E6  1F
    cmp al, 0x80                                      ; 07E7  3C 80
    je cmd80_disp1                                    ; 07E9  74 29
    cmp al, 0x81                                      ; 07EB  3C 81
    je cmd81_english                                  ; 07ED  74 22
    cmp al, 0x82                                      ; 07EF  3C 82
    je cmd82_disp3                                    ; 07F1  74 24
    cmp al, 0x83                                      ; 07F3  3C 83
    je cmd83_thai                                     ; 07F5  74 17
    cmp al, 0x84                                      ; 07F7  3C 84
    je cmd84_prn1                                     ; 07F9  74 1F
    cmp al, 0x85                                      ; 07FB  3C 85
    je cmd85_prn3                                     ; 07FD  74 1E
    cmp byte [disp3], 0xff                            ; 07FF  80 3E 06 01 FF
    jne hook10_plain                                  ; 0804  75 04
    call putc3                                        ; 0806  E8 25 00
    ret                                               ; 0809  C3
hook10_plain:
    call bios10                                       ; 080A  E8 13 00
    ret                                               ; 080D  C3
cmd83_thai:
    jmp near fn_thai                                  ; 080E  E9 FB FE
cmd81_english:
    jmp near fn_english                               ; 0811  E9 DF FE
cmd80_disp1:
    jmp near fn_disp1                                 ; 0814  E9 1C FE
cmd82_disp3:
    jmp near fn_disp3                                 ; 0817  E9 20 FE
cmd84_prn1:
    jmp near fn_prn1                                  ; 081A  E9 24 FE
cmd85_prn3:
    jmp near fn_prn3                                  ; 081D  E9 3E FE
; bios10: เรียก INT 10h ตัวเดิมด้วย AH/AL ปัจจุบัน (CX=1 สำหรับ AH=09h) — ค่ารีจิสเตอร์เดิมถูกรักษาไว้
bios10:
    push ax                                           ; 0820  50
    push si                                           ; 0821  56
    mov cx, 1                                         ; 0822  B9 01 00
    mov si, old10_vec                                 ; 0825  BE E1 07
    pushf                                             ; 0828  9C
    call far [si]                                     ; 0829  FF 1C
    pop si                                            ; 082B  5E
    pop ax                                            ; 082C  58
    ret                                               ; 082D  C3
; putc3: แสดงตัวอักษร 1 ตัวแบบ 3 ระดับ (ทำงานเมื่อ [disp3]=FFh)
;   แนวคิด: หนึ่งบรรทัดข้อความกินหลายแถวของจอ — รหัส D9h..E4h (สระบน วรรณยุกต์ ์) พิมพ์ที่แถวถัดขึ้นไป,
;           D7h/D8h (ุ ู) พิมพ์ที่แถวถัดลงไป, นอกนั้นพิมพ์ที่แถวปัจจุบัน
;   ทุกตัวอักษรถูกเก็บลง lbuf ตามลำดับที่พิมพ์ (นำไปใช้ในฟังก์ชัน INT 69h AH=0Bh)
putc3:
    cmp al, 0xd                                       ; 082E  3C 0D   ; CR ?
    je is_cr                                          ; 0830  74 30
    cmp al, 8                                         ; 0832  3C 08   ; Backspace ?
    je is_bs                                          ; 0834  74 2F
    jb putc_ctrl                                      ; 0836  72 30   ; รหัสควบคุมอื่น -> ส่งตรงให้ BIOS
    cmp byte [col], 0x50                              ; 0838  80 3E 0A 01 50   ; คอลัมน์ >= 80 (50h hard-code) -> ขึ้นบรรทัดใหม่ก่อน
    jb putc3_store                                    ; 083D  72 03
    call newline                                      ; 083F  E8 34 00
putc3_store:
    call lbuf_put                                     ; 0842  E8 9E 00   ; เก็บลง lbuf ก่อนแยกประเภท
    cmp al, 0x20                                      ; 0845  3C 20   ; เว้นวรรค -> space_skip
    je is_space                                       ; 0847  74 16
    cmp al, 0xd9                                      ; 0849  3C D9   ; สระบน/วรรณยุกต์ -> put_upper
    jae is_upper                                      ; 084B  73 0C
    cmp al, 0xd7                                      ; 084D  3C D7   ; ุ / ู -> put_lower
    jae is_lower                                      ; 084F  73 0B
    mov byte [spc3], 0                                ; 0851  C6 06 0B 01 00
    jmp near putc_norm                                ; 0856  E9 A1 00
is_upper:
    jmp near put_upper                                ; 0859  E9 74 01
is_lower:
    jmp near put_lower                                ; 085C  E9 B5 00
is_space:
    jmp short space_skip                              ; 085F  EB 3E
    nop                                               ; 0861  90
is_cr:
    jmp short do_cr                                   ; 0862  EB 08
    nop                                               ; 0864  90
is_bs:
    jmp near backspace                                ; 0865  E9 81 01
; putc_ctrl: รหัสควบคุมอื่น (ยกเว้น CR, BS) ส่งตรงให้ BIOS
putc_ctrl:
    call bios10                                       ; 0868  E8 B5 FF
    ret                                               ; 086B  C3
; do_cr: CR — ล้างตัวนับสระบนและตัวนับเว้นวรรค แล้วขึ้นบรรทัดใหม่
do_cr:
    mov byte [upr], 0                                 ; 086C  C6 06 0D 01 00
    mov byte [spc3], 0                                ; 0871  C6 06 0B 01 00
; newline: พิมพ์ CR, LF (เพิ่มอีก LF เมื่อ [dlf]≠0 = โหมด 8 บรรทัด) แล้วล้างเลขคอลัมน์และบัฟเฟอร์บรรทัด
newline:
    push ax                                           ; 0876  50
    mov ah, 0xe                                       ; 0877  B4 0E
    mov al, 0xd                                       ; 0879  B0 0D
    call bios10                                       ; 087B  E8 A2 FF
    mov ah, 0xe                                       ; 087E  B4 0E
    mov al, 0xa                                       ; 0880  B0 0A
    call bios10                                       ; 0882  E8 9B FF
    cmp byte [dlf], 0                                 ; 0885  80 3E 07 01 00
    je no_dlf                                         ; 088A  74 07
    mov ah, 0xe                                       ; 088C  B4 0E
    mov al, 0xa                                       ; 088E  B0 0A
    call bios10                                       ; 0890  E8 8D FF
no_dlf:
    mov byte [col], 0                                 ; 0893  C6 06 0A 01 00
    mov byte [blen], 0                                ; 0898  C6 06 0E 01 00
    pop ax                                            ; 089D  58
    ret                                               ; 089E  C3
; space_skip: เว้นวรรคหลังสระบน — ถ้าพิมพ์เว้นวรรคติดกันครบ 3 ครั้ง จะพิมพ์เว้นวรรคเพิ่มอีกเท่ากับจำนวนสระบนที่
;             ค้างอยู่ ([upr]) ทีละช่อง ถึงจะล้างตัวนับ ; ปิดได้ด้วย [noskip]=FFh (ซึ่งถูกสลับทุกครั้งที่กด Backspace)
;             — เป็นกฎเดียวกับ p_space ของเครื่องพิมพ์ ที่มาของกฎนี้ไม่ปรากฏในโค้ด
space_skip:
    cmp byte [noskip], 0xff                           ; 089F  80 3E 09 01 FF
    je putc_norm                                      ; 08A4  74 54
    cmp byte [upr], 0                                 ; 08A6  80 3E 0D 01 00
    je putc_norm                                      ; 08AB  74 4D
    inc byte [spc3]                                   ; 08AD  FE 06 0B 01
    cmp byte [spc3], 3                                ; 08B1  80 3E 0B 01 03
    jae skip_loop                                     ; 08B6  73 03
    jmp short putc_norm                               ; 08B8  EB 40
    nop                                               ; 08BA  90
skip_loop:
    mov al, 0x20                                      ; 08BB  B0 20
    call lbuf_put                                     ; 08BD  E8 23 00
    mov ah, 0xe                                       ; 08C0  B4 0E
    mov al, 0x20                                      ; 08C2  B0 20
    call bios10                                       ; 08C4  E8 59 FF
    dec byte [upr]                                    ; 08C7  FE 0E 0D 01
    je skip_end                                       ; 08CB  74 10
    inc byte [col]                                    ; 08CD  FE 06 0A 01
    cmp byte [col], 0x50                              ; 08D1  80 3E 0A 01 50
    jb skip_loop                                      ; 08D6  72 E3
    call newline                                      ; 08D8  E8 9B FF
    jmp short skip_loop                               ; 08DB  EB DE
skip_end:
    mov byte [spc3], 0                                ; 08DD  C6 06 0B 01 00
    ret                                               ; 08E2  C3
; lbuf_put: เก็บ AL ลงบัฟเฟอร์บรรทัด lbuf ที่ตำแหน่ง [blen] แล้วเพิ่ม [blen]
lbuf_put:
    push dx                                           ; 08E3  52
    push bx                                           ; 08E4  53
    mov dx, 0                                         ; 08E5  BA 00 00
    mov dl, byte [blen]                               ; 08E8  8A 16 0E 01
    mov bx, lbuf                                      ; 08EC  BB 9A 04
    db 0x03, 0xDA                                        ; 08EF  03 DA   ; "add bx, dx" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
    mov byte [bx], al                                 ; 08F1  88 07
    pop bx                                            ; 08F3  5B
    pop dx                                            ; 08F4  5A
    inc byte [blen]                                   ; 08F5  FE 06 0E 01
    ret                                               ; 08F9  C3
; putc_norm: ตัวอักษรระดับกลาง — เพิ่มเลขคอลัมน์ ล้างสระบนที่ค้างใน [upc] พิมพ์ และจำตำแหน่งเคอร์เซอร์
putc_norm:
    inc byte [col]                                    ; 08FA  FE 06 0A 01
    mov byte [upc], 0                                 ; 08FE  C6 06 0F 01 00
    call bios10                                       ; 0903  E8 1A FF
    mov ah, 3                                         ; 0906  B4 03   ; หมายเหตุ: ไม่มีการเลื่อนเคอร์เซอร์เอง — ผู้เรียกที่ใช้ AH=09h จะได้เคอร์เซอร์อยู่ที่เดิม (DOS ใช้ AH=0Eh)
;          ค่าที่เก็บใน cur_row/cur_col ไม่มีโค้ดอ่านกลับ
    call bios10                                       ; 0908  E8 15 FF
    mov byte [cur_row], dh                            ; 090B  88 36 18 01
    mov byte [cur_col], dl                            ; 090F  88 16 19 01
    ret                                               ; 0913  C3
; put_lower: ุ / ู (D7h,D8h) — ลง 1 แถว ถอยซ้าย 1 ช่อง พิมพ์ แล้วกลับขึ้นมาที่ตำแหน่งเดิม
put_lower:
    call cur_down                                     ; 0914  E8 13 00
    call cur_left                                     ; 0917  E8 2D 00
    call bios10                                       ; 091A  E8 03 FF
    call cur_up                                       ; 091D  E8 16 00
    cmp ah, 0xe                                       ; 0920  80 FC 0E   ; เทียบแล้วกระโดดไปคำสั่งถัดไป — ไม่มีผล (je +0)
    je low_inc                                        ; 0923  74 00   ; ไม่มีผล (je +0)
low_inc:
    inc byte [upr]                                    ; 0925  FE 06 0D 01
    ret                                               ; 0929  C3
; cur_down: เลื่อนเคอร์เซอร์ลง 1 แถว (พิมพ์ LF ผ่าน BIOS)
cur_down:
    push ax                                           ; 092A  50
    push dx                                           ; 092B  52
    mov al, 0xa                                       ; 092C  B0 0A
    mov ah, 0xe                                       ; 092E  B4 0E
    call bios10                                       ; 0930  E8 ED FE
    pop dx                                            ; 0933  5A
    pop ax                                            ; 0934  58
    ret                                               ; 0935  C3
; cur_up: เลื่อนเคอร์เซอร์ขึ้น 1 แถว (อ่านตำแหน่ง AH=03h แล้วตั้ง AH=02h)
cur_up:
    push ax                                           ; 0936  50
    push dx                                           ; 0937  52
    mov ah, 3                                         ; 0938  B4 03
    call bios10                                       ; 093A  E8 E3 FE
    dec dh                                            ; 093D  FE CE
    mov ah, 2                                         ; 093F  B4 02
    call bios10                                       ; 0941  E8 DC FE
    pop dx                                            ; 0944  5A
    pop ax                                            ; 0945  58
    ret                                               ; 0946  C3
; cur_left: ถอยเคอร์เซอร์ซ้าย 1 ช่อง (พิมพ์ BS ผ่าน BIOS)
cur_left:
    push ax                                           ; 0947  50
    push dx                                           ; 0948  52
    mov ah, 0xe                                       ; 0949  B4 0E
    mov al, 8                                         ; 094B  B0 08
    mov cx, 1                                         ; 094D  B9 01 00
    call bios10                                       ; 0950  E8 CD FE
    pop dx                                            ; 0953  5A
    pop ax                                            ; 0954  58
    ret                                               ; 0955  C3
; cur_right: เลื่อนเคอร์เซอร์ขวา 1 ช่อง — ไม่มีโค้ดเรียก (dead code)
cur_right:
    push ax                                           ; 0956  50
    push dx                                           ; 0957  52
    mov ah, 3                                         ; 0958  B4 03
    call bios10                                       ; 095A  E8 C3 FE
    inc dl                                            ; 095D  FE C2
    mov ah, 2                                         ; 095F  B4 02
    call bios10                                       ; 0961  E8 BC FE
    pop dx                                            ; 0964  5A
    pop ax                                            ; 0965  58
    ret                                               ; 0966  C3
; merge: รวมสระบนกับวรรณยุกต์ที่ซ้อนกันให้เป็นตัวอักษรประกอบ (ligature) — [upc] เก็บสระบน/วรรณยุกต์
;        ตัวล่าสุดของคอลัมน์นี้ไว้
;   กติกา: D9h..DEh = สระบน (ประกอบกับวรรณยุกต์ได้) ; DFh ขึ้นไป = ชั้นวรรณยุกต์/เครื่องหมาย (ไม่ประกอบ)
;          ไม่ว่าพิมพ์ "สระบนแล้ววรรณยุกต์" หรือ "วรรณยุกต์แล้วสระบน" ก็ได้ผลเหมือนกัน:
;          AL = วรรณยุกต์ + สเกลของสระบน -> รหัสลิเกเจอร์ E6h..FEh ; [upc] คงเป็นสระบนตัวนั้นไว้
merge:
    cmp byte [upc], 0                                 ; 0967  80 3E 0F 01 00
    jne merge_have                                    ; 096C  75 04
merge_store:
    mov byte [upc], al                                ; 096E  A2 0F 01   ; A: จำ AL ไว้เป็นตัวค้าง แล้วกลับ
    ret                                               ; 0971  C3
merge_have:
    cmp al, 0xe0                                      ; 0972  3C E0   ; ตัวใหม่ >= E0h = วรรณยุกต์
    jae merge_tone_new                                ; 0974  73 0A
    cmp byte [upc], 0xe0                              ; 0976  80 3E 0F 01 E0
    jb merge_store                                    ; 097B  72 F1
    jmp short merge_vowel_new                         ; 097D  EB 0B
    nop                                               ; 097F  90
merge_tone_new:
    cmp byte [upc], 0xdf                              ; 0980  80 3E 0F 01 DF   ; ตัวค้างเป็นวรรณยุกต์เช่นกัน -> เก็บตัวใหม่แทน
    jae merge_store                                   ; 0985  73 E7
    jmp short merge_apply                             ; 0987  EB 09   ; ตัวค้างเป็นสระบน, ตัวใหม่เป็นวรรณยุกต์
    nop                                               ; 0989  90
merge_vowel_new:
    cmp al, 0xdf                                      ; 098A  3C DF   ; ตัวค้างเป็นวรรณยุกต์, ตัวใหม่เป็นสระบน
    je merge_store                                    ; 098C  74 E0
    xchg [upc], al                                    ; 098E  86 06 0F 01   ; สลับ: [upc]=สระบนตัวใหม่, AL=วรรณยุกต์ตัวเก่า
merge_apply:
    cmp byte [upc], 0xd9                              ; 0992  80 3E 0F 01 D9   ; สเกลตามสระบน: [DEh] +06h  ิ +0Eh  ั +0Ah  ี +13h  ึ +17h  ื +1Bh
    je mrk_d9                                         ; 0997  74 2B
    cmp byte [upc], 0xda                              ; 0999  80 3E 0F 01 DA
    je mrk_da                                         ; 099E  74 27
    cmp byte [upc], 0xdb                              ; 09A0  80 3E 0F 01 DB
    je mrk_db                                         ; 09A5  74 23
    cmp byte [upc], 0xdc                              ; 09A7  80 3E 0F 01 DC
    je mrk_dc                                         ; 09AC  74 1F
    cmp byte [upc], 0xdd                              ; 09AE  80 3E 0F 01 DD
    je mrk_dd                                         ; 09B3  74 0C
    cmp byte [upc], 0xde                              ; 09B5  80 3E 0F 01 DE
    je mrk_de                                         ; 09BA  74 02
    jmp short merge_store                             ; 09BC  EB B0
mrk_de:
    add al, 6                                         ; 09BE  04 06
    ret                                               ; 09C0  C3
mrk_dd:
    add al, 0xa                                       ; 09C1  04 0A
    ret                                               ; 09C3  C3
mrk_d9:
    add al, 0xe                                       ; 09C4  04 0E
    ret                                               ; 09C6  C3
mrk_da:
    add al, 0x13                                      ; 09C7  04 13
    ret                                               ; 09C9  C3
mrk_db:
    add al, 0x17                                      ; 09CA  04 17
    ret                                               ; 09CC  C3
mrk_dc:
    add al, 0x1b                                      ; 09CD  04 1B
    ret                                               ; 09CF  C3
; put_upper: สระบน/วรรณยุกต์ — ขึ้น 1 แถว ถอยซ้าย 1 ช่อง พิมพ์ แล้วลงกลับตำแหน่งเดิม
put_upper:
    call merge                                        ; 09D0  E8 94 FF
    call cur_up                                       ; 09D3  E8 60 FF
    call cur_left                                     ; 09D6  E8 6E FF
    call bios10                                       ; 09D9  E8 44 FE
    call cur_down                                     ; 09DC  E8 4B FF
    cmp ah, 0xe                                       ; 09DF  80 FC 0E   ; เทียบแล้วกระโดดไปคำสั่งถัดไป — ไม่มีผล (je +0)
    je upr_inc                                        ; 09E2  74 00   ; ไม่มีผล (je +0)
upr_inc:
    inc byte [upr]                                    ; 09E4  FE 06 0D 01
    ret                                               ; 09E8  C3
; backspace: สลับ [noskip] ทุกครั้งที่กด แล้วลบตัวอักษรล่าสุดของ lbuf:
;            (ถึง routine นี้ได้เฉพาะจาก putc3 เมื่อโปรแกรมพิมพ์ BS เอง — ระหว่าง AH=0Ah อ่านบรรทัด BS
;            ไม่ผ่านทางนี้ จึงถูกเก็บเป็นไบต์ 08 ใน lbuf แทนการลบ — ดูข้อสังเกต 10)
;            ตัวปกติ -> BS ปกติ ; ุ/ู -> ลบที่แถวล่าง ; สระบน -> ลบที่แถวบน (คืนสระบนตัวก่อนหน้าถ้ามีซ้อนกัน)
;            (บัฟเฟอร์ว่าง [blen]=0 -> ไม่ทำอะไร)
backspace:
    cmp byte [noskip], 0xff                           ; 09E9  80 3E 09 01 FF
    je bs_set                                         ; 09EE  74 08
    mov byte [noskip], 0xff                           ; 09F0  C6 06 09 01 FF
    jmp short bs_check                                ; 09F5  EB 06
    nop                                               ; 09F7  90
bs_set:
    mov byte [noskip], 0                              ; 09F8  C6 06 09 01 00
bs_check:
    cmp byte [blen], 1                                ; 09FD  80 3E 0E 01 01
    jae bs_dec                                        ; 0A02  73 06
    mov byte [blen], 0                                ; 0A04  C6 06 0E 01 00
    ret                                               ; 0A09  C3
bs_dec:
    dec byte [blen]                                   ; 0A0A  FE 0E 0E 01
    mov al, byte [blen]                               ; 0A0E  A0 0E 01
    push bx                                           ; 0A11  53
    mov bx, lbuf                                      ; 0A12  BB 9A 04
    xlatb                                             ; 0A15  D7
    pop bx                                            ; 0A16  5B
    cmp al, 0xd9                                      ; 0A17  3C D9
    jae bs_upper                                      ; 0A19  73 23
    cmp al, 0xd7                                      ; 0A1B  3C D7
    jae bs_lower                                      ; 0A1D  73 0A
    mov al, 8                                         ; 0A1F  B0 08
    call bios10                                       ; 0A21  E8 FC FD
    dec byte [col]                                    ; 0A24  FE 0E 0A 01
    ret                                               ; 0A28  C3
; bs_lower: ลบ ุ/ู ที่แถวล่าง
bs_lower:
    call cur_down                                     ; 0A29  E8 FE FE
    call cur_left                                     ; 0A2C  E8 18 FF
    mov al, 0x20                                      ; 0A2F  B0 20
    mov ah, 0xe                                       ; 0A31  B4 0E
    call bios10                                       ; 0A33  E8 EA FD
    call cur_up                                       ; 0A36  E8 FD FE
    dec byte [upr]                                    ; 0A39  FE 0E 0D 01
    ret                                               ; 0A3D  C3
; bs_upper: ลบสระบนที่แถวบน (ถ้าตัวก่อนหน้าเป็นสระบนด้วย พิมพ์ตัวนั้นคืน ไม่งั้นพิมพ์เว้นวรรค)
bs_upper:
    dec byte [blen]                                   ; 0A3E  FE 0E 0E 01
    mov al, byte [blen]                               ; 0A42  A0 0E 01
    push bx                                           ; 0A45  53
    mov bx, lbuf                                      ; 0A46  BB 9A 04
    xlatb                                             ; 0A49  D7
    pop bx                                            ; 0A4A  5B
    inc byte [blen]                                   ; 0A4B  FE 06 0E 01
    cmp al, 0xd9                                      ; 0A4F  3C D9
    jae bs_up_print                                   ; 0A51  73 02
    mov al, 0x20                                      ; 0A53  B0 20
bs_up_print:
    mov ah, 0xe                                       ; 0A55  B4 0E
    call cur_up                                       ; 0A57  E8 DC FE
    call cur_left                                     ; 0A5A  E8 EA FE
    call bios10                                       ; 0A5D  E8 C0 FD
    call cur_down                                     ; 0A60  E8 C7 FE
    dec byte [upr]                                    ; 0A63  FE 0E 0D 01
    ret                                               ; 0A67  C3
; ============================== hook INT 17h ===============================
; hook17: ดักเฉพาะ AH=00h (พิมพ์ตัวอักษรใน AL)
hook17:
    sti                                               ; 0A68  FB
    push ds                                           ; 0A69  1E
    push bx                                           ; 0A6A  53
    mov bx, cs                                        ; 0A6B  8C CB
    mov ds, bx                                        ; 0A6D  8E DB
    pop bx                                            ; 0A6F  5B
    cmp ah, 0                                         ; 0A70  80 FC 00
    jne hook17_chain                                  ; 0A73  75 09
    cmp al, 0xa0                                      ; 0A75  3C A0
    jne hook17_a20                                    ; 0A77  75 02
    mov al, 0x20                                      ; 0A79  B0 20
hook17_a20:
    jmp short hook17_work                             ; 0A7B  EB 07
    nop                                               ; 0A7D  90
hook17_chain:
    pop ds                                            ; 0A7E  1F
; hook17_jmp: ส่งต่อไป INT 17h ตัวเดิม (เวกเตอร์เดิมอยู่ที่ old17_vec = operand ของ jmp นี้)
hook17_jmp:
    jmp 0:0                                           ; 0A7F  EA 00 00 00 00
old17_vec equ hook17_jmp+1
; hook17_work:
;     A0h (เว้นวรรคไทย)  -> พิมพ์เป็น 20h ; [prn3]=0 (โหมดพิมพ์ 1 ระดับ) -> ส่งตรงให้ BIOS
;     [prn3]=FFh (โหมดพิมพ์ 3 ระดับ) -> แยกเก็บรหัสลงบัฟเฟอร์ระดับบน/กลาง/ล่าง (prn_putc) โดยยังไม่พิมพ์
;     แล้วเรียก BIOS ด้วย AH=02h (อ่านสถานะเครื่องพิมพ์) เพื่อให้ผู้เรียกได้รับสถานะเหมือนพิมพ์จริง
hook17_work:
    cmp byte [prn3], 0                                ; 0A84  80 3E 11 01 00
    je hook17_chain                                   ; 0A89  74 F3
    call prn_putc                                     ; 0A8B  E8 04 00
    mov ah, 2                                         ; 0A8E  B4 02
    jmp short hook17_chain                            ; 0A90  EB EC
; prn_putc: แจกจ่ายรหัสลงบัฟเฟอร์ 3 ระดับสำหรับพิมพ์ (ตำแหน่ง [ppos] เริ่ม 0 ที่ขอบซ้าย)
;     ตัวอักษรระดับกลาง -> lvl_m[ppos], ppos+1 ; สระบน (>=D9h ผ่าน merge ก่อน) -> lvl_u[ppos-1]
;     ุ/ู -> lvl_l[ppos-1] ; CR -> พิมพ์ทั้ง 3 แถวแล้วล้างบัฟเฟอร์ ; เต็มบรรทัด -> พิมพ์ก่อนแล้วมาทำตัวนี้ใหม่
prn_putc:
    cmp al, 0xd                                       ; 0A92  3C 0D
    je p_cr                                           ; 0A94  74 75
    cmp al, 0xa                                       ; 0A96  3C 0A   ; LF ถูกกลืน (ขึ้นบรรทัดทำที่ CR)
    je prn_ret                                        ; 0A98  74 50
    mov bl, byte [pwid]                               ; 0A9A  8A 1E 15 01   ; เต็มบรรทัด ([ppos] >= [pwid]=131)
    cmp byte [ppos], bl                               ; 0A9E  38 1E 13 01
    jae prn_wrapped                                   ; 0AA2  73 62
    cmp al, 0x20                                      ; 0AA4  3C 20   ; เว้นวรรค -> p_space
    je is_pspace                                      ; 0AA6  74 5B
    mov byte [pspc], 0                                ; 0AA8  C6 06 10 01 00   ; ตัวอักษรอื่นรีเซ็ตตัวนับเว้นวรรคของเครื่องพิมพ์
prn_char:
    cmp al, 0xd7                                      ; 0AAD  3C D7   ; D7h,D8h = ุ ู
    jae prn_mark                                      ; 0AAF  73 0F
    mov word [pbuf], lvl_m                            ; 0AB1  C7 06 16 01 9A 02   ; ระดับกลาง
    call pbuf_put                                     ; 0AB7  E8 C2 00
    mov byte [upc], 0                                 ; 0ABA  C6 06 0F 01 00
    ret                                               ; 0ABF  C3
prn_mark:
    cmp al, 0xd9                                      ; 0AC0  3C D9
    jae prn_upper                                     ; 0AC2  73 12
    dec byte [ppos]                                   ; 0AC4  FE 0E 13 01   ; ถอย 1 ตำแหน่งให้ตรงกับพยัญชนะตัวหน้า
    mov word [pbuf], lvl_l                            ; 0AC8  C7 06 16 01 9A 03   ; ระดับล่าง
    call pbuf_put                                     ; 0ACE  E8 AB 00
    inc byte [pmark]                                  ; 0AD1  FE 06 12 01
    ret                                               ; 0AD5  C3
prn_upper:
    call merge                                        ; 0AD6  E8 8E FE
    dec byte [ppos]                                   ; 0AD9  FE 0E 13 01   ; ถอย 1 ตำแหน่ง
    mov word [pbuf], lvl_u                            ; 0ADD  C7 06 16 01 9A 01   ; ระดับบน
    call pbuf_put                                     ; 0AE3  E8 96 00
    inc byte [pmark]                                  ; 0AE6  FE 06 12 01
prn_ret:
    ret                                               ; 0AEA  C3
; bios_print: พิมพ์ AL ทาง LPT1 (DX=0) ผ่าน INT 17h ตัวเดิม (AH=00h) — รีจิสเตอร์ทั้งหมดถูกรักษาไว้
bios_print:
    push dx                                           ; 0AEB  52
    push ax                                           ; 0AEC  50
    push bx                                           ; 0AED  53
    push cx                                           ; 0AEE  51
    push ds                                           ; 0AEF  1E
    push cs                                           ; 0AF0  0E
    pop ds                                            ; 0AF1  1F
    mov dx, 0                                         ; 0AF2  BA 00 00
    mov ah, 0                                         ; 0AF5  B4 00
    mov bx, old17_vec                                 ; 0AF7  BB 80 0A
    pushf                                             ; 0AFA  9C
    call far [bx]                                     ; 0AFB  FF 1F
    pop ds                                            ; 0AFD  1F
    pop cx                                            ; 0AFE  59
    pop bx                                            ; 0AFF  5B
    pop ax                                            ; 0B00  58
    pop dx                                            ; 0B01  5A
    ret                                               ; 0B02  C3
; is_pspace: รายการ "เว้นวรรค" ของ prn_putc
is_pspace:
    jmp near p_space                                  ; 0B03  E9 8E 00
prn_wrapped:
    call flush                                        ; 0B06  E8 48 00
    jmp short prn_putc                                ; 0B09  EB 87
; p_cr: CR — ถ้าบรรทัดไม่ว่าง พิมพ์บัฟเฟอร์ทั้ง 3 ระดับ (บน กลาง ล่าง) แถวละ [ppos] ตัวอักษร + CR LF (p_type)
;       แล้วเติมบัฟเฟอร์ทั้งหมด 3FFh ไบต์ (019Ah..0598h) ด้วยเว้นวรรค และคืน [ppos]=0
p_cr:
    mov byte [pmark], 0                               ; 0B0B  C6 06 12 01 00
    mov byte [pspc], 0                                ; 0B10  C6 06 10 01 00
p_flush_body:
    cmp byte [ppos], 0                                ; 0B15  80 3E 13 01 00   ; บัฟเฟอร์ว่าง -> ข้ามไปล้าง
    je p_clear                                        ; 0B1A  74 1B
    mov word [pbuf], lvl_u                            ; 0B1C  C7 06 16 01 9A 01   ; แถวบน
    call p_type                                       ; 0B22  E8 32 00
    mov word [pbuf], lvl_m                            ; 0B25  C7 06 16 01 9A 02   ; แถวกลาง
    call p_type                                       ; 0B2B  E8 29 00
    mov word [pbuf], lvl_l                            ; 0B2E  C7 06 16 01 9A 03   ; แถวล่าง
    call p_type                                       ; 0B34  E8 20 00
; p_clear: เติมบัฟเฟอร์ 3FFh ไบต์ด้วย 20h แล้วคืน [ppos]=0
p_clear:
    push dx                                           ; 0B37  52
    push bx                                           ; 0B38  53
    mov bx, lvl_u                                     ; 0B39  BB 9A 01
    mov dx, 0x3ff                                     ; 0B3C  BA FF 03
    push ax                                           ; 0B3F  50
    mov al, 0x20                                      ; 0B40  B0 20
pc_fill:
    mov byte [bx], al                                 ; 0B42  88 07
    inc bx                                            ; 0B44  43
    dec dx                                            ; 0B45  4A
    jne pc_fill                                       ; 0B46  75 FA
    pop ax                                            ; 0B48  58
    pop bx                                            ; 0B49  5B
    pop dx                                            ; 0B4A  5A
    mov byte [ppos], 0                                ; 0B4B  C6 06 13 01 00
    ret                                               ; 0B50  C3
; flush: พิมพ์บัฟเฟอร์ที่ค้างอยู่ (เรียกเมื่อเต็มบรรทัด) โดยรักษาค่า AL
flush:
    push ax                                           ; 0B51  50
    call p_flush_body                                 ; 0B52  E8 C0 FF
    pop ax                                            ; 0B55  58
    ret                                               ; 0B56  C3
; p_type: พิมพ์ [ppos] ไบต์จากบัฟเฟอร์ [pbuf] ตามด้วย CR LF
p_type:
    push dx                                           ; 0B57  52
    push bx                                           ; 0B58  53
    mov bx, word [pbuf]                               ; 0B59  8B 1E 16 01
    mov dl, byte [ppos]                               ; 0B5D  8A 16 13 01
ptype_loop:
    push dx                                           ; 0B61  52
    push bx                                           ; 0B62  53
    mov al, byte [bx]                                 ; 0B63  8A 07
    call bios_print                                   ; 0B65  E8 83 FF
    pop bx                                            ; 0B68  5B
    pop dx                                            ; 0B69  5A
    inc bx                                            ; 0B6A  43
    dec dl                                            ; 0B6B  FE CA
    jne ptype_loop                                    ; 0B6D  75 F2
    mov al, 0xd                                       ; 0B6F  B0 0D
    call bios_print                                   ; 0B71  E8 77 FF
    mov al, 0xa                                       ; 0B74  B0 0A
    call bios_print                                   ; 0B76  E8 72 FF
    pop bx                                            ; 0B79  5B
    pop dx                                            ; 0B7A  5A
    ret                                               ; 0B7B  C3
; pbuf_put: เก็บ AL ที่ [pbuf]+[ppos] แล้วเพิ่ม [ppos]
pbuf_put:
    push dx                                           ; 0B7C  52
    push bx                                           ; 0B7D  53
    mov dx, 0                                         ; 0B7E  BA 00 00
    mov dl, byte [ppos]                               ; 0B81  8A 16 13 01
    mov bx, word [pbuf]                               ; 0B85  8B 1E 16 01
    db 0x03, 0xDA                                        ; 0B89  03 DA   ; "add bx, dx" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
    mov byte [bx], al                                 ; 0B8B  88 07
    pop bx                                            ; 0B8D  5B
    pop dx                                            ; 0B8E  5A
    inc byte [ppos]                                   ; 0B8F  FE 06 13 01
    ret                                               ; 0B93  C3
; p_space: เว้นวรรคเมื่อมีสระบน/ล่างค้างในคำ ([pmark]>0) — เว้นวรรคครบ 3 ครั้งจะพิมพ์เว้นวรรคเพิ่มเท่ากับ
;          จำนวนสระที่ค้างอยู่ (กฎเดียวกับ space_skip ของจอภาพ) ; ไม่มีสระค้าง -> เก็บเว้นวรรคปกติ
p_space:
    cmp byte [pmark], 0                               ; 0B94  80 3E 12 01 00
    jne psp_count                                     ; 0B99  75 03
    jmp near prn_char                                 ; 0B9B  E9 0F FF
psp_count:
    inc byte [pspc]                                   ; 0B9E  FE 06 10 01
    cmp byte [pspc], 3                                ; 0BA2  80 3E 10 01 03
    jae psp_3rd                                       ; 0BA7  73 03
    jmp near prn_char                                 ; 0BA9  E9 01 FF
psp_3rd:
    inc byte [pmark]                                  ; 0BAC  FE 06 12 01
; p_sp_loop
p_sp_loop:
    mov word [pbuf], lvl_m                            ; 0BB0  C7 06 16 01 9A 02
    mov al, 0x20                                      ; 0BB6  B0 20
    call pbuf_put                                     ; 0BB8  E8 C1 FF
    dec byte [pmark]                                  ; 0BBB  FE 0E 12 01   ; นับครบตามจำนวนสระ -> จบ
    je p_sp_end                                       ; 0BBF  74 0F
    mov bl, byte [pwid]                               ; 0BC1  8A 1E 15 01   ; เต็มบรรทัด -> พิมพ์ก่อน (คง AL ไว้)
    cmp byte [ppos], bl                               ; 0BC5  38 1E 13 01
    jb p_sp_loop                                      ; 0BC9  72 E5
    call flush                                        ; 0BCB  E8 83 FF
    jmp short p_sp_loop                               ; 0BCE  EB E0
; p_sp_end: รีเซ็ตตัวนับเว้นวรรค
p_sp_end:
    mov byte [pspc], 0                                ; 0BD0  C6 06 10 01 00
    ret                                               ; 0BD5  C3
;
; ---- พื้นที่เซฟรีจิสเตอร์ของผู้เรียก INT 69h ----
sv_es:           dw 0                     ; 0BD6
sv_ds:           dw 0                     ; 0BD8
sv_bp:           dw 0                     ; 0BDA
sv_di:           dw 0                     ; 0BDC
sv_si:           dw 0                     ; 0BDE
sv_dx:           dw 0                     ; 0BE0
sv_cx:           dw 0                     ; 0BE2
sv_bx:           dw 0                     ; 0BE4
sv_ax:           dw 0                     ; 0BE6
;
; ---- fntab: ตารางฟังก์ชัน INT 69h (รายการละ db หมายเลข, dw routine) ----
fntab:
    db 0x01                                                 ; 0BE8
    dw f01_get_kbd
    db 0x02                                                 ; 0BEB
    dw f02_get_disp
    db 0x03                                                 ; 0BEE
    dw f03_get_prn
    db 0x04                                                 ; 0BF1
    dw f04_set_kbd
    db 0x05                                                 ; 0BF4
    dw f05_set_disp
    db 0x06                                                 ; 0BF7
    dw f06_set_lines
    db 0x07                                                 ; 0BFA
    dw f07_set_prn
    db 0x08                                                 ; 0BFD
    dw f08_set_ptype
    db 0x09                                                 ; 0C00
    dw f09_read_key
    db 0x0A                                                 ; 0C03
    dw f0A_read_echo
    db 0x0B                                                 ; 0C06
    dw f0B_read_line
    db 0x00                                                 ; 0C09
    dw fn_none
; ============================== hook INT 69h ===============================
; hook69: API ของ TSX — เก็บ DS ของผู้เรียกไว้ที่ sv_ds, เซฟรีจิสเตอร์ทั้งหมด (save_regs),
;         แล้วบวกค่า AH ด้วย 1 แล้วค้นหาใน fntab: AH=00h -> f01, AH=01h -> f02, ..., AH=0Ah -> f0B
;         (หมายเลข AH จึงตรงกับหมายเลขฟังก์ชันตามตารางในบทความ ; ค่า AH ตั้งแต่ 0Bh ขึ้นไป -> fn_none ไม่ทำอะไร)
;         routine แต่ละตัวเรียก rest_regs ก่อนแก้รีจิสเตอร์ และกลับด้วย pop ds + iret
;         (rest_regs ไม่คืนค่า AX — AX เป็นช่องทางส่งค่ากลับของฟังก์ชัน)
;         ที่อยู่ 0C0Ch นี้คือ "ลายเซ็น" ที่ใช้ตรวจว่า TSR ตัวนี้อยู่ (เวกเตอร์ INT 69h = CS:0C0Ch)
hook69:
    sti                                               ; 0C0C  FB
    push ds                                           ; 0C0D  1E
    push cx                                           ; 0C0E  51
    mov cx, ds                                        ; 0C0F  8C D9
    push bx                                           ; 0C11  53
    mov bx, cs                                        ; 0C12  8C CB
    mov ds, bx                                        ; 0C14  8E DB
    pop bx                                            ; 0C16  5B
    mov word [sv_ds], cx                              ; 0C17  89 0E D8 0B
    pop cx                                            ; 0C1B  59
    call save_regs                                    ; 0C1C  E8 0E 00
    inc ah                                            ; 0C1F  FE C4
    db 0x8A, 0xC4                                        ; 0C21  8A C4   ; "mov al, ah" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
    mov si, fntab                                     ; 0C23  BE E8 0B
    call fn_find                                      ; 0C26  E8 41 00
    call bx                                           ; 0C29  FF D3
    pop ds                                            ; 0C2B  1F
    iret                                              ; 0C2C  CF
; save_regs: เก็บ ES,BP,SI,DI,DX,CX,BX,AX ลง sv_*
save_regs:
    mov word [sv_es], es                              ; 0C2D  8C 06 D6 0B
    mov word [sv_bp], bp                              ; 0C31  89 2E DA 0B
    mov word [sv_si], si                              ; 0C35  89 36 DE 0B
    mov word [sv_di], di                              ; 0C39  89 3E DC 0B
    mov word [sv_dx], dx                              ; 0C3D  89 16 E0 0B
    mov word [sv_cx], cx                              ; 0C41  89 0E E2 0B
    mov word [sv_bx], bx                              ; 0C45  89 1E E4 0B
    mov word [sv_ax], ax                              ; 0C49  A3 E6 0B
    ret                                               ; 0C4C  C3
; rest_regs: คืนค่าจาก sv_* (ยกเว้น DS — คืนตอน pop ds ก่อน iret)
rest_regs:
    mov es, word [sv_es]                              ; 0C4D  8E 06 D6 0B
    mov bp, word [sv_bp]                              ; 0C51  8B 2E DA 0B
    mov si, word [sv_si]                              ; 0C55  8B 36 DE 0B
    mov di, word [sv_di]                              ; 0C59  8B 3E DC 0B
    mov dx, word [sv_dx]                              ; 0C5D  8B 16 E0 0B
    mov cx, word [sv_cx]                              ; 0C61  8B 0E E2 0B
    mov bx, word [sv_bx]                              ; 0C65  8B 1E E4 0B
    ret                                               ; 0C69  C3
; fn_find: หา AL ในตาราง [SI] (รายการละ 3 ไบต์) ; ไม่พบ -> BX = ที่อยู่หลังรายการปิดท้าย = fn_none
;          (ใช้ opcode 83h /r ของ 80186 เช่นเดียวกับ tbl_find)
fn_find:
    cmp byte [si], 0                                  ; 0C6A  80 3C 00
    je fn_found                                       ; 0C6D  74 09
    cmp al, byte [si]                                 ; 0C6F  3A 04
    je fn_found                                       ; 0C71  74 05
    add si, 3                                         ; 0C73  83 C6 03
    jmp short fn_find                                 ; 0C76  EB F2
fn_found:
    mov bx, word [si + 1]                             ; 0C78  8B 5C 01
    ret                                               ; 0C7B  C3
; f01: (INT 69h AH=00h) อ่านโหมดแป้นพิมพ์ -> AL = 00h อังกฤษ / FFh ไทย
f01_get_kbd:
    call rest_regs                                    ; 0C7C  E8 CE FF
    mov al, byte [kbd_mode]                           ; 0C7F  A0 05 01
    ret                                               ; 0C82  C3
; f02: (INT 69h AH=01h) อ่านโหมดการแสดงผล -> AL = [disp3] (00h 1 ระดับ / FFh 3 ระดับ) ; AH = [dlf] (00h 12 บรรทัด / FFh 8 บรรทัด)
f02_get_disp:
    call rest_regs                                    ; 0C83  E8 C7 FF
    mov ah, byte [dlf]                                ; 0C86  8A 26 07 01
    mov al, byte [disp3]                              ; 0C8A  A0 06 01
    ret                                               ; 0C8D  C3
; f03: (INT 69h AH=02h) อ่านโหมดเครื่องพิมพ์ -> AL = [prn3] (00h 1 ระดับ / FFh 3 ระดับ)
f03_get_prn:
    call rest_regs                                    ; 0C8E  E8 BC FF
    mov al, byte [prn3]                               ; 0C91  A0 11 01
    ret                                               ; 0C94  C3
; f04: (INT 69h AH=03h) ตั้งโหมดแป้นพิมพ์ : DL=00h -> อังกฤษ , DL=FFh หรือ 01h -> ไทย , DL=02h..7Fh -> ไม่เปลี่ยน
;      พร้อมตั้งรูปเคอร์เซอร์ (ดู fn_english / fn_thai)
f04_set_kbd:
    call rest_regs                                    ; 0C95  E8 B5 FF
    db 0x8B, 0xC2                                        ; 0C98  8B C2   ; "mov ax, dx" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
    cmp al, 0                                         ; 0C9A  3C 00
    je f04_english                                    ; 0C9C  74 12
    dec al                                            ; 0C9E  FE C8
    jg f04_ret                                        ; 0CA0  7F 25
    mov byte [kbd_mode], 0xff                         ; 0CA2  C6 06 05 01 FF
    mov ah, 1                                         ; 0CA7  B4 01
    mov cx, 0xc                                       ; 0CA9  B9 0C 00
    call bios10                                       ; 0CAC  E8 71 FB
    ret                                               ; 0CAF  C3
; f04_english
f04_english:
    mov byte [kbd_mode], 0                            ; 0CB0  C6 06 05 01 00
    mov ah, 1                                         ; 0CB5  B4 01
    mov cx, 0x90a                                     ; 0CB7  B9 0A 09   ; บรรทัดสแกน 9-10 หรือ 5-6 ตาม [mono]
    cmp byte [mono], 0xff                             ; 0CBA  80 3E 08 01 FF
    je f04_cursor                                     ; 0CBF  74 03
    mov cx, 0x506                                     ; 0CC1  B9 06 05
f04_cursor:
    call bios10                                       ; 0CC4  E8 59 FB
f04_ret:
    ret                                               ; 0CC7  C3
; f05: (INT 69h AH=04h) ตั้งโหมดการแสดงผล : DL=00h -> 1 ระดับ , DL=FFh หรือ 01h -> 3 ระดับ , DL=02h..7Fh -> ไม่เปลี่ยน
f05_set_disp:
    call rest_regs                                    ; 0CC8  E8 82 FF
    db 0x8B, 0xC2                                        ; 0CCB  8B C2   ; "mov ax, dx" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
    cmp al, 0                                         ; 0CCD  3C 00
    je f05_one                                        ; 0CCF  74 0A
    dec al                                            ; 0CD1  FE C8
    jg f05_keep                                       ; 0CD3  7F 0B
    mov byte [disp3], 0xff                            ; 0CD5  C6 06 06 01 FF
    ret                                               ; 0CDA  C3
f05_one:
    mov byte [disp3], 0                               ; 0CDB  C6 06 06 01 00
f05_keep:
    ret                                               ; 0CE0  C3
; f06: (INT 69h AH=05h) จำนวนบรรทัด : DL=00h -> LF เดี่ยว (12 บรรทัด) , DL=FFh หรือ 01h -> LF คู่ (8 บรรทัด) , DL=02h..7Fh -> ไม่เปลี่ยน
f06_set_lines:
    call rest_regs                                    ; 0CE1  E8 69 FF
    db 0x8B, 0xC2                                        ; 0CE4  8B C2   ; "mov ax, dx" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
    cmp al, 0                                         ; 0CE6  3C 00
    je f06_single                                     ; 0CE8  74 0A
    dec al                                            ; 0CEA  FE C8
    jg f06_ret                                        ; 0CEC  7F 0B
    mov byte [dlf], 0xff                              ; 0CEE  C6 06 07 01 FF
    ret                                               ; 0CF3  C3
f06_single:
    mov byte [dlf], 0                                 ; 0CF4  C6 06 07 01 00
f06_ret:
    ret                                               ; 0CF9  C3
; f07: (INT 69h AH=06h) ตั้งโหมดเครื่องพิมพ์ แล้วส่งรหัสระยะบรรทัดให้เครื่องพิมพ์ :
;      DL=FFh หรือ 01h -> [prn3]=FFh (3 ระดับ) + prn3_init ; DL=02h..7Fh -> ไม่เปลี่ยน ; DL=00h -> prn1_init
;      ข้อสังเกต: ที่ prn1_init มีการเขียน [prn3]=FFh เช่นกัน (น่าจะตั้งใจเป็น 00h) ผลคือ DL=00h สั่งระยะบรรทัด
;      แบบ 1 ระดับ แต่ TSX ยังค่อยข้อมูลแบบ 3 ระดับอยู่ — การสั่ง "พิมพ์ 1 ระดับ" ที่ได้ผลจริงคือ ALT+F5 / INT 10h AL=84h
f07_set_prn:
    call rest_regs                                    ; 0CFA  E8 50 FF
    db 0x8B, 0xC2                                        ; 0CFD  8B C2   ; "mov ax, dx" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
    cmp al, 0                                         ; 0CFF  3C 00
    je prn1_init                                      ; 0D01  74 1E
    dec al                                            ; 0D03  FE C8   ; 01h..7Fh -> ออกโดยไม่เปลี่ยน
    jg set_prn_ret                                    ; 0D05  7F 33
; prn3_init: รหัสระยะบรรทัดสำหรับพิมพ์ 3 ระดับ ตามชนิดเครื่องพิมพ์
prn3_init:
    mov byte [prn3], 0xff                             ; 0D07  C6 06 11 01 FF
    cmp byte [prn_type], 1                            ; 0D0C  80 3E 04 01 01   ; prn_type
    je prn3i_citoh                                    ; 0D11  74 0A
    jb prn3i_fx                                       ; 0D13  72 04
    call pr_esc3_14                                   ; 0D15  E8 26 FA   ; 2 = LQ1500 -> ESC '3' 14h
    ret                                               ; 0D18  C3
prn3i_fx:
    call pr_esc3_17                                   ; 0D19  E8 32 FA   ; 0 = FX100  -> ESC '3' 17h
    ret                                               ; 0D1C  C3
prn3i_citoh:
    call pr_escT16                                    ; 0D1D  E8 3E FA   ; 1 = CITOH  -> ESC 'T' '1' '6'
    ret                                               ; 0D20  C3
; prn1_init: รหัสระยะบรรทัดสำหรับพิมพ์ 1 ระดับ ตามชนิดเครื่องพิมพ์
;            (บรรทัดแรกเขียน [prn3]=FFh — ข้อผิดพลาดที่กล่าวถึงใน f07)
prn1_init:
    mov byte [prn3], 0xff                             ; 0D21  C6 06 11 01 FF
    cmp byte [prn_type], 1                            ; 0D26  80 3E 04 01 01   ; prn_type
    je prn1i_citoh                                    ; 0D2B  74 0A
    jb prn1i_fx                                       ; 0D2D  72 04
    call pr_esc1                                      ; 0D2F  E8 EB F9   ; 2 = LQ1500 -> ESC '1'
    ret                                               ; 0D32  C3
prn1i_fx:
    call pr_esc2                                      ; 0D33  E8 F2 F9   ; 0 = FX100  -> ESC '2'
    ret                                               ; 0D36  C3
prn1i_citoh:
    call pr_escA                                      ; 0D37  E8 F9 F9   ; 1 = CITOH  -> ESC 'A'
set_prn_ret:
    ret                                               ; 0D3A  C3
; f08: (INT 69h AH=07h) เลือกชนิดเครื่องพิมพ์ : DL = 0 FX100 / 1 CITOH / 2 LQ1500 (ค่าอื่น -> ไม่เปลี่ยน)
;      แล้วส่งรหัสระยะบรรทัดตามโหมดพิมพ์ปัจจุบัน (prn1_init หรือ prn3_init) ตามด้วยรหัสเริ่มต้นที่ f08_type_init
f08_set_ptype:
    call rest_regs                                    ; 0D3B  E8 0F FF
    db 0x8A, 0xC2                                        ; 0D3E  8A C2   ; "mov al, dl" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
    cmp al, 2                                         ; 0D40  3C 02
    ja pti_done                                       ; 0D42  77 26   ; > 2 -> ออก
    mov byte [prn_type], al                           ; 0D44  A2 04 01
    cmp byte [prn3], 0                                ; 0D47  80 3E 11 01 00   ; ตามโหมดพิมพ์ปัจจุบัน
    je f08_1level                                     ; 0D4C  74 05
    call prn3_init                                    ; 0D4E  E8 B6 FF
    jmp short f08_type_init                           ; 0D51  EB 03
f08_1level:
    call prn1_init                                    ; 0D53  E8 CB FF
; f08_type_init: ส่ง DC2 (FX100/LQ1500) หรือ ESC 'N' (CITOH)
f08_type_init:
    cmp byte [prn_type], 1                            ; 0D56  80 3E 04 01 01   ; prn_type
    je pti_citoh                                      ; 0D5B  74 0A
    jb pti_fx                                         ; 0D5D  72 04
    call pr_dc2                                       ; 0D5F  E8 11 FA
    ret                                               ; 0D62  C3
pti_fx:
    call pr_dc2b                                      ; 0D63  E8 13 FA
    ret                                               ; 0D66  C3
pti_citoh:
    call pr_escN                                      ; 0D67  E8 13 FA
pti_done:
    ret                                               ; 0D6A  C3
; f09: (INT 69h AH=08h) อ่านคีย์ 1 ตัว (ไม่แสดงผล) -> AL = รหัส KU, AH = scan code เดิม ;
;      สระบน+วรรณยุกต์ที่ซ้อนกันถูกรวมเป็นลิเกเจอร์ (>=E6h)
;      ([upc] เก็บสระบนตัวค้างไว้ให้ครั้งถัดไป)
f09_read_key:
    mov ah, 0                                         ; 0D6B  B4 00
    call kbd_read                                     ; 0D6D  E8 70 F8
    cmp al, 0xd9                                      ; 0D70  3C D9   ; ไม่ใช่สระบน -> ล้างตัวค้าง
    jae f09_upper                                     ; 0D72  73 07
    mov byte [upc], 0                                 ; 0D74  C6 06 0F 01 00
    jmp short f09_ret                                 ; 0D79  EB 0D
f09_upper:
    cmp byte [upc], 0xe6                              ; 0D7B  80 3E 0F 01 E6   ; ตัวค้างเป็นลิเกเจอร์อยู่แล้ว -> ไม่รวมซ้ำ
    jae f09_store                                     ; 0D80  73 03
    call merge                                        ; 0D82  E8 E2 FB
f09_store:
    mov byte [upc], al                                ; 0D85  A2 0F 01
f09_ret:
    call rest_regs                                    ; 0D88  E8 C2 FE
    ret                                               ; 0D8B  C3
; f0A: (INT 69h AH=09h) อ่านคีย์ 1 ตัว แล้วแสดงผลที่ตำแหน่งเคอร์เซอร์ (BIOS หน้า 0 สี 4) -> AL = รหัส KU
;      ค่าที่อ่านได้ถูกเก็บที่ sv_ax เพื่อคืนให้ผู้เรียก
f0A_read_echo:
    call f09_read_key                                 ; 0D8C  E8 DC FF
    mov word [sv_ax], ax                              ; 0D8F  A3 E6 0B
    mov cx, 1                                         ; 0D92  B9 01 00
    mov bx, 0x14                                      ; 0D95  BB 14 00
    mov ah, 0xe                                       ; 0D98  B4 0E
    call putc3_store                                  ; 0D9A  E8 A5 FA
    mov ax, word [sv_ax]                              ; 0D9D  A1 E6 0B
    ret                                               ; 0DA0  C3
; f0B: (INT 69h AH=0Ah) อ่านข้อความ 1 บรรทัดจนกว่า ENTER (บังคับแสดงผลแบบ 3 ระดับระหว่างอ่าน) ; DS:DX = บัฟเฟอร์ปลายทาง
;      ผลลัพธ์ : ไบต์แรก = จำนวนตัวอักษร ([col]+[upr]) ตามด้วยรหัส KU จาก lbuf (ตัวสุดท้ายคือ CR)
f0B_read_line:
    mov byte [col], 0                                 ; 0DA1  C6 06 0A 01 00
    mov byte [upr], 0                                 ; 0DA6  C6 06 0D 01 00
    mov al, byte [disp3]                              ; 0DAB  A0 06 01
    mov word [sv_ax], ax                              ; 0DAE  A3 E6 0B
    mov byte [disp3], 0xff                            ; 0DB1  C6 06 06 01 FF
f0b_loop:
    call f0A_read_echo                                ; 0DB6  E8 D3 FF
    cmp al, 0xd                                       ; 0DB9  3C 0D
    je f0b_done                                       ; 0DBB  74 02
    jmp short f0b_loop                                ; 0DBD  EB F7
f0b_done:
    mov ch, 0                                         ; 0DBF  B5 00
    mov cl, byte [col]                                ; 0DC1  8A 0E 0A 01
    mov ah, 0                                         ; 0DC5  B4 00
    mov al, byte [upr]                                ; 0DC7  A0 0D 01
    db 0x03, 0xC8                                        ; 0DCA  03 C8   ; "add cx, ax" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
    mov es, word [sv_ds]                              ; 0DCC  8E 06 D8 0B
    mov bx, word [sv_dx]                              ; 0DD0  8B 1E E0 0B
    mov byte [es:bx], cl                              ; 0DD4  26 88 0F
    inc bx                                            ; 0DD7  43
    mov si, lbuf                                      ; 0DD8  BE 9A 04
    db 0x8B, 0xFB                                        ; 0DDB  8B FB   ; "mov di, bx" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)
f0b_copy:
    mov al, byte [si]                                 ; 0DDD  8A 04
    mov byte [es:di], al                              ; 0DDF  26 88 05
    inc si                                            ; 0DE2  46
    inc di                                            ; 0DE3  47
    dec cx                                            ; 0DE4  49
    jne f0b_copy                                      ; 0DE5  75 F6
    mov ah, 0xe                                       ; 0DE7  B4 0E
    mov al, 0xd                                       ; 0DE9  B0 0D
    int 0x10                                          ; 0DEB  CD 10
    mov ax, word [sv_ax]                              ; 0DED  A1 E6 0B
    mov byte [disp3], al                              ; 0DF0  A2 06 01
    call rest_regs                                    ; 0DF3  E8 57 FE
    ret                                               ; 0DF6  C3
; fn_none: ค่าเริ่มต้นเมื่อหมายเลขฟังก์ชันไม่มีในตาราง — ไม่ทำอะไร
fn_none:
    ret                                               ; 0DF7  C3
;
; ---- banner: ข้อความเปิดโปรแกรม (จบด้วย '$' ที่ 1140h) พิมพ์ด้วย INT 21h AH=09h ที่ install ----
;    ข้อความไทยเป็นรหัส KU ที่วางไว้สำหรับการแสดงผล 3 ระดับ (สระบน/สระล่างอยู่คนละแถวกับตัวอักษร):
;       0E1Dh (ตัวอักษร): "โปรแกรมควบคมระบบงานภาษาไทย"  — ควบค[ุ]ม ที่ ุ หายไปอยู่ในบรรทัดถัดไป
;       0E66h (สระล่าง) : ◌ุ ของคำว่า "ควบคุม"
;       0FB0h (สระบน)   : ◌ิ ◌์ ◌ิ ◌ั ◌์ ของบรรทัดตัวอักษรข้างล่าง (คณะวิศว..., มหาวิทยาลัย..., ศาสตร์)
;       1004h (ตัวอักษร): "คณะวศวกรรมศาสตร มหาวทยาลยเกษตรศาสตร"
banner:
; 0DF8h: "<BEL>"
    db 0x07, 0x0D, 0x0A                               ; 0DF8  <BEL><CR><LF>
    db 0x0A                                           ; 0DFB  <LF>
    db 0x0A                                           ; 0DFC  <LF>
    db 0x0A                                           ; 0DFD  <LF>
    db 0x0A                                           ; 0DFE  <LF>
    db 0x0A                                           ; 0DFF  <LF>
    db 0x0A                                           ; 0E00  <LF>
    db 0x0A                                           ; 0E01  <LF>
; 0E02h: "                           โปรแกรมควบคมระบบงานภาษาไทย      "
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0E02                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xD2, 0xB9, 0xC1, 0xD1, 0xA1 ; 0E12             โปรแก
    db 0xC1, 0xBF, 0xA3, 0xC4, 0xB8, 0xA3, 0xBF, 0xC1, 0xCC, 0xB8, 0xB8, 0xA5, 0xCE, 0xB7, 0xBE, 0xCE ; 0E22  รมควบคมระบบงานภา
    db 0xC6, 0xCE, 0xD4, 0xB5, 0xC0, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 0E32  ษาไทย      <CR><LF>
; 0E3Fh: "                                     ◌ุ                     "
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0E3F                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0E4F                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0xD7, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0E5F       ◌ุ          
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 0E6F             <CR><LF>
    db 0x0A                                           ; 0E7C  <LF>
; 0E7Dh: "                                      FOR                  "
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0E7D                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0E8D                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x46, 0x4F, 0x52, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0E9D        FOR       
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 0EAD             <CR><LF>
    db 0x0A                                           ; 0EBA  <LF>
; 0EBBh: "                               IBM PC,XT AND PCjr          "
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0EBB                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x49 ; 0ECB                 I
    db 0x42, 0x4D, 0x20, 0x50, 0x43, 0x2C, 0x58, 0x54, 0x20, 0x41, 0x4E, 0x44, 0x20, 0x50, 0x43, 0x6A ; 0EDB  BM PC,XT AND PCj
    db 0x72, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 0EEB  r          <CR><LF>
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0EF8                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0F08                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0F18                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 0F28             <CR><LF>
; 0F35h: "                         Version 3.51   ( Version of TSX)  "
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0F35                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x56, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E ; 0F45           Version
    db 0x20, 0x33, 0x2E, 0x35, 0x31, 0x20, 0x20, 0x20, 0x28, 0x20, 0x56, 0x65, 0x72, 0x73, 0x69, 0x6F ; 0F55   3.51   ( Versio
    db 0x6E, 0x20, 0x6F, 0x66, 0x20, 0x54, 0x53, 0x58, 0x29, 0x20, 0x20, 0x0D, 0x0A ; 0F65  n of TSX)  <CR><LF>
    db 0x0A                                           ; 0F72  <LF>
; 0F73h: "                                Copyright  1984            "
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0F73                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0F83                  
    db 0x43, 0x6F, 0x70, 0x79, 0x72, 0x69, 0x67, 0x68, 0x74, 0x20, 0x20, 0x31, 0x39, 0x38, 0x34, 0x20 ; 0F93  Copyright  1984 
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 0FA3             <CR><LF>
; 0FB0h: "                          ◌ิ          ◌์    ◌ิ   ◌ั          ◌์ "
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0FB0                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xD9, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0FC0            ◌ิ     
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0xE4, 0x20, 0x20, 0x20, 0x20, 0xD9, 0x20, 0x20, 0x20, 0xDD, 0x20 ; 0FD0       ◌์    ◌ิ   ◌ั 
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xE4, 0x20, 0x0D, 0x0A ; 0FE0           ◌์ <CR><LF>
; 0FEDh: "                       คณะวศวกรรมศาสตร มหาวทยาลยเกษตรศาสตร "
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 0FED                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xA3, 0xB1, 0xCC, 0xC4, 0xC5, 0xC4, 0xA1, 0xC1, 0xC1 ; 0FFD         คณะวศวกรร
    db 0xBF, 0xC5, 0xCE, 0xC7, 0xB3, 0xC1, 0x20, 0xBF, 0xC8, 0xCE, 0xC4, 0xB5, 0xC0, 0xCE, 0xC3, 0xC0 ; 100D  มศาสตร มหาวทยาลย
    db 0xD0, 0xA1, 0xC6, 0xB3, 0xC1, 0xC5, 0xCE, 0xC7, 0xB3, 0xC1, 0x20, 0x0D, 0x0A ; 101D  เกษตรศาสตร <CR><LF>
    db 0x0A                                           ; 102A  <LF>
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 102B                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 103B                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 104B                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 105B             <CR><LF>
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 1068                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 1078                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 1088                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 1098             <CR><LF>
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 10A5                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 10B5                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 10C5                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 10D5             <CR><LF>
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 10E2                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 10F2                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 1102                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 1112             <CR><LF>
    db 0x0A                                           ; 111F  <LF>
    db 0x0A                                           ; 1120  <LF>
    db 0x0A                                           ; 1121  <LF>
; 1122h: "Press any key to continue ... $"
    db 0x50, 0x72, 0x65, 0x73, 0x73, 0x20, 0x61, 0x6E, 0x79, 0x20, 0x6B, 0x65, 0x79, 0x20, 0x74, 0x6F ; 1122  Press any key to
    db 0x20, 0x63, 0x6F, 0x6E, 0x74, 0x69, 0x6E, 0x75, 0x65, 0x20, 0x2E, 0x2E, 0x2E, 0x20, 0x24 ; 1132   continue ... $
;
; ---- cmdlist: รายการคำสั่ง + ส่วนหัวของเมนูเครื่องพิมพ์ (จบด้วย '$' ที่ 14B7h) ----
cmdlist:
    db 0x0D, 0x0A                                     ; 1141  <CR><LF>
    db 0x0A                                           ; 1143  <LF>
    db 0x0A                                           ; 1144  <LF>
    db 0x0A                                           ; 1145  <LF>
    db 0x0A                                           ; 1146  <LF>
    db 0x0A                                           ; 1147  <LF>
    db 0x0A                                           ; 1148  <LF>
    db 0x0A                                           ; 1149  <LF>
    db 0x0A                                           ; 114A  <LF>
    db 0x0A                                           ; 114B  <LF>
; 114Ch: "                          <<<<   COMMAND   >>>>         "
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 114C                  
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3C, 0x3C, 0x3C, 0x3C, 0x20, 0x20 ; 115C            <<<<  
    db 0x20, 0x43, 0x4F, 0x4D, 0x4D, 0x41, 0x4E, 0x44, 0x20, 0x20, 0x20, 0x3E, 0x3E, 0x3E, 0x3E, 0x20 ; 116C   COMMAND   >>>> 
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 117C          <CR><LF>
    db 0x0A                                           ; 1186  <LF>
; 1187h: "  FUNCTION KEY      ASCII (DECIMAL)               MEANING        "
    db 0x20, 0x20, 0x46, 0x55, 0x4E, 0x43, 0x54, 0x49, 0x4F, 0x4E, 0x20, 0x4B, 0x45, 0x59, 0x20, 0x20 ; 1187    FUNCTION KEY  
    db 0x20, 0x20, 0x20, 0x20, 0x41, 0x53, 0x43, 0x49, 0x49, 0x20, 0x28, 0x44, 0x45, 0x43, 0x49, 0x4D ; 1197      ASCII (DECIM
    db 0x41, 0x4C, 0x29, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 11A7  AL)             
    db 0x20, 0x20, 0x4D, 0x45, 0x41, 0x4E, 0x49, 0x4E, 0x47, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 11B7    MEANING       
    db 0x20, 0x0D, 0x0A                               ; 11C7   <CR><LF>
    db 0x0A                                           ; 11CA  <LF>
; 11CBh: "   ALT_F1<TAB>           128             SELECT 1 LEVEL  DISPLAY   "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x31, 0x09, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 11CB     ALT_F1<TAB>      
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x31, 0x32, 0x38, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 11DB       128        
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C, 0x45, 0x43, 0x54, 0x20, 0x31, 0x20, 0x4C, 0x45 ; 11EB       SELECT 1 LE
    db 0x56, 0x45, 0x4C, 0x20, 0x20, 0x44, 0x49, 0x53, 0x50, 0x4C, 0x41, 0x59, 0x20, 0x20, 0x20, 0x0D ; 11FB  VEL  DISPLAY   <CR>
    db 0x0A                                           ; 120B  <LF>
; 120Ch: "   ALT_F2<TAB>           129<TAB><TAB>   SELECT ENGLISH  MODE      "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x32, 0x09, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 120C     ALT_F2<TAB>      
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x31, 0x32, 0x39, 0x09, 0x09, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C ; 121C       129<TAB><TAB>   SEL
    db 0x45, 0x43, 0x54, 0x20, 0x45, 0x4E, 0x47, 0x4C, 0x49, 0x53, 0x48, 0x20, 0x20, 0x4D, 0x4F, 0x44 ; 122C  ECT ENGLISH  MOD
    db 0x45, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x0D, 0x0A ; 123C  E      <CR><LF>
; 1245h: "   ALT_F3<TAB><TAB>   130<TAB><TAB>   SELECT 3 LEVELS DISPLAY   "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x33, 0x09, 0x09, 0x20, 0x20, 0x20, 0x31, 0x33 ; 1245     ALT_F3<TAB><TAB>   13
    db 0x30, 0x09, 0x09, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C, 0x45, 0x43, 0x54, 0x20, 0x33, 0x20, 0x4C ; 1255  0<TAB><TAB>   SELECT 3 L
    db 0x45, 0x56, 0x45, 0x4C, 0x53, 0x20, 0x44, 0x49, 0x53, 0x50, 0x4C, 0x41, 0x59, 0x20, 0x20, 0x20 ; 1265  EVELS DISPLAY   
    db 0x0D, 0x0A                                     ; 1275  <CR><LF>
; 1277h: "   ALT_F4<TAB><TAB>   131<TAB><TAB>   SELECT THAI     MODE      "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x34, 0x09, 0x09, 0x20, 0x20, 0x20, 0x31, 0x33 ; 1277     ALT_F4<TAB><TAB>   13
    db 0x31, 0x09, 0x09, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C, 0x45, 0x43, 0x54, 0x20, 0x54, 0x48, 0x41 ; 1287  1<TAB><TAB>   SELECT THA
    db 0x49, 0x20, 0x20, 0x20, 0x20, 0x20, 0x4D, 0x4F, 0x44, 0x45, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 ; 1297  I     MODE      
    db 0x0D, 0x0A                                     ; 12A7  <CR><LF>
; 12A9h: "   ALT_F5<TAB><TAB>   132<TAB><TAB>   SELECT 1 LEVEL  PRINTER   "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x35, 0x09, 0x09, 0x20, 0x20, 0x20, 0x31, 0x33 ; 12A9     ALT_F5<TAB><TAB>   13
    db 0x32, 0x09, 0x09, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C, 0x45, 0x43, 0x54, 0x20, 0x31, 0x20, 0x4C ; 12B9  2<TAB><TAB>   SELECT 1 L
    db 0x45, 0x56, 0x45, 0x4C, 0x20, 0x20, 0x50, 0x52, 0x49, 0x4E, 0x54, 0x45, 0x52, 0x20, 0x20, 0x20 ; 12C9  EVEL  PRINTER   
    db 0x0D, 0x0A                                     ; 12D9  <CR><LF>
; 12DBh: "   ALT_F6<TAB><TAB>   133<TAB><TAB>   SELECT 3 LEVELS PRINTER   "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x36, 0x09, 0x09, 0x20, 0x20, 0x20, 0x31, 0x33 ; 12DB     ALT_F6<TAB><TAB>   13
    db 0x33, 0x09, 0x09, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C, 0x45, 0x43, 0x54, 0x20, 0x33, 0x20, 0x4C ; 12EB  3<TAB><TAB>   SELECT 3 L
    db 0x45, 0x56, 0x45, 0x4C, 0x53, 0x20, 0x50, 0x52, 0x49, 0x4E, 0x54, 0x45, 0x52, 0x20, 0x20, 0x20 ; 12FB  EVELS PRINTER   
    db 0x0D, 0x0A                                     ; 130B  <CR><LF>
; 130Dh: "   ALT_F7<TAB><TAB><TAB><TAB>   TOGGLE MONO&COLOR DISPLAY "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x37, 0x09, 0x09, 0x09, 0x09, 0x20, 0x20, 0x20 ; 130D     ALT_F7<TAB><TAB><TAB><TAB>   
    db 0x54, 0x4F, 0x47, 0x47, 0x4C, 0x45, 0x20, 0x4D, 0x4F, 0x4E, 0x4F, 0x26, 0x43, 0x4F, 0x4C, 0x4F ; 131D  TOGGLE MONO&COLO
    db 0x52, 0x20, 0x44, 0x49, 0x53, 0x50, 0x4C, 0x41, 0x59, 0x20, 0x0D, 0x0A ; 132D  R DISPLAY <CR><LF>
; 1339h: "   ALT_F8<TAB><TAB> <TAB><TAB>   TOGGLE 8&12 LINES DISPLAY "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x38, 0x09, 0x09, 0x20, 0x09, 0x09, 0x20, 0x20 ; 1339     ALT_F8<TAB><TAB> <TAB><TAB>  
    db 0x20, 0x54, 0x4F, 0x47, 0x47, 0x4C, 0x45, 0x20, 0x38, 0x26, 0x31, 0x32, 0x20, 0x4C, 0x49, 0x4E ; 1349   TOGGLE 8&12 LIN
    db 0x45, 0x53, 0x20, 0x44, 0x49, 0x53, 0x50, 0x4C, 0x41, 0x59, 0x20, 0x0D, 0x0A ; 1359  ES DISPLAY <CR><LF>
; 1366h: "   ALT_F9<TAB><TAB><TAB>           SELECT NORMAL     PRINTER "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x39, 0x09, 0x09, 0x09, 0x20, 0x20, 0x20, 0x20 ; 1366     ALT_F9<TAB><TAB><TAB>    
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C, 0x45, 0x43, 0x54, 0x20, 0x4E, 0x4F ; 1376         SELECT NO
    db 0x52, 0x4D, 0x41, 0x4C, 0x20, 0x20, 0x20, 0x20, 0x20, 0x50, 0x52, 0x49, 0x4E, 0x54, 0x45, 0x52 ; 1386  RMAL     PRINTER
    db 0x20, 0x0D, 0x0A                               ; 1396   <CR><LF>
; 1399h: "   ALT_F10<TAB><TAB>    <TAB>           SELECT CONDENSE   PRINTER "
    db 0x20, 0x20, 0x20, 0x41, 0x4C, 0x54, 0x5F, 0x46, 0x31, 0x30, 0x09, 0x09, 0x20, 0x20, 0x20, 0x20 ; 1399     ALT_F10<TAB><TAB>    
    db 0x09, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C, 0x45 ; 13A9  <TAB>           SELE
    db 0x43, 0x54, 0x20, 0x43, 0x4F, 0x4E, 0x44, 0x45, 0x4E, 0x53, 0x45, 0x20, 0x20, 0x20, 0x50, 0x52 ; 13B9  CT CONDENSE   PR
    db 0x49, 0x4E, 0x54, 0x45, 0x52, 0x20, 0x0D, 0x0A ; 13C9  INTER <CR><LF>
; 13D1h: "    NONE <TAB><TAB>   134<TAB><TAB>   SELECT PRINTER 80  COLUMNS"
    db 0x20, 0x20, 0x20, 0x20, 0x4E, 0x4F, 0x4E, 0x45, 0x20, 0x09, 0x09, 0x20, 0x20, 0x20, 0x31, 0x33 ; 13D1      NONE <TAB><TAB>   13
    db 0x34, 0x09, 0x09, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C, 0x45, 0x43, 0x54, 0x20, 0x50, 0x52, 0x49 ; 13E1  4<TAB><TAB>   SELECT PRI
    db 0x4E, 0x54, 0x45, 0x52, 0x20, 0x38, 0x30, 0x20, 0x20, 0x43, 0x4F, 0x4C, 0x55, 0x4D, 0x4E, 0x53 ; 13F1  NTER 80  COLUMNS
    db 0x0D, 0x0A                                     ; 1401  <CR><LF>
; 1403h: "    NONE  <TAB><TAB>   135<TAB><TAB>   SELECT PRINTER 132 COLUMNS"
    db 0x20, 0x20, 0x20, 0x20, 0x4E, 0x4F, 0x4E, 0x45, 0x20, 0x20, 0x09, 0x09, 0x20, 0x20, 0x20, 0x31 ; 1403      NONE  <TAB><TAB>   1
    db 0x33, 0x35, 0x09, 0x09, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C, 0x45, 0x43, 0x54, 0x20, 0x50, 0x52 ; 1413  35<TAB><TAB>   SELECT PR
    db 0x49, 0x4E, 0x54, 0x45, 0x52, 0x20, 0x31, 0x33, 0x32, 0x20, 0x43, 0x4F, 0x4C, 0x55, 0x4D, 0x4E ; 1423  INTER 132 COLUMN
    db 0x53, 0x0D, 0x0A                               ; 1433  S<CR><LF>
; 1436h: "    NONE<TAB><TAB>   136             SELECT PRINTER 160 COLUMNS"
    db 0x20, 0x20, 0x20, 0x20, 0x4E, 0x4F, 0x4E, 0x45, 0x09, 0x09, 0x20, 0x20, 0x20, 0x31, 0x33, 0x36 ; 1436      NONE<TAB><TAB>   136
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C ; 1446               SEL
    db 0x45, 0x43, 0x54, 0x20, 0x50, 0x52, 0x49, 0x4E, 0x54, 0x45, 0x52, 0x20, 0x31, 0x36, 0x30, 0x20 ; 1456  ECT PRINTER 160 
    db 0x43, 0x4F, 0x4C, 0x55, 0x4D, 0x4E, 0x53, 0x0D, 0x0A ; 1466  COLUMNS<CR><LF>
; 146Fh: "    NONE<TAB><TAB>   137             SELECT PRINTER 256 COLUMNS"
    db 0x20, 0x20, 0x20, 0x20, 0x4E, 0x4F, 0x4E, 0x45, 0x09, 0x09, 0x20, 0x20, 0x20, 0x31, 0x33, 0x37 ; 146F      NONE<TAB><TAB>   137
    db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x53, 0x45, 0x4C ; 147F               SEL
    db 0x45, 0x43, 0x54, 0x20, 0x50, 0x52, 0x49, 0x4E, 0x54, 0x45, 0x52, 0x20, 0x32, 0x35, 0x36, 0x20 ; 148F  ECT PRINTER 256 
    db 0x43, 0x4F, 0x4C, 0x55, 0x4D, 0x4E, 0x53, 0x0D, 0x0A ; 149F  COLUMNS<CR><LF>
    db 0x0A                                           ; 14A8  <LF>
; 14A9h: " FOR PRINTER  $"
    db 0x20, 0x46, 0x4F, 0x52, 0x20, 0x50, 0x52, 0x49, 0x4E, 0x54, 0x45, 0x52, 0x20, 0x20, 0x24 ; 14A9   FOR PRINTER  $
;
; ---- ข้อความเมนูเครื่องพิมพ์ (พิมพ์โดย install/menu_item) ----
pmenu_lq:
    db 0x20, 0x4C, 0x51, 0x31, 0x35, 0x30, 0x30, 0x20, 0x20, 0x24 ; 14B8   LQ1500  $
;     ชนิด 2 = LQ1500
pmenu_citoh:
    db 0x20, 0x43, 0x49, 0x54, 0x4F, 0x48, 0x20, 0x20, 0x20, 0x24 ; 14C2   CITOH   $
;     ชนิด 1 = CITOH
pmenu_fx:
    db 0x20, 0x46, 0x58, 0x31, 0x30, 0x30, 0x20, 0x20, 0x20, 0x24 ; 14CC   FX100   $
;     ชนิด 0 = FX100
pmenu_nul:   db 0x00             ; 14D6
pmenu_crlf:  db 0x0D, 0x0A, 0x24 ; 14D7  CR LF '$'
; ================== ส่วนติดตั้ง (ทำงานครั้งเดียวจาก PSP:0100h) ==================
; install: แสดงแบนเนอร์ + รายการคำสั่ง (INT 21h AH=09h), รอกดคีย์ (AH=07h),
;          แล้วแสดงรายการเครื่องพิมพ์โดยไฮไลต์ชนิดที่ตั้งอยู่
install:
    mov ax, cs                                        ; 14DA  8C C8
    mov ds, ax                                        ; 14DC  8E D8
    mov dx, banner                                    ; 14DE  BA F8 0D
    mov ah, 9                                         ; 14E1  B4 09
    int 0x21                                          ; 14E3  CD 21
    mov ah, 7                                         ; 14E5  B4 07   ; รอกดคีย์ (ไม่แสดงผล)
    int 0x21                                          ; 14E7  CD 21
    mov dx, cmdlist                                   ; 14E9  BA 41 11
    mov ah, 9                                         ; 14EC  B4 09
    int 0x21                                          ; 14EE  CD 21
    mov ah, 9                                         ; 14F0  B4 09
    mov cx, 1                                         ; 14F2  B9 01 00
    mov bx, 0x20                                      ; 14F5  BB 20 00   ; BX = 0020h: BH=หน้า 0, BL=สี 20h
    mov si, pmenu_lq                                  ; 14F8  BE B8 14
    mov dl, 2                                         ; 14FB  B2 02
    call menu_item                                    ; 14FD  E8 1A 00
    mov si, pmenu_citoh                               ; 1500  BE C2 14
    mov dl, 1                                         ; 1503  B2 01
    call menu_item                                    ; 1505  E8 12 00
    mov si, pmenu_fx                                  ; 1508  BE CC 14
    mov dl, 0                                         ; 150B  B2 00
    call menu_item                                    ; 150D  E8 0A 00
    mov ah, 9                                         ; 1510  B4 09
    mov dx, pmenu_crlf                                ; 1512  BA D7 14
    int 0x21                                          ; 1515  CD 21
    jmp short setup                                   ; 1517  EB 2B
    nop                                               ; 1519  90
; menu_item: พิมพ์ข้อความที่ DS:SI ทีละตัวอักษรด้วย INT 10h AH=09h (CX=1) จนถึง '$'
;            DL = ชนิดเครื่องพิมพ์ของรายการนี้ — ตรงกับ [prn_type] ใช้สี BL=70h (กลับสี) , ไม่งั้นใช้ BL เดิม (20h)
;            พิมพ์แล้วเลื่อนเคอร์เซอร์เองด้วย AH=03h (อ่านตำแหน่ง) + AH=02h (+1 คอลัมน์) เพราะ AH=09h ไม่เลื่อน
menu_item:
    cmp dl, byte [prn_type]                           ; 151A  3A 16 04 01
    jne mi_attr_done                                  ; 151E  75 03
    mov bx, 0x70                                      ; 1520  BB 70 00
mi_attr_done:
    mov al, byte [si]                                 ; 1523  8A 04
    cmp al, 0x24                                      ; 1525  3C 24
    je mi_end                                         ; 1527  74 17
    push ax                                           ; 1529  50
    push bx                                           ; 152A  53
    push cx                                           ; 152B  51
    push si                                           ; 152C  56
    int 0x10                                          ; 152D  CD 10
    mov ah, 3                                         ; 152F  B4 03
    int 0x10                                          ; 1531  CD 10
    inc dl                                            ; 1533  FE C2
    mov ah, 2                                         ; 1535  B4 02
    int 0x10                                          ; 1537  CD 10
    pop si                                            ; 1539  5E
    pop cx                                            ; 153A  59
    pop bx                                            ; 153B  5B
    pop ax                                            ; 153C  58
    inc si                                            ; 153D  46
    jmp short mi_attr_done                            ; 153E  EB E3
mi_end:
    mov bx, 0x20                                      ; 1540  BB 20 00
    ret                                               ; 1543  C3
; setup: เก็บเวกเตอร์เดิมของ INT 16h (0000:0058h), INT 10h (0040h), INT 17h (005Ch) ไว้ใน operand ของ
;        คำสั่ง jmp ส่งต่อ แล้วชี้เวกเตอร์ทั้งสามมาที่ hook ของ TSR นี้,
;        ตั้งเวกเตอร์ INT 69h (01A4h) = CS:0C0Ch และสั่งอยู่ถาวรด้วย INT 27h (DX=014DAh = สิ้นสุดส่วนถาวร)
setup:
    mov ax, 0                                         ; 1544  B8 00 00
    mov es, ax                                        ; 1547  8E C0
    mov ax, word [es:0x58]                            ; 1549  26 A1 58 00
    mov bx, old16_vec                                 ; 154D  BB C6 05
    mov word [bx], ax                                 ; 1550  89 07
    mov ax, word [es:0x5a]                            ; 1552  26 A1 5A 00
    mov word [bx + 2], ax                             ; 1556  89 47 02
    mov word [es:0x58], hook16                        ; 1559  26 C7 06 58 00 CA 05
    mov ax, cs                                        ; 1560  8C C8
    mov word [es:0x5a], ax                            ; 1562  26 A3 5A 00
    mov ax, word [es:0x40]                            ; 1566  26 A1 40 00
    mov bx, old10_vec                                 ; 156A  BB E1 07
    mov word [bx], ax                                 ; 156D  89 07
    mov ax, word [es:0x42]                            ; 156F  26 A1 42 00
    mov word [bx + 2], ax                             ; 1573  89 47 02
    mov word [es:0x40], hook10                        ; 1576  26 C7 06 40 00 C9 07
    mov ax, cs                                        ; 157D  8C C8
    mov word [es:0x42], ax                            ; 157F  26 A3 42 00
    mov ax, word [es:0x5c]                            ; 1583  26 A1 5C 00
    mov bx, old17_vec                                 ; 1587  BB 80 0A
    mov word [bx], ax                                 ; 158A  89 07
    mov ax, word [es:0x5e]                            ; 158C  26 A1 5E 00
    mov word [bx + 2], ax                             ; 1590  89 47 02
    mov word [es:0x5c], hook17                        ; 1593  26 C7 06 5C 00 68 0A
    mov ax, cs                                        ; 159A  8C C8
    mov word [es:0x5e], ax                            ; 159C  26 A3 5E 00
    mov word [es:0x1a4], hook69                       ; 15A0  26 C7 06 A4 01 0C 0C
    mov ax, cs                                        ; 15A7  8C C8
    mov word [es:0x1a6], ax                           ; 15A9  26 A3 A6 01
    mov dx, install                                   ; 15AD  BA DA 14
    int 0x27                                          ; 15B0  CD 27
