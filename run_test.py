# -*- coding: utf-8 -*-
"""Run THAI.COM (TSR install) + TESTTSX.COM under Unicorn with a mini BIOS/DOS.

Real code is executed: THAI.COM installs its hooks into the IVT, TESTTSX.COM
calls the INT 69h API, and all INT 10h/16h/17h traffic goes through the real
TSX hook code.  BIOS/DOS services are emulated in Python (screen 80x25,
scripted keyboard, printer capture).
"""
import struct
import sys

from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn.x86_const import (UC_X86_REG_AX, UC_X86_REG_BX, UC_X86_REG_CX, UC_X86_REG_DX,
                               UC_X86_REG_SP, UC_X86_REG_EIP, UC_X86_REG_EFLAGS,
                               UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS)

TSX_SEG, TEST_SEG, STUB_SEG = 0x2000, 0x4000, 0xF000
W, H = 80, 25

AX, BX, CX, DX, SP, EIP, EFLAGS, CS, DS, ES, SS = (
    UC_X86_REG_AX, UC_X86_REG_BX, UC_X86_REG_CX, UC_X86_REG_DX, UC_X86_REG_SP,
    UC_X86_REG_EIP, UC_X86_REG_EFLAGS, UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS)

tsx_bytes = open(r'C:\Users\too\github\tsx_disasm\THAI.COM', 'rb').read()
test_bytes = open(r'testtsx.com', 'rb').read()

uc = Uc(UC_ARCH_X86, UC_MODE_16)
uc.mem_map(0, 0x110000)
uc.mem_write((TSX_SEG << 4) + 0x100, tsx_bytes)
uc.mem_write((TEST_SEG << 4) + 0x100, test_bytes)

# ---------------- keyboard script ----------------
# (ascii, scan) — คีย์ผ่าน INT 16h ตัวเดิม แล้ว TSX แปลงเป็นรหัส KU เอง
KEYS = [
    (0x58, 0x2A),   # THAI.COM banner: press any key -> 'X'
    (0x66, 0x21),   # AH=08h test: 'f' -> ktbl[0x66] = 0xB2 (ด)
    (0x6B, 0x25),   # AH=09h test: 'k' -> 0xCE (า)
    (0x6C, 0x26),   #               'l' -> 0xC7 (ส)
    (0x1B, 0x01),   #               ESC -> จบลูป
    (0x6D, 0x32),   # AH=0Ah line: 'm' -> 0xB5 (ท)
    (0x66, 0x21),   #               'f' -> 0xB2 (ด)
    (0x6C, 0x26),   #               'l' -> 0xC7 (ส)
    (0x76, 0x2F),   #               'v' -> 0xCA (อ)
    (0x5B, 0x1A),   #               '[' -> 0xB8 (บ)
    (0x0D, 0x1C),   #               ENTER
]

# ---------------- screen ----------------
screen = [bytearray(b' ' * W) for _ in range(H)]
attrs = [[0x07] * W for _ in range(H)]
cur = [0, 0]                    # row, col
hist = bytearray()              # ทุกตัวอักษรที่ผ่าน teletype (สำหรับตรวจผล)
prn = bytearray()               # ทุกไบต์ที่ส่งออกเครื่องพิมพ์
log = []


def scroll():
    screen.pop(0)
    attrs.pop(0)
    screen.append(bytearray(b' ' * W))
    attrs.append([0x07] * W)
    cur[0] = H - 1


def cell(r, c, ch, a=0x07):
    if 0 <= r < H and 0 <= c < W:
        screen[r][c] = ch
        attrs[r][c] = a


def teletype(ch, a=0x07):
    """BIOS INT 10h AH=0Eh semantics."""
    hist.append(ch)
    if ch == 0x0D:
        cur[1] = 0
    elif ch == 0x0A:
        cur[0] += 1
        if cur[0] >= H:
            scroll()
    elif ch == 0x08:
        cur[1] = max(0, cur[1] - 1)
    elif ch == 0x07 or ch == 0x1B:
        pass
    else:
        cell(cur[0], cur[1], ch, a)
        cur[1] += 1
        if cur[1] >= W:
            cur[1] = 0
            cur[0] += 1
            if cur[0] >= H:
                scroll()


def dos_raw(ch):
    """DOS console output: processes control codes, advances cursor."""
    if ch in (0x07, 0x08, 0x0A, 0x0D):
        teletype(ch)
        return
    cell(cur[0], cur[1], ch)
    hist.append(ch)
    cur[1] += 1
    if cur[1] >= W:
        cur[1] = 0
        cur[0] += 1
        if cur[0] >= H:
            scroll()


# ---------------- unicorn helpers ----------------
def g16(name):
    return uc.reg_read(name) & 0xFFFF


def s16(name, v):
    uc.reg_write(name, v & 0xFFFF)


def stack_word(sp, off):
    a = (g16(SS) << 4) + ((sp + off) & 0xFFFF)
    return int.from_bytes(uc.mem_read(a, 2), 'little')


def stack_put(sp, off, v):
    a = (g16(SS) << 4) + ((sp + off) & 0xFFFF)
    uc.mem_write(a, struct.pack('<H', v & 0xFFFF))


# ---------------- BIOS / DOS services ----------------
def bios10():
    ax = g16(AX)
    ah, al = ax >> 8, ax & 0xFF
    if ah == 0x0E:
        teletype(al, g16(BX) & 0xFF)
    elif ah == 0x03:
        s16(DX, (cur[0] << 8) | cur[1])
        s16(CX, 0x0607)
    elif ah == 0x02:
        cur[0] = min((g16(DX) >> 8) & 0xFF, H - 1)
        cur[1] = g16(DX) & 0xFF
    elif ah == 0x09:
        a = g16(AX) & 0xFF
        b = g16(BX) & 0xFF
        for _ in range(g16(CX)):
            cell(cur[0], cur[1], a, b)
    elif ah == 0x0F:
        s16(AX, (0x80 << 8) | 0x03)
        s16(BX, 0)


def bios16():
    ax = g16(AX)
    ah = ax >> 8
    if ah == 0x00:
        al, sc = KEYS.pop(0) if KEYS else (0, 0)
        s16(AX, (sc << 8) | al)
        log.append('int16 read: %02X/%02X' % (al, sc))
    elif ah == 0x01:
        if KEYS:
            al, sc = KEYS[0]
            s16(AX, (sc << 8) | al)
            uc.reg_write(UC_X86_REG_EFLAGS, uc.reg_read(UC_X86_REG_EFLAGS) & ~0x40)
        else:
            uc.reg_write(UC_X86_REG_EFLAGS, uc.reg_read(UC_X86_REG_EFLAGS) | 0x40)
    elif ah == 0x02:
        s16(AX, 0)


def bios17():
    ax = g16(AX)
    ah, al = ax >> 8, ax & 0xFF
    if ah == 0x00:
        prn.append(al)
    elif ah == 0x02:
        s16(AX, (0x90 << 8) | al)


def dos21():
    ax = g16(AX)
    ah = ax >> 8
    if ah == 0x09:
        a = (g16(DS) << 4) + g16(DX)
        for _ in range(10000):
            b = uc.mem_read(a, 1)[0]
            if b == 0x24:
                break
            dos_raw(b)
            a += 1
    elif ah == 0x07:
        al, sc = KEYS.pop(0) if KEYS else (0, 0)
        s16(AX, (sc << 8) | al)
        log.append('int21 AH=7 key: %02X' % al)
    elif ah == 0x02:
        dos_raw(g16(DX) & 0xFF)
    elif ah == 0x4C:
        uc.emu_stop()


FINISHED = []


def dispatch_ivt(intno):
    # dispatch ผ่าน IVT จริง (TSX hook ครอบ 10h/16h/17h อยู่ในนั้นหลังติดตั้ง)
    v_ip = int.from_bytes(uc.mem_read(intno * 4, 2), 'little')
    v_cs = int.from_bytes(uc.mem_read(intno * 4 + 2, 2), 'little')
    ret_ip, ret_cs = g16(EIP), g16(CS)
    flags = uc.reg_read(UC_X86_REG_EFLAGS) & 0xFFFF
    sp = g16(SP) - 2
    stack_put(sp, 0, flags)
    sp -= 2
    stack_put(sp, 0, ret_cs)
    sp -= 2
    stack_put(sp, 0, ret_ip)
    s16(SP, sp)
    s16(EIP, v_ip)
    s16(CS, v_cs)


def hook_intr(uc_, intno, data):
    # unicorn: EIP ชี้คำสั่ง "ถัดจาก" INT แล้ว และไม่มีการ push frame ให้เอง
    if intno in (0x10, 0x16, 0x17, 0x69):
        dispatch_ivt(intno)
        return

    if intno in (0x10, 0xFE):
        bios10()
    elif intno in (0x16, 0xFD):
        bios16()
    elif intno in (0x17, 0xFC):
        bios17()
    elif intno == 0x20:
        FINISHED.append('int20')
        uc.emu_stop()
        return
    elif intno == 0x21:
        dos21()
    elif intno == 0x27:
        FINISHED.append('int27(TSR installed, resident through 0x%04X)' % g16(DX))
        uc.emu_stop()
        return
    else:
        pass                               # int อื่น: ไม่มีในโปรแกรมนี้

    if intno in (0xFE, 0xFD, 0xFC):
        # stub: กลับไปยังผู้เรียก TSX โดยเลิก frame ของ pushf + call far
        sp = g16(SP)
        ret_ip, ret_cs = stack_word(sp, 0), stack_word(sp, 2)
        s16(SP, sp + 6)
        s16(EIP, ret_ip)
        s16(CS, ret_cs)
    # int อื่นที่จัดการใน Python: EIP ชี้คำสั่งถัดไปอยู่แล้ว


# ---------------- install stub vectors (BIOS เดิมก่อน TSX ติดตั้ง) ----------------
uc.mem_write((STUB_SEG << 4) + 0x100, bytes([0xCD, 0xFD]))   # int16 stub -> int FD
uc.mem_write((STUB_SEG << 4) + 0x110, bytes([0xCD, 0xFE]))   # int10 stub -> int FE
uc.mem_write((STUB_SEG << 4) + 0x120, bytes([0xCD, 0xFC]))   # int17 stub -> int FC
for n, off in ((0x16, 0x100), (0x10, 0x110), (0x17, 0x120)):
    uc.mem_write(n * 4, struct.pack('<HH', off, STUB_SEG))

uc.hook_add(UC_HOOK_INTR, hook_intr)


def run(seg):
    for r in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS):
        uc.reg_write(r, seg)
    uc.reg_write(UC_X86_REG_EIP, 0x100)
    uc.reg_write(UC_X86_REG_SP, 0xFFFE)
    uc.emu_start((seg << 4) + 0x100, 0, 0, 20_000_000)


# ---------------- run THAI.COM (install) ----------------
print('=== running THAI.COM (TSR install) ===')
run(TSX_SEG)
print('install finished:', FINISHED)

# ---------------- run TESTTSX.COM ----------------
print('=== running TESTTSX.COM ===')
FINISHED.clear()
run(TEST_SEG)
print('test finished:', FINISHED)
print('keys left in queue:', len(KEYS))
print('printer bytes captured:', len(prn))
print()
print('=== console history (teletype stream, KU decoded) ===')

# KU -> Thai for readable dump
KU2TH = {
    0xA1: 'ก', 0xA2: 'ข', 0xA3: 'ค', 0xA4: 'ฆ', 0xA5: 'ง', 0xA6: 'จ', 0xA7: 'ฉ', 0xA8: 'ช',
    0xA9: 'ซ', 0xAA: 'ฌ', 0xAB: 'ฎ', 0xAC: 'ฏ', 0xAD: 'ฐ', 0xAE: 'ฑ', 0xAF: 'ฒ', 0xB1: 'ณ',
    0xB2: 'ด', 0xB3: 'ต', 0xB4: 'ถ', 0xB5: 'ท', 0xB6: 'ธ', 0xB7: 'น', 0xB8: 'บ', 0xB9: 'ป',
    0xBA: 'ผ', 0xBB: 'ฝ', 0xBC: 'พ', 0xBD: 'ฟ', 0xBE: 'ภ', 0xBF: 'ม', 0xC0: 'ย', 0xC1: 'ร',
    0xC2: 'ฤ', 0xC3: 'ล', 0xC4: 'ว', 0xC5: 'ศ', 0xC6: 'ษ', 0xC7: 'ส', 0xC8: 'ห', 0xC9: 'ฬ',
    0xCA: 'อ', 0xCB: 'ฮ', 0xCC: 'ะ', 0xCE: 'า', 0xCF: 'ำ', 0xD0: 'เ', 0xD1: 'แ', 0xD2: 'โ',
    0xD3: 'ใ', 0xD4: 'ไ', 0xD5: 'ๆ', 0xD7: 'ุ', 0xD8: 'ู', 0xD9: 'ิ', 0xDA: 'ี', 0xDB: 'ึ',
    0xDC: 'ื', 0xDD: 'ั', 0xE0: '่', 0xE1: '้', 0xE2: '๊', 0xE3: '๋', 0xE4: '์',
}
LIG = {}
for v in range(0xD9, 0xDF):
    pass
OFF = {0x06: 0xDE, 0x0E: 0xD9, 0x0A: 0xDD, 0x13: 0xDA, 0x17: 0xDB, 0x1B: 0xDC}


def dec(b):
    if b in KU2TH:
        ch = KU2TH[b]
        return '\u25cc' + ch if (0xD7 <= b <= 0xE4) else ch
    if 0xE6 <= b <= 0xFE:
        t, k = divmod(b - 0xE6, 4)
        vow = OFF.get(k * 4 + 6)
        if vow:
            return KU2TH[vow] + KU2TH[0xE0 + t]
    if 32 <= b < 127:
        return chr(b)
    return {0x0D: '<CR>', 0x0A: '<LF>\n', 0x07: '<BEL>'}.get(b, '<%02X>' % b)


out = ''.join(dec(b) for b in hist)
print(out)

# ---------------- assertions ----------------
print('=== assertions ===')
text = out


def check(name, ok, detail=''):
    print(('PASS' if ok else 'FAIL') + '  ' + name + ('  ' + detail if detail else ''))
    return ok


ok = True
ok &= check('f09 read key translated to KU (f -> 0xB2)', 'code = 0xB2' in text)
ok &= check('AH=09h echo keys (k -> 0xCE, l -> 0xC7)', 'code = 0xCE' in text and 'code = 0xC7' in text)
ok &= check('ESC ends the echo loop', 'code = 0x1B' not in text)
ok &= check('known bug reproduced: disp3 = 0x0D after AH=0Ah', 'disp3 after AH=0Ah = 0x0D' in text)
ok &= check('line buffer: count=6, codes B5 B2 C7 CA B8 0D', '06:B5 B2 C7 CA B8 0D' in text)
# แถวจอ: หา "แถวล่าง" (มีทั้ง ◌ุ และ ◌ู) — ฐานอยู่แถวเหนือขึ้นหนึ่ง, สระบนอยู่อีกสองแถวขึ้นไป
low_row = None
for r in range(H):
    line = ''.join(dec(b) if b >= 0x80 else chr(b) for b in screen[r])
    if '\u25ccุ' in line and '\u25ccู' in line:
        low_row = r
if low_row is not None:
    upr = ''.join(dec(b) if b >= 0x80 else chr(b) for b in screen[low_row - 2])
    lwr = ''.join(dec(b) if b >= 0x80 else chr(b) for b in screen[low_row])
    bas = ''.join(dec(b) if b >= 0x80 else chr(b) for b in screen[low_row - 1])
else:
    upr = lwr = bas = ''
ok &= check('3-level: ligature ั้ (EB) merged on upper row', low_row is not None and 'ั้' in upr, 'upper="%s"' % upr.strip())
ok &= check('3-level: tone ่ ้ on upper row', low_row is not None and '◌่' in upr and '◌้' in upr)
ok &= check('3-level: ุ ู on lower row', low_row is not None and '◌ุ' in lwr and '◌ู' in lwr, 'lower="%s"' % lwr.strip())
ok &= check('3-level: base row has the Thai words', low_row is not None and 'ง' in bas and 'ก' in bas, 'base="%s"' % bas.strip())
if low_row is not None:
    print()
    print('=== screen rows around the Thai test line ===')
    for r in range(max(0, low_row - 2), min(H, low_row + 2)):
        line = ''.join(dec(b) if b >= 0x80 else chr(b) for b in screen[r]).rstrip()
        print('%2d |%s|' % (r, line))
print()
print('RESULT:', 'ALL PASS' if ok else 'SOME CHECKS FAILED')
sys.exit(0 if ok else 1)
