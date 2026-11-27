#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate an annotated NASM-style disassembly of THAI.COM (TSX v3.51).

usage: python -I gen_disasm.py THAI.COM OUT.asm

Every byte of the input is emitted exactly once (code via capstone, data via
db/dw) and all branch targets are checked to land on instruction starts.
"""
import hashlib
import re
import sys

from capstone import Cs, CS_ARCH_X86, CS_MODE_16

ORG = 0x100
SRC = open(sys.argv[1], 'rb').read()
OUT = sys.argv[2]

assert len(SRC) == 0x14B2, len(SRC)
assert hashlib.md5(SRC).hexdigest() == 'd4db5c5ddd4bfc4bdeed613ba632bcc9'


def b(a):
    return SRC[a - ORG]


def w(a):
    return SRC[a - ORG] | (SRC[a - ORG + 1] << 8)


# --------------------------------------------------------------------------
# symbols
# --------------------------------------------------------------------------
VARS = [  # (addr, name, size, comment)
    (0x0104, 'prn_type', 1, 'ชนิดเครื่องพิมพ์ : 0 = FX100 , 1 = CITOH , 2 = LQ1500 (ค่าเริ่มต้น 1)'),
    (0x0105, 'kbd_mode', 1, 'โหมดแป้นพิมพ์ : 00h = อังกฤษ (ไม่แปลรหัส) , FFh = ไทย (ASCII -> KU)'),
    (0x0106, 'disp3', 1, 'การแสดงผล : 00h = 1 ระดับ (ส่งตรงให้ BIOS) , FFh = 3 ระดับ (putc3)'),
    (0x0107, 'dlf', 1, '00h = LF เดี่ยว (12 บรรทัด/จอ) , FFh = LF คู่ (8 บรรทัด/จอ)'),
    (0x0108, 'mono', 1, 'ชนิดจอ (รูปเคอร์เซอร์) : 00h = จอสี (บรรทัดสแกน 5-6) , FFh = จอโมโน (9-10)'),
    (0x0109, 'noskip', 1, 'FFh = ปิดกฎเว้นวรรค 3 ครั้งหลังสระบน (space_skip) — ถูกสลับทุกครั้งที่กด Backspace'),
    (0x010A, 'col', 1, 'เลขคอลัมน์ปัจจุบันของบรรทัดบนจอ (ใช้ตัดบรรทัดที่ 80)'),
    (0x010B, 'spc3', 1, 'จำนวนเว้นวรรคติดกันหลังสระบน (space_skip)'),
    (0x010C, 'tspc', 1, 'จำนวนเว้นวรรคติดกันในโหมดไทย (ครบ 3 -> A0h)'),
    (0x010D, 'upr', 1, 'จำนวนสระบน/วรรณยุกต์ที่พิมพ์แล้วในคอลัมน์ปัจจุบัน'),
    (0x010E, 'blen', 1, 'จำนวนไบต์ที่เก็บใน lbuf'),
    (0x010F, 'upc', 1, 'สระบน/วรรณยุกต์ตัวล่าสุดของคอลัมน์ (ใช้ใน merge)'),
    (0x0110, 'pspc', 1, 'จำนวนเว้นวรรคติดกันของเครื่องพิมพ์ (p_space)'),
    (0x0111, 'prn3', 1, 'โหมดเครื่องพิมพ์ : 00h = 1 ระดับ (ส่งตรงให้ BIOS) , FFh = 3 ระดับ'),
    (0x0112, 'pmark', 1, 'จำนวนสระบน/ล่างที่พบในคำปัจจุบัน (เครื่องพิมพ์)'),
    (0x0113, 'ppos', 1, 'ตำแหน่งคอลัมน์ปัจจุบันในบัฟเฟอร์เครื่องพิมพ์'),
    (0x0114, 'pad114', 1, 'ไม่มีโค้ดอ้างถึง (ค่า 50h = 80 เหลืออยู่ในไฟล์)'),
    (0x0115, 'pwid', 1, 'ความกว้างบรรทัดของเครื่องพิมพ์ = 131 (132 คอลัมน์) — ไม่มีโค้ดเปลี่ยนค่า'),
    (0x0116, 'pbuf', 2, 'บัฟเฟอร์ระดับที่กำลังใช้ (lvl_u / lvl_m / lvl_l)'),
    (0x0118, 'cur_row', 1, 'ตำแหน่งเคอร์เซอร์ล่าสุด — ถูกเขียนใน putc_norm แต่ไม่มีโค้ดอ่าน'),
    (0x0119, 'cur_col', 1, ''),
]
DATA_LABELS = [  # (addr, name)
    (0x011A, 'ktbl'), (0x019A, 'lvl_u'), (0x029A, 'lvl_m'), (0x039A, 'lvl_l'),
    (0x049A, 'lbuf'), (0x0599, 'keytab'), (0x0BD6, 'sv_es'), (0x0BD8, 'sv_ds'),
    (0x0BDA, 'sv_bp'), (0x0BDC, 'sv_di'), (0x0BDE, 'sv_si'), (0x0BE0, 'sv_dx'),
    (0x0BE2, 'sv_cx'), (0x0BE4, 'sv_bx'), (0x0BE6, 'sv_ax'), (0x0BE8, 'fntab'),
    (0x0DF8, 'banner'), (0x1141, 'cmdlist'), (0x14AB, 'pmenu_hdr'),
    (0x14B8, 'pmenu_lq'), (0x14C2, 'pmenu_citoh'), (0x14CC, 'pmenu_fx'),
    (0x14D6, 'pmenu_nul'), (0x14D7, 'pmenu_crlf'),
]
CODE_LABELS = {  # addr: name
    0x14DA: 'install', 0x151A: 'menu_item', 0x1544: 'setup',
    0x05C5: 'hook16_jmp', 0x05CA: 'hook16', 0x05E0: 'kbd_read', 0x060D: 'key_done',
    0x0613: 'key_space', 0x0616: 'bios_key', 0x0621: 'tbl_find',
    0x0633: 'fn_disp1', 0x063A: 'fn_disp3', 0x0641: 'fn_prn1', 0x065E: 'fn_prn3',
    0x067B: 'fn_lines', 0x0690: 'fn_mono', 0x06C3: 'fn_prn_norm', 0x06DB: 'fn_prn_cond',
    0x06F3: 'fn_english', 0x070C: 'fn_thai', 0x071B: 'key_none',
    0x071D: 'pr_esc1', 0x0728: 'pr_esc2', 0x0733: 'pr_escA', 0x073E: 'pr_esc3_14',
    0x074E: 'pr_esc3_17', 0x075E: 'pr_escT16', 0x0773: 'pr_dc2', 0x0779: 'pr_dc2b',
    0x077D: 'pr_escN', 0x0788: 'pr_dc4', 0x078E: 'pr_dc4b', 0x0792: 'pr_escQ',
    0x079D: 'beep', 0x07A5: 'call_old10', 0x07AE: 'thai_space',
    0x07C9: 'hook10', 0x07E0: 'hook10_jmp', 0x07E5: 'hook10_work',
    0x080E: 'cmd83_thai', 0x0811: 'cmd81_english', 0x0814: 'cmd80_disp1',
    0x0817: 'cmd82_disp3', 0x081A: 'cmd84_prn1', 0x081D: 'cmd85_prn3',
    0x0820: 'bios10', 0x082E: 'putc3', 0x085F: 'is_space', 0x0862: 'is_cr',
    0x0865: 'is_bs', 0x0868: 'putc_ctrl', 0x086C: 'do_cr', 0x0876: 'newline',
    0x0893: 'no_dlf', 0x089F: 'space_skip', 0x08BB: 'skip_loop', 0x08DD: 'skip_end',
    0x08E3: 'lbuf_put', 0x08FA: 'putc_norm', 0x0914: 'put_lower', 0x092A: 'cur_down',
    0x0936: 'cur_up', 0x0947: 'cur_left', 0x0956: 'cur_right', 0x0967: 'merge',
    0x09BE: 'mrk_de', 0x09C1: 'mrk_dd', 0x09C4: 'mrk_d9', 0x09C7: 'mrk_da',
    0x09CA: 'mrk_db', 0x09CD: 'mrk_dc', 0x09D0: 'put_upper', 0x09E9: 'backspace',
    0x0A29: 'bs_lower', 0x0A3E: 'bs_upper', 0x0A68: 'hook17', 0x0A7F: 'hook17_jmp',
    0x0A84: 'hook17_work', 0x0A92: 'prn_putc', 0x0AEB: 'bios_print',
    0x0B03: 'is_pspace', 0x0B0B: 'p_cr', 0x0B15: 'p_flush_body', 0x0B37: 'p_clear',
    0x0B51: 'flush', 0x0B57: 'p_type', 0x0B7C: 'pbuf_put', 0x0B94: 'p_space',
    0x0BB0: 'p_sp_loop', 0x0BD0: 'p_sp_end',
    0x0C0C: 'hook69', 0x0C2D: 'save_regs', 0x0C4D: 'rest_regs', 0x0C6A: 'fn_find',
    0x0C7C: 'f01_get_kbd', 0x0C83: 'f02_get_disp', 0x0C8E: 'f03_get_prn',
    0x0C95: 'f04_set_kbd', 0x0CB0: 'f04_english', 0x0CC8: 'f05_set_disp',
    0x0CE1: 'f06_set_lines', 0x0CFA: 'f07_set_prn', 0x0D07: 'prn3_init',
    0x0D21: 'prn1_init', 0x0D3B: 'f08_set_ptype', 0x0D56: 'f08_type_init',
    0x0D6B: 'f09_read_key', 0x0D8C: 'f0A_read_echo', 0x0DA1: 'f0B_read_line',
    0x0DF7: 'fn_none',
}
EQU = [  # (name, expression, addr) -- labels that sit inside the operand of a far jmp
    ('old16_vec', 'hook16_jmp+1', 0x05C6),
    ('old10_vec', 'hook10_jmp+1', 0x07E1),
    ('old17_vec', 'hook17_jmp+1', 0x0A80),
]
CODE_LABELS.update({
    0x05E2: 'kbd_again',
    0x05FC: 'kbd_check',
    0x062F: 'tbl_found',
    0x0654: 'prn1_fx',
    0x0659: 'prn1_citoh',
    0x065C: 'prn1_done',
    0x0671: 'prn3_fx',
    0x0676: 'prn3_citoh',
    0x0679: 'prn3_done',
    0x0689: 'lines_off',
    0x068E: 'lines_done',
    0x06AD: 'mono_set',
    0x06C1: 'mono_done',
    0x06D1: 'norm_fx',
    0x06D6: 'norm_citoh',
    0x06D9: 'norm_done',
    0x06E9: 'cond_fx',
    0x06EE: 'cond_citoh',
    0x06F1: 'cond_done',
    0x0707: 'eng_cursor',
    0x07C0: 'ts_plain',
    0x07C1: 'ts_a0',
    0x07D4: 'hook10_go',
    0x080A: 'hook10_plain',
    0x0842: 'putc3_store',
    0x0859: 'is_upper',
    0x085C: 'is_lower',
    0x0925: 'low_inc',
    0x09E4: 'upr_inc',
    0x096E: 'merge_store',
    0x0972: 'merge_have',
    0x0980: 'merge_tone_new',
    0x098A: 'merge_vowel_new',
    0x0992: 'merge_apply',
    0x09F8: 'bs_set',
    0x09FD: 'bs_check',
    0x0A0A: 'bs_dec',
    0x0A55: 'bs_up_print',
    0x0A7B: 'hook17_a20',
    0x0A7E: 'hook17_chain',
    0x0AAD: 'prn_char',
    0x0AC0: 'prn_mark',
    0x0AD6: 'prn_upper',
    0x0AEA: 'prn_ret',
    0x0B06: 'prn_wrapped',
    0x0B42: 'pc_fill',
    0x0B61: 'ptype_loop',
    0x0B9E: 'psp_count',
    0x0BAC: 'psp_3rd',
    0x0C78: 'fn_found',
    0x0CC4: 'f04_cursor',
    0x0CC7: 'f04_ret',
    0x0CDB: 'f05_one',
    0x0CE0: 'f05_keep',
    0x0CF4: 'f06_single',
    0x0CF9: 'f06_ret',
    0x0D19: 'prn3i_fx',
    0x0D1D: 'prn3i_citoh',
    0x0D33: 'prn1i_fx',
    0x0D37: 'prn1i_citoh',
    0x0D3A: 'set_prn_ret',
    0x0D53: 'f08_1level',
    0x0D63: 'pti_fx',
    0x0D67: 'pti_citoh',
    0x0D6A: 'pti_done',
    0x0D7B: 'f09_upper',
    0x0D85: 'f09_store',
    0x0D88: 'f09_ret',
    0x0DB6: 'f0b_loop',
    0x0DBF: 'f0b_done',
    0x0DDD: 'f0b_copy',
    0x1523: 'mi_attr_done',
    0x1540: 'mi_end',
})
SYM = {a: n for a, n, _, _ in VARS}
SYM.update({a: n for a, n in DATA_LABELS})
SYM.update(CODE_LABELS)
SYM.update({a: n for n, _, a in EQU})

# KU code -> Thai (รหัสภาษาไทยแบบเกษตร ตามที่ปรากฏในไฟล์นี้)
KU2TH = {
    0xA1: 'ก', 0xA2: 'ข', 0xA3: 'ค', 0xA4: 'ฆ', 0xA5: 'ง', 0xA6: 'จ', 0xA7: 'ฉ', 0xA8: 'ช',
    0xA9: 'ซ', 0xAA: 'ฌ', 0xAB: 'ฎ', 0xAC: 'ฏ', 0xAD: 'ฐ', 0xAE: 'ฑ', 0xAF: 'ฒ', 0xB0: '?',
    0xB1: 'ณ', 0xB2: 'ด', 0xB3: 'ต', 0xB4: 'ถ', 0xB5: 'ท', 0xB6: 'ธ', 0xB7: 'น', 0xB8: 'บ',
    0xB9: 'ป', 0xBA: 'ผ', 0xBB: 'ฝ', 0xBC: 'พ', 0xBD: 'ฟ', 0xBE: 'ภ', 0xBF: 'ม', 0xC0: 'ย',
    0xC1: 'ร', 0xC2: 'ฤ', 0xC3: 'ล', 0xC4: 'ว', 0xC5: 'ศ', 0xC6: 'ษ', 0xC7: 'ส', 0xC8: 'ห',
    0xC9: 'ฬ', 0xCA: 'อ', 0xCB: 'ฮ', 0xCC: 'ะ', 0xCD: '?', 0xCE: 'า', 0xCF: 'ำ', 0xD0: 'เ',
    0xD1: 'แ', 0xD2: 'โ', 0xD3: 'ใ', 0xD4: 'ไ', 0xD5: 'ๆ', 0xD6: '?', 0xD7: 'ุ', 0xD8: 'ู',
    0xD9: 'ิ', 0xDA: 'ี', 0xDB: 'ึ', 0xDC: 'ื', 0xDD: 'ั', 0xDE: '?', 0xDF: '?', 0xE0: '่',
    0xE1: '้', 0xE2: '๊', 0xE3: '๋', 0xE4: '์',
}
LOWER = {0xD7, 0xD8}
UPPER_VOWEL = set(range(0xD9, 0xDF))
OFF = {0x06: 0xDE, 0x0E: 0xD9, 0x13: 0xDA, 0x17: 0xDB, 0x1B: 0xDC, 0x0A: 0xDD}  # merge(): offset <- vowel code


def lig_parts(c):
    """(vowel, tone) for a ligature code E6h..FEh, or None."""
    if 0xE6 <= c <= 0xFE:
        t, k = divmod(c - 0xE6, 4)
        return OFF.get(k * 4 + 6), 0xE0 + t
    return None


def ku(c):
    """Thai for a KU code, or None.  Upper/lower marks carry U+25CC so they stay readable."""
    if c in KU2TH:
        ch = KU2TH[c]
        return ('\u25cc' + ch) if (c in LOWER or c in UPPER_VOWEL or c >= 0xE0) and ch != '?' else ch
    if 0xE6 <= c <= 0xFE:
        vow, tone = lig_parts(c)
        if vow in KU2TH and KU2TH[vow] != '?':
            return KU2TH[vow] + KU2TH[tone]
    return None


def keyname(c):
    return {0x20: "' '", 0x09: "<TAB>", 0x0D: "<CR>", 0x0A: "<LF>", 0x07: "<BEL>",
            0x00: "<0>"}.get(c, "'" + chr(c) + "'" if 0x20 < c < 0x7F else "%02Xh" % c)


CTRL = {0x0D: '<CR>', 0x0A: '<LF>', 0x09: '<TAB>', 0x07: '<BEL>', 0x00: '<0>'}


def render(v):
    if 0x20 <= v < 0x7F:
        return chr(v)
    return ku(v) or CTRL.get(v, '.')


# --------------------------------------------------------------------------
# output helpers
# --------------------------------------------------------------------------
L = []            # output lines
cov = [None] * len(SRC)


def mark(a0, a1, what):
    for a in range(a0, a1):
        assert cov[a - ORG] is None, 'overlap at %04X (%s / %s)' % (a, cov[a - ORG], what)
        cov[a - ORG] = what


def C(*lines):
    for s in lines:
        L.append('; ' + s if s else ';')


def raw(s):
    L.append(s)


BRANCH = {'jmp', 'call', 'je', 'jne', 'jz', 'jnz', 'ja', 'jae', 'jb', 'jbe', 'jg', 'jge',
          'jl', 'jle', 'js', 'jns', 'jo', 'jno', 'jp', 'jnp', 'loop', 'loope', 'loopne',
          'jcxz'}

md = Cs(CS_ARCH_X86, CS_MODE_16)
CODE_RANGES = [(0x0100, 0x0104), (0x05C5, 0x0A68), (0x0A68, 0x0BD6), (0x0C0C, 0x0DF8), (0x14DA, 0x15B2)]
# reg<-reg opcodes whose RM form NASM canonicalizes to MR (same instruction, different bytes)
RM_REGREG = {0x02, 0x03, 0x0A, 0x0B, 0x12, 0x13, 0x1A, 0x1B, 0x22, 0x23, 0x2A, 0x2B,
             0x32, 0x33, 0x3A, 0x3B, 0x8A, 0x8B}
STARTS = set()   # all instruction start addresses
UNNAMED = set()  # branch targets seen while rendering
USED = set()     # symbol names used in operands


def sym_op(inner):
    m = re.fullmatch(r'0x([0-9a-f]+)', inner)
    if m and int(inner, 16) in SYM:
        USED.add(SYM[int(inner, 16)])
        return SYM[int(inner, 16)]
    return inner


def nasm(ins):
    mn, ops = ins.mnemonic, ins.op_str
    if mn == 'ljmp':
        mn = 'jmp'
    elif mn == 'lcall':
        mn, ops = 'call far', ops
    elif mn == 'jmp' and ins.bytes[0] == 0xE9:
        mn = 'jmp near'          # original used the 3-byte form; keep it
    elif mn == 'jmp' and ins.bytes[0] == 0xEB:
        mn = 'jmp short'         # original used the 2-byte form; keep it
    elif mn == 'xchg':
        mn, ops = 'xchg', ops.replace('byte ptr ', '').replace('word ptr ', '')
    parts = []
    for op in ops.split(', '):
        if not op:
            continue
        m = re.fullmatch(r'(byte|word) ptr (?:([a-z]{2}):)?\[(.+)\]', op)
        if m:
            size, seg, inner = m.groups()
            parts.append('%s [%s%s]' % (size, seg + ':' if seg else '', sym_op(inner)))
            continue
        m = re.fullmatch(r'(?:([a-z]{2}):)?\[(.+)\]', op)
        if m:
            seg, inner = m.groups()
            parts.append('[%s%s]' % (seg + ':' if seg else '', sym_op(inner)))
            continue
        m = re.fullmatch(r'0x([0-9a-f]+)', op)
        if m:
            v = int(op, 16)
            if mn in BRANCH:
                assert v in STARTS, 'branch to mid-instruction %04X from %04X' % (v, ins.address)
                UNNAMED.add(v)
            parts.append(sym_op(op))
            continue
        parts.append(op)
    return mn + (' ' + ', '.join(parts) if parts else '')


def code(a0, a1, pre, eolc):
    insns = list(md.disasm(SRC[a0 - ORG:a1 - ORG], a0))
    assert insns and insns[-1].address + insns[-1].size == a1, 'code range not fully decoded %04X-%04X' % (a0, a1)
    for i in insns:
        STARTS.add(i.address)
    for i in insns:
        if i.address in pre:
            C(*pre[i.address])
        if i.address in CODE_LABELS:
            raw('%s:' % CODE_LABELS[i.address])
        t = nasm(i)
        c = eolc.get(i.address)
        hx = ' '.join('%02X' % x for x in i.bytes)
        if len(i.bytes) == 2 and i.bytes[0] in RM_REGREG and (i.bytes[1] & 0xC0) == 0xC0:
            # the original assembler picked the RM form; NASM would emit the
            # equivalent MR form -- keep the original bytes verbatim via db
            btxt = ', '.join('0x%02X' % x for x in i.bytes)
            pad = ' ' * max(1, 54 - (4 + len(btxt)))
            tail = ('   ; ' + c[0]) if c else ''
            raw('    db %s%s; %04X  %s%s   ; "%s" -- RM form (NASM แอสเซมเบิลรูป MR ซึ่งความหมายเหมือนกัน)'
                % (btxt, pad, i.address, hx, tail, t))
            for extra in (c or [])[1:]:
                C(extra)
            continue
        pad = ' ' * max(1, 54 - (4 + len(t)))
        raw('    %s%s; %04X  %s%s' % (t, pad, i.address, hx,
                                       ('   ; ' + c[0]) if c else ''))
        for extra in (c or [])[1:]:
            C(extra)
        for n, e, a in EQU:
            if a == i.address + 1:
                raw('%s equ %s' % (n, e))
    mark(a0, a1, 'code')


def db_row(a0, a1, text=True):
    """db line for bytes [a0,a1) with address + textual rendering."""
    txt = ', '.join('0x%02X' % b(x) for x in range(a0, a1))
    raw('    db %s%s; %04X  %s' % (txt, ' ' * max(1, 54 - (7 + len(txt))), a0,
                                   ''.join(render(b(x)) if text else '.' for x in range(a0, a1))))


def db_rows(a0, a1, text=True):
    for a in range(a0, a1, 16):
        db_row(a, min(a + 16, a1), text)
    mark(a0, a1, 'data')


def db_text(a0, a1):
    """Text block: one comment line (address + readable text) per CR/LF-delimited line, then db rows."""
    a = a0
    while a < a1:
        e = a
        while e < a1 and b(e) != 0x0A:
            e += 1
        e = min(e + 1, a1)            # include the LF
        vis = [b(x) for x in range(a, e) if b(x) not in (0x0D, 0x0A)]
        if any(v not in (0x20, 0x09) for v in vis):
            C('%04Xh: "%s"' % (a, ''.join(render(v) for v in vis)))
        db_rows(a, e)
        a = e


# --------------------------------------------------------------------------
# pre-comments / end-of-line comments
# --------------------------------------------------------------------------
PRE = {}
EOL = {}


def P(a, *lines):
    PRE[a] = list(lines)


def E(a, *lines):
    EOL[a] = list(lines)


P(0x0100, 'จุดเข้าของ .COM: ข้ามไปยังส่วนติดตั้งที่ท้ายไฟล์ (ส่วนนั้นไม่ต้องคงไว้หลัง INT 27h)')

P(0x05C5,
  '============================== hook INT 16h ===============================',
  'hook16_jmp: ส่งต่อไปยัง INT 16h ตัวเดิมของ BIOS — เวกเตอร์เดิม (segment:offset) ถูกเก็บไว้ที่',
  '            old16_vec ซึ่งเป็น operand ของคำสั่ง jmp นี้เอง (setup เขียนทับตอนติดตั้ง)')
P(0x05CA,
  'hook16: ดักเฉพาะ AH=00h (อ่านคีย์และรอ) ส่วน AH อื่น (01h, 02h, 10h ...) ส่งต่อ BIOS ทันที',
  '        => โปรแกรมที่อ่านคีย์ด้วย AH=01h/10h จะได้คีย์ดิบโดยไม่ผ่านการแปลของ TSX')
P(0x05E0,
  'kbd_read: อ่านคีย์ 1 ตัวจาก BIOS แล้วประมวลผล (AX = AH:scan code, AL:รหัส ASCII)',
  '  ALT+Fn (AL=00)      : เรียก routine ตามตาราง keytab, บี๊ป แล้วอ่านคีย์ใหม่ — คีย์ถูกกลืน',
  '                        (routine ปิดท้ายด้วย STC ; ไม่พอคีย์ รายการปิดท้ายของตารางชี้ไป key_none ล้าง CF)',
  '  ENTER / รหัส < 20h  : ส่งคืนเดิม พร้อมล้างตัวนับเว้นวรคภาษาไทย (tspc)',
  '  SPACE (โหมดไทย)    : เว้นวรรคที่ 3 ติดกันให้รหัส A0h แทน 20h  (ดู thai_space)',
  '  โหมดไทย            : แปล ASCII -> รหัส KU ด้วย XLAT จากตาราง ktbl ; โหมดอังกฤษ : ส่งคืนเดิม')
E(0x05E5, 'ENTER ?')
E(0x05EB, 'SI = keytab ; เทียบ AX ทั้ง word (AL=00, AH=scan code)')
E(0x05F1, 'BX = routine ของคีย์นี้ (key_none ถ้าไม่พบ)')
E(0x05F5, 'CF=0 : ไม่ใช่คีย์ฟังก์ชัน')
E(0x05F7, 'CF=1 : เป็น ALT+Fn ที่จัดการแล้ว -> บี๊บ แล้วอ่านคีย์ใหม่')
E(0x05FC, 'รหัสควบคุม -> ส่งคืนเดิม')
E(0x0600, 'เว้นวรรค')
E(0x0602, 'FFh = โหมดไทย')
E(0x0609, 'XLAT: AL = [BX+AL]  (BX = ktbl)')
P(0x0616, 'bios_key: เรียก INT 16h ตัวเดิม (AH=00h) ผ่านเวกเตอร์ old16_vec โดยจำลอง interrupt (pushf)')
P(0x0621,
  'tbl_find: หา AX ในตาราง [SI] (รายการละ dw key, dw routine)',
  '          หาไม่พบจะหยุดที่รายการปิดท้าย (key=0) ซึ่งชี้ไป key_none',
  '          หมายเหตุ: ใช้ opcode 83h /r ซึ่งเป็นคำสั่งของ 80186 ขึ้นไป — บน 8086/8088 แท้ opcode 83h',
  '          ทำงานเหมือน 81h (imm16) ทำให้การค้นหานี้เสีย (เช่นเดียวกับ fn_find ที่ 0C6Ah)')
P(0x0633, 'fn_disp1: (ALT+F1 / INT 10h AL=80h) เลือกการแสดงผลแบบ 1 ระดับ — ส่งรหัสทุกตัวให้ BIOS ทีละช่องโดยไม่จัดระดับ')
P(0x063A, 'fn_disp3: (ALT+F3 / INT 10h AL=82h) เลือกการแสดงผลแบบ 3 ระดับ — สระบน/วรรณยุกต์พิมพ์ที่แถวเหนือ สระล่างที่แถวใต้')
P(0x0641,
  'fn_prn1: (ALT+F5 / INT 10h AL=84h) เลือกเครื่องพิมพ์แบบ 1 ระดับ แล้วสั่งระยะบรรทัดเริ่มต้นตามชนิดเครื่องพิมพ์')
E(0x0646, 'prn_type')
E(0x064F, "2 = LQ1500 -> ESC '1'")
E(0x0654, "0 = FX100  -> ESC '2'")
E(0x0659, "1 = CITOH  -> ESC 'A'")
P(0x065E,
  'fn_prn3: (ALT+F6 / INT 10h AL=85h) เลือกเครื่องพิมพ์แบบ 3 ระดับ (หนึ่งบรรทัดข้อความ = 3 แถวพิมพ์ซ้อนกัน)',
  '         แล้วสั่งระยะบรรทัดแบบถี่ๆ ตามชนิดเครื่องพิมพ์')
E(0x0663, 'prn_type')
E(0x066C, "2 = LQ1500 -> ESC '3' 14h")
E(0x0671, "0 = FX100  -> ESC '3' 17h")
E(0x0676, "1 = CITOH  -> ESC 'T' '1' '6'")
P(0x067B,
  'fn_lines: (ALT+F8) สลับ [dlf]',
  '          0  = LF เดี่ยว (12 บรรทัด/จอ) ; FFh = LF คู่ (8 บรรทัด/จอ — เว้นแถวว่างให้สระล่างของบรรทัดหนึ่ง',
  '          ไม่ทับกับสระบนของบรรทัดถัดไป)')
P(0x0690,
  'fn_mono: (ALT+F7) สลับ [mono] แล้วตั้งรูปเคอร์เซอร์ (INT 10h AH=01h) เฉพาะเมื่ออยู่ในโหมดอังกฤษ',
  '         [mono]=FFh -> บรรทัดสแกน 9-10 (จอโมโน 14 เส้น) ; [mono]=0 -> บรรทัดสแกน 5-6 (จอสี 8 เส้น)')
P(0x06C3, "fn_prn_norm: (ALT+F9) เลือกตัวอักษรขนาดปกติ — FX100/LQ1500: DC2 ; CITOH: ESC 'N'")
E(0x06C3, 'prn_type')
E(0x06CC, '2 = LQ1500 -> DC2')
E(0x06D1, '0 = FX100  -> DC2')
E(0x06D6, "1 = CITOH  -> ESC 'N'")
P(0x06DB, "fn_prn_cond: (ALT+F10) เลือกตัวอักษรหนาแน่น (condensed) — FX100/LQ1500: DC4 ; CITOH: ESC 'Q'")
E(0x06DB, 'prn_type')
E(0x06E4, '2 = LQ1500 -> DC4')
E(0x06E9, '0 = FX100  -> DC4')
E(0x06EE, "1 = CITOH  -> ESC 'Q'")
P(0x06F3,
  'fn_english: (ALT+F2 / INT 10h AL=81h) เลือกโหมดแป้นพิมพ์ภาษาอังกฤษ ([kbd_mode]=0) และตั้งรูปเคอร์เซอร์ตาม [mono]')
E(0x06F8, 'เคอร์เซอร์ 9-10 (โมโน)')
E(0x06FD, '5-6 เมื่อ [mono]=0 (จอสี)')
P(0x070C,
  'fn_thai: (ALT+F4 / INT 10h AL=83h) เลือกโหมดแป้นพิมพ์ภาษาไทย ([kbd_mode]=FFh)',
  '         รูปเคอร์เซอร์ = บล็อกเต็มช่อง (CX=000Ch : บรรทัดสแกน 0-12)')
P(0x071B, 'key_none: ค่าเริ่มต้นเมื่อไม่พบคีย์ในตาราง — ล้าง CF แล้วกลับ (คีย์ธรรมดา)')
P(0x071D, "pr_esc1: ส่ง ESC '1' ให้เครื่องพิมพ์ (LQ1500: ระยะบรรทัดแบบ 1 ระดับ)")
P(0x0728, "pr_esc2: ส่ง ESC '2' ให้เครื่องพิมพ์ (FX100: 1 ระดับ)")
P(0x0733, "pr_escA: ส่ง ESC 'A' ให้เครื่องพิมพ์ (CITOH: 1 ระดับ)")
P(0x073E, "pr_esc3_14: ส่ง ESC '3' 14h (LQ1500: 3 ระดับ)")
P(0x074E, "pr_esc3_17: ส่ง ESC '3' 17h (FX100: 3 ระดับ)")
P(0x075E, "pr_escT16: ส่ง ESC 'T' '1' '6' (CITOH: 3 ระดับ)")
P(0x0773, 'pr_dc2: ส่ง DC2 (12h)')
P(0x0779, 'pr_dc2b: เหมือน pr_dc2')
P(0x077D, "pr_escN: ส่ง ESC 'N'")
P(0x0788, 'pr_dc4: ส่ง DC4 (14h)')
P(0x078E, 'pr_dc4b: เหมือน pr_dc4')
P(0x0792, "pr_escQ: ส่ง ESC 'Q'")
P(0x079D, 'beep: ส่งเสียงบี๊ป (BEL ผ่าน INT 10h ตัวเดิม — ไม่ผ่าน hook ของตัวเอง)')
P(0x07A5, 'call_old10: เรียก INT 10h ตัวเดิมด้วย AX ปัจจุบัน (ใช้ตั้งรูปเคอร์เซอร์ AH=01h)')
P(0x07AE,
  'thai_space: โหมดไทย — เว้นวรรคติดกันครั้งที่ 3 ให้รหัส A0h แล้วเริ่มนับใหม่ ; โหมดอังกฤษ : คืน 20h ตามปกติ',
  '            (A0h ทำหน้าที่เป็น "เว้นวรรคไทย" — ตอนพิมพ์ hook17 จะเปลี่ยนเป็น 20h)')
P(0x07C9,
  '============================== hook INT 10h ===============================',
  'hook10: ดักเฉพาะ AH=09h (เขียนตัวอักษร+สี) และ AH=0Eh (teletype) ฟังก์ชันอื่นส่งต่อ BIOS ทันที')
P(0x07E0, 'hook10_jmp: ส่งต่อไป INT 10h ตัวเดิม (เวกเตอร์เดิมอยู่ที่ old10_vec = operand ของ jmp นี้)')
P(0x07E5,
  'hook10_work: AL = 80h..85h เป็นรหัสคำสั่ง (ดูรายการ COMMAND ในข้อความเปิดโปรแกรม) :',
  '    80h แสดงผล 1 ระดับ | 81h โหมดอังกฤษ | 82h แสดงผล 3 ระดับ | 83h โหมดไทย',
  '    84h พิมพ์ 1 ระดับ   | 85h พิมพ์ 3 ระดับ',
  '    (รายการ 134-137 "เลือกความกว้าง 80/132/160/256 คอลัมน์" มีข้อความอยู่ใน cmdlist แต่ไม่มีโค้ดรองรับ)',
  '    นอกจากนี้: [disp3]=FFh -> putc3 (จัดระดับ 3 ระดับ) ; ไม่งั้นส่งตรงให้ BIOS (bios10)')
P(0x0820, 'bios10: เรียก INT 10h ตัวเดิมด้วย AH/AL ปัจจุบัน (CX=1 สำหรับ AH=09h) — ค่ารีจิสเตอร์เดิมถูกรักษาไว้')
P(0x082E,
  'putc3: แสดงตัวอักษร 1 ตัวแบบ 3 ระดับ (ทำงานเมื่อ [disp3]=FFh)',
  '  แนวคิด: หนึ่งบรรทัดข้อความกินหลายแถวของจอ — รหัส D9h..E4h (สระบน วรรณยุกต์ ์) พิมพ์ที่แถวถัดขึ้นไป,',
  '          D7h/D8h (ุ ู) พิมพ์ที่แถวถัดลงไป, นอกนั้นพิมพ์ที่แถวปัจจุบัน',
  '  ทุกตัวอักษรถูกเก็บลง lbuf ตามลำดับที่พิมพ์ (นำไปใช้ในฟังก์ชัน INT 69h AH=0Bh)')
E(0x082E, 'CR ?')
E(0x0832, 'Backspace ?')
E(0x0836, 'รหัสควบคุมอื่น -> ส่งตรงให้ BIOS')
E(0x0838, 'คอลัมน์ >= 80 (50h hard-code) -> ขึ้นบรรทัดใหม่ก่อน')
E(0x0842, 'เก็บลง lbuf ก่อนแยกประเภท')
E(0x0845, 'เว้นวรรค -> space_skip')
E(0x0849, 'สระบน/วรรณยุกต์ -> put_upper')
E(0x084D, 'ุ / ู -> put_lower')
P(0x0868, 'putc_ctrl: รหัสควบคุมอื่น (ยกเว้น CR, BS) ส่งตรงให้ BIOS')
P(0x086C, 'do_cr: CR — ล้างตัวนับสระบนและตัวนับเว้นวรรค แล้วขึ้นบรรทัดใหม่')
P(0x0876,
  'newline: พิมพ์ CR, LF (เพิ่มอีก LF เมื่อ [dlf]≠0 = โหมด 8 บรรทัด) แล้วล้างเลขคอลัมน์และบัฟเฟอร์บรรทัด')
P(0x089F,
  'space_skip: เว้นวรรคหลังสระบน — ถ้าพิมพ์เว้นวรรคติดกันครบ 3 ครั้ง จะพิมพ์เว้นวรรคเพิ่มอีกเท่ากับจำนวนสระบนที่',
  '            ค้างอยู่ ([upr]) ทีละช่อง ถึงจะล้างตัวนับ ; ปิดได้ด้วย [noskip]=FFh (ซึ่งถูกสลับทุกครั้งที่กด Backspace)',
  '            — เป็นกฎเดียวกับ p_space ของเครื่องพิมพ์ ที่มาของกฎนี้ไม่ปรากฏในโค้ด')
P(0x08E3, 'lbuf_put: เก็บ AL ลงบัฟเฟอร์บรรทัด lbuf ที่ตำแหน่ง [blen] แล้วเพิ่ม [blen]')
P(0x08FA, 'putc_norm: ตัวอักษรระดับกลาง — เพิ่มเลขคอลัมน์ ล้างสระบนที่ค้างใน [upc] พิมพ์ และจำตำแหน่งเคอร์เซอร์')
E(0x0906,
  'หมายเหตุ: ไม่มีการเลื่อนเคอร์เซอร์เอง — ผู้เรียกที่ใช้ AH=09h จะได้เคอร์เซอร์อยู่ที่เดิม (DOS ใช้ AH=0Eh)',
  '         ค่าที่เก็บใน cur_row/cur_col ไม่มีโค้ดอ่านกลับ')
P(0x0914, 'put_lower: ุ / ู (D7h,D8h) — ลง 1 แถว ถอยซ้าย 1 ช่อง พิมพ์ แล้วกลับขึ้นมาที่ตำแหน่งเดิม')
P(0x092A, 'cur_down: เลื่อนเคอร์เซอร์ลง 1 แถว (พิมพ์ LF ผ่าน BIOS)')
P(0x0936, 'cur_up: เลื่อนเคอร์เซอร์ขึ้น 1 แถว (อ่านตำแหน่ง AH=03h แล้วตั้ง AH=02h)')
P(0x0947, 'cur_left: ถอยเคอร์เซอร์ซ้าย 1 ช่อง (พิมพ์ BS ผ่าน BIOS)')
P(0x0956, 'cur_right: เลื่อนเคอร์เซอร์ขวา 1 ช่อง — ไม่มีโค้ดเรียก (dead code)')
P(0x0967,
  'merge: รวมสระบนกับวรรณยุกต์ที่ซ้อนกันให้เป็นตัวอักษรประกอบ (ligature) — [upc] เก็บสระบน/วรรณยุกต์',
  '       ตัวล่าสุดของคอลัมน์นี้ไว้',
  '  กติกา: D9h..DEh = สระบน (ประกอบกับวรรณยุกต์ได้) ; DFh ขึ้นไป = ชั้นวรรณยุกต์/เครื่องหมาย (ไม่ประกอบ)',
  '         ไม่ว่าพิมพ์ "สระบนแล้ววรรณยุกต์" หรือ "วรรณยุกต์แล้วสระบน" ก็ได้ผลเหมือนกัน:',
  '         AL = วรรณยุกต์ + สเกลของสระบน -> รหัสลิเกเจอร์ E6h..FEh ; [upc] คงเป็นสระบนตัวนั้นไว้')
E(0x096E, 'A: จำ AL ไว้เป็นตัวค้าง แล้วกลับ')
E(0x0972, 'ตัวใหม่ >= E0h = วรรณยุกต์')
E(0x0980, 'ตัวค้างเป็นวรรณยุกต์เช่นกัน -> เก็บตัวใหม่แทน')
E(0x0987, 'ตัวค้างเป็นสระบน, ตัวใหม่เป็นวรรณยุกต์')
E(0x098A, 'ตัวค้างเป็นวรรณยุกต์, ตัวใหม่เป็นสระบน')
E(0x098E, 'สลับ: [upc]=สระบนตัวใหม่, AL=วรรณยุกต์ตัวเก่า')
E(0x0992, 'สเกลตามสระบน: [DEh] +06h  ิ +0Eh  ั +0Ah  ี +13h  ึ +17h  ื +1Bh')
E(0x0920, 'เทียบแล้วกระโดดไปคำสั่งถัดไป — ไม่มีผล (je +0)')
E(0x0923, 'ไม่มีผล (je +0)')
P(0x09D0, 'put_upper: สระบน/วรรณยุกต์ — ขึ้น 1 แถว ถอยซ้าย 1 ช่อง พิมพ์ แล้วลงกลับตำแหน่งเดิม')
E(0x09DF, 'เทียบแล้วกระโดดไปคำสั่งถัดไป — ไม่มีผล (je +0)')
E(0x09E2, 'ไม่มีผล (je +0)')
P(0x09E9,
  'backspace: สลับ [noskip] ทุกครั้งที่กด แล้วลบตัวอักษรล่าสุดของ lbuf:',
  '           (ถึง routine นี้ได้เฉพาะจาก putc3 เมื่อโปรแกรมพิมพ์ BS เอง — ระหว่าง AH=0Ah อ่านบรรทัด BS',
  '           ไม่ผ่านทางนี้ จึงถูกเก็บเป็นไบต์ 08 ใน lbuf แทนการลบ — ดูข้อสังเกต 10)',
  '           ตัวปกติ -> BS ปกติ ; ุ/ู -> ลบที่แถวล่าง ; สระบน -> ลบที่แถวบน (คืนสระบนตัวก่อนหน้าถ้ามีซ้อนกัน)',
  '           (บัฟเฟอร์ว่าง [blen]=0 -> ไม่ทำอะไร)')
P(0x0A29, 'bs_lower: ลบ ุ/ู ที่แถวล่าง')
P(0x0A3E, 'bs_upper: ลบสระบนที่แถวบน (ถ้าตัวก่อนหน้าเป็นสระบนด้วย พิมพ์ตัวนั้นคืน ไม่งั้นพิมพ์เว้นวรรค)')
P(0x0A68,
  '============================== hook INT 17h ===============================',
  'hook17: ดักเฉพาะ AH=00h (พิมพ์ตัวอักษรใน AL)')
P(0x0A7F, 'hook17_jmp: ส่งต่อไป INT 17h ตัวเดิม (เวกเตอร์เดิมอยู่ที่ old17_vec = operand ของ jmp นี้)')
P(0x0A84,
  'hook17_work:',
  '    A0h (เว้นวรรคไทย)  -> พิมพ์เป็น 20h ; [prn3]=0 (โหมดพิมพ์ 1 ระดับ) -> ส่งตรงให้ BIOS',
  '    [prn3]=FFh (โหมดพิมพ์ 3 ระดับ) -> แยกเก็บรหัสลงบัฟเฟอร์ระดับบน/กลาง/ล่าง (prn_putc) โดยยังไม่พิมพ์',
  '    แล้วเรียก BIOS ด้วย AH=02h (อ่านสถานะเครื่องพิมพ์) เพื่อให้ผู้เรียกได้รับสถานะเหมือนพิมพ์จริง')
P(0x0A92,
  'prn_putc: แจกจ่ายรหัสลงบัฟเฟอร์ 3 ระดับสำหรับพิมพ์ (ตำแหน่ง [ppos] เริ่ม 0 ที่ขอบซ้าย)',
  '    ตัวอักษรระดับกลาง -> lvl_m[ppos], ppos+1 ; สระบน (>=D9h ผ่าน merge ก่อน) -> lvl_u[ppos-1]',
  '    ุ/ู -> lvl_l[ppos-1] ; CR -> พิมพ์ทั้ง 3 แถวแล้วล้างบัฟเฟอร์ ; เต็มบรรทัด -> พิมพ์ก่อนแล้วมาทำตัวนี้ใหม่')
E(0x0A96, 'LF ถูกกลืน (ขึ้นบรรทัดทำที่ CR)')
E(0x0A9A, 'เต็มบรรทัด ([ppos] >= [pwid]=131)')
E(0x0AA4, 'เว้นวรรค -> p_space')
E(0x0AA8, 'ตัวอักษรอื่นรีเซ็ตตัวนับเว้นวรรคของเครื่องพิมพ์')
E(0x0AAD, 'D7h,D8h = ุ ู')
E(0x0AB1, 'ระดับกลาง')
E(0x0AC4, 'ถอย 1 ตำแหน่งให้ตรงกับพยัญชนะตัวหน้า')
E(0x0AC8, 'ระดับล่าง')
E(0x0AD9, 'ถอย 1 ตำแหน่ง')
E(0x0ADD, 'ระดับบน')
P(0x0AEB, 'bios_print: พิมพ์ AL ทาง LPT1 (DX=0) ผ่าน INT 17h ตัวเดิม (AH=00h) — รีจิสเตอร์ทั้งหมดถูกรักษาไว้')
P(0x0B03, 'is_pspace: รายการ "เว้นวรรค" ของ prn_putc')
P(0x0B0B,
  'p_cr: CR — ถ้าบรรทัดไม่ว่าง พิมพ์บัฟเฟอร์ทั้ง 3 ระดับ (บน กลาง ล่าง) แถวละ [ppos] ตัวอักษร + CR LF (p_type)',
  '      แล้วเติมบัฟเฟอร์ทั้งหมด 3FFh ไบต์ (019Ah..0598h) ด้วยเว้นวรรค และคืน [ppos]=0')
E(0x0B15, 'บัฟเฟอร์ว่าง -> ข้ามไปล้าง')
E(0x0B1C, 'แถวบน')
E(0x0B25, 'แถวกลาง')
E(0x0B2E, 'แถวล่าง')
P(0x0B37, 'p_clear: เติมบัฟเฟอร์ 3FFh ไบต์ด้วย 20h แล้วคืน [ppos]=0')
P(0x0B51, 'flush: พิมพ์บัฟเฟอร์ที่ค้างอยู่ (เรียกเมื่อเต็มบรรทัด) โดยรักษาค่า AL')
P(0x0B57, 'p_type: พิมพ์ [ppos] ไบต์จากบัฟเฟอร์ [pbuf] ตามด้วย CR LF')
P(0x0B7C, 'pbuf_put: เก็บ AL ที่ [pbuf]+[ppos] แล้วเพิ่ม [ppos]')
P(0x0B94,
  'p_space: เว้นวรรคเมื่อมีสระบน/ล่างค้างในคำ ([pmark]>0) — เว้นวรรคครบ 3 ครั้งจะพิมพ์เว้นวรรคเพิ่มเท่ากับ',
  '         จำนวนสระที่ค้างอยู่ (กฎเดียวกับ space_skip ของจอภาพ) ; ไม่มีสระค้าง -> เก็บเว้นวรรคปกติ')
E(0x0BBB, 'นับครบตามจำนวนสระ -> จบ')
E(0x0BC1, 'เต็มบรรทัด -> พิมพ์ก่อน (คง AL ไว้)')
P(0x0BB0, 'p_sp_loop')
P(0x0BD0, 'p_sp_end: รีเซ็ตตัวนับเว้นวรรค')
P(0x0C0C,
  '============================== hook INT 69h ===============================',
  'hook69: API ของ TSX — เก็บ DS ของผู้เรียกไว้ที่ sv_ds, เซฟรีจิสเตอร์ทั้งหมด (save_regs),',
  '        แล้วบวกค่า AH ด้วย 1 แล้วค้นหาใน fntab: AH=00h -> f01, AH=01h -> f02, ..., AH=0Ah -> f0B',
  '        (หมายเลข AH จึงตรงกับหมายเลขฟังก์ชันตามตารางในบทความ ; ค่า AH ตั้งแต่ 0Bh ขึ้นไป -> fn_none ไม่ทำอะไร)',
  '        routine แต่ละตัวเรียก rest_regs ก่อนแก้รีจิสเตอร์ และกลับด้วย pop ds + iret',
  '        (rest_regs ไม่คืนค่า AX — AX เป็นช่องทางส่งค่ากลับของฟังก์ชัน)',
  '        ที่อยู่ 0C0Ch นี้คือ "ลายเซ็น" ที่ใช้ตรวจว่า TSR ตัวนี้อยู่ (เวกเตอร์ INT 69h = CS:0C0Ch)')
P(0x0C2D, 'save_regs: เก็บ ES,BP,SI,DI,DX,CX,BX,AX ลง sv_*')
P(0x0C4D, 'rest_regs: คืนค่าจาก sv_* (ยกเว้น DS — คืนตอน pop ds ก่อน iret)')
P(0x0C6A,
  'fn_find: หา AL ในตาราง [SI] (รายการละ 3 ไบต์) ; ไม่พบ -> BX = ที่อยู่หลังรายการปิดท้าย = fn_none',
  '         (ใช้ opcode 83h /r ของ 80186 เช่นเดียวกับ tbl_find)')
P(0x0C7C, 'f01: (INT 69h AH=00h) อ่านโหมดแป้นพิมพ์ -> AL = 00h อังกฤษ / FFh ไทย')
P(0x0C83, 'f02: (INT 69h AH=01h) อ่านโหมดการแสดงผล -> AL = [disp3] (00h 1 ระดับ / FFh 3 ระดับ) ; AH = [dlf] (00h 12 บรรทัด / FFh 8 บรรทัด)')
P(0x0C8E, 'f03: (INT 69h AH=02h) อ่านโหมดเครื่องพิมพ์ -> AL = [prn3] (00h 1 ระดับ / FFh 3 ระดับ)')
P(0x0C95,
  'f04: (INT 69h AH=03h) ตั้งโหมดแป้นพิมพ์ : DL=00h -> อังกฤษ , DL=FFh หรือ 01h -> ไทย , DL=02h..7Fh -> ไม่เปลี่ยน',
  '     พร้อมตั้งรูปเคอร์เซอร์ (ดู fn_english / fn_thai)')
P(0x0CB0, 'f04_english')
E(0x0CB7, 'บรรทัดสแกน 9-10 หรือ 5-6 ตาม [mono]')
P(0x0CC8, 'f05: (INT 69h AH=04h) ตั้งโหมดการแสดงผล : DL=00h -> 1 ระดับ , DL=FFh หรือ 01h -> 3 ระดับ , DL=02h..7Fh -> ไม่เปลี่ยน')
P(0x0CE1, 'f06: (INT 69h AH=05h) จำนวนบรรทัด : DL=00h -> LF เดี่ยว (12 บรรทัด) , DL=FFh หรือ 01h -> LF คู่ (8 บรรทัด) , DL=02h..7Fh -> ไม่เปลี่ยน')
P(0x0CFA,
  'f07: (INT 69h AH=06h) ตั้งโหมดเครื่องพิมพ์ แล้วส่งรหัสระยะบรรทัดให้เครื่องพิมพ์ :',
  '     DL=FFh หรือ 01h -> [prn3]=FFh (3 ระดับ) + prn3_init ; DL=02h..7Fh -> ไม่เปลี่ยน ; DL=00h -> prn1_init',
  '     ข้อสังเกต: ที่ prn1_init มีการเขียน [prn3]=FFh เช่นกัน (น่าจะตั้งใจเป็น 00h) ผลคือ DL=00h สั่งระยะบรรทัด',
  '     แบบ 1 ระดับ แต่ TSX ยังค่อยข้อมูลแบบ 3 ระดับอยู่ — การสั่ง "พิมพ์ 1 ระดับ" ที่ได้ผลจริงคือ ALT+F5 / INT 10h AL=84h')
E(0x0D03, '01h..7Fh -> ออกโดยไม่เปลี่ยน')
P(0x0D07, 'prn3_init: รหัสระยะบรรทัดสำหรับพิมพ์ 3 ระดับ ตามชนิดเครื่องพิมพ์')
E(0x0D0C, 'prn_type')
E(0x0D15, "2 = LQ1500 -> ESC '3' 14h")
E(0x0D19, "0 = FX100  -> ESC '3' 17h")
E(0x0D1D, "1 = CITOH  -> ESC 'T' '1' '6'")
P(0x0D21,
  'prn1_init: รหัสระยะบรรทัดสำหรับพิมพ์ 1 ระดับ ตามชนิดเครื่องพิมพ์',
  '           (บรรทัดแรกเขียน [prn3]=FFh — ข้อผิดพลาดที่กล่าวถึงใน f07)')
E(0x0D26, 'prn_type')
E(0x0D2F, "2 = LQ1500 -> ESC '1'")
E(0x0D33, "0 = FX100  -> ESC '2'")
E(0x0D37, "1 = CITOH  -> ESC 'A'")
P(0x0D3B,
  'f08: (INT 69h AH=07h) เลือกชนิดเครื่องพิมพ์ : DL = 0 FX100 / 1 CITOH / 2 LQ1500 (ค่าอื่น -> ไม่เปลี่ยน)',
  '     แล้วส่งรหัสระยะบรรทัดตามโหมดพิมพ์ปัจจุบัน (prn1_init หรือ prn3_init) ตามด้วยรหัสเริ่มต้นที่ f08_type_init')
E(0x0D42, '> 2 -> ออก')
E(0x0D47, 'ตามโหมดพิมพ์ปัจจุบัน')
P(0x0D56, "f08_type_init: ส่ง DC2 (FX100/LQ1500) หรือ ESC 'N' (CITOH)")
E(0x0D56, 'prn_type')
P(0x0D6B,
  'f09: (INT 69h AH=08h) อ่านคีย์ 1 ตัว (ไม่แสดงผล) -> AL = รหัส KU, AH = scan code เดิม ;',
  '     สระบน+วรรณยุกต์ที่ซ้อนกันถูกรวมเป็นลิเกเจอร์ (>=E6h)',
  '     ([upc] เก็บสระบนตัวค้างไว้ให้ครั้งถัดไป)')
E(0x0D70, 'ไม่ใช่สระบน -> ล้างตัวค้าง')
E(0x0D7B, 'ตัวค้างเป็นลิเกเจอร์อยู่แล้ว -> ไม่รวมซ้ำ')
P(0x0D8C,
  'f0A: (INT 69h AH=09h) อ่านคีย์ 1 ตัว แล้วแสดงผลที่ตำแหน่งเคอร์เซอร์ (BIOS หน้า 0 สี 4) -> AL = รหัส KU',
  '     ค่าที่อ่านได้ถูกเก็บที่ sv_ax เพื่อคืนให้ผู้เรียก')
P(0x0DA1,
  'f0B: (INT 69h AH=0Ah) อ่านข้อความ 1 บรรทัดจนกว่า ENTER (บังคับแสดงผลแบบ 3 ระดับระหว่างอ่าน) ; DS:DX = บัฟเฟอร์ปลายทาง',
  '     ผลลัพธ์ : ไบต์แรก = จำนวนตัวอักษร ([col]+[upr]) ตามด้วยรหัส KU จาก lbuf (ตัวสุดท้ายคือ CR)')
P(0x0DF7, 'fn_none: ค่าเริ่มต้นเมื่อหมายเลขฟังก์ชันไม่มีในตาราง — ไม่ทำอะไร')
P(0x14DA,
  '================== ส่วนติดตั้ง (ทำงานครั้งเดียวจาก PSP:0100h) ==================',
  'install: แสดงแบนเนอร์ + รายการคำสั่ง (INT 21h AH=09h), รอกดคีย์ (AH=07h),',
  '         แล้วแสดงรายการเครื่องพิมพ์โดยไฮไลต์ชนิดที่ตั้งอยู่')
E(0x14E5, 'รอกดคีย์ (ไม่แสดงผล)')
E(0x14F5, 'BX = 0020h: BH=หน้า 0, BL=สี 20h')
P(0x151A,
  'menu_item: พิมพ์ข้อความที่ DS:SI ทีละตัวอักษรด้วย INT 10h AH=09h (CX=1) จนถึง \'$\'',
  '           DL = ชนิดเครื่องพิมพ์ของรายการนี้ — ตรงกับ [prn_type] ใช้สี BL=70h (กลับสี) , ไม่งั้นใช้ BL เดิม (20h)',
  '           พิมพ์แล้วเลื่อนเคอร์เซอร์เองด้วย AH=03h (อ่านตำแหน่ง) + AH=02h (+1 คอลัมน์) เพราะ AH=09h ไม่เลื่อน')
P(0x1544,
  'setup: เก็บเวกเตอร์เดิมของ INT 16h (0000:0058h), INT 10h (0040h), INT 17h (005Ch) ไว้ใน operand ของ',
  '       คำสั่ง jmp ส่งต่อ แล้วชี้เวกเตอร์ทั้งสามมาที่ hook ของ TSR นี้,',
  '       ตั้งเวกเตอร์ INT 69h (01A4h) = CS:0C0Ch และสั่งอยู่ถาวรด้วย INT 27h (DX=014DAh = สิ้นสุดส่วนถาวร)')


# --------------------------------------------------------------------------
# header
# --------------------------------------------------------------------------
def header():
    C('')
    C('#' * 78)
    C(' THAI.COM  —  TSX (Thai System Extensions)  v3.51')
    C(' ส่วนที่อยู่ถาวรในหน่วยความจำ (TSR) ของระบบจัดการภาษาไทย "รหัสเกษตร" (KU code)')
    C(' สำหรับ IBM PC / XT / PCjr  —  คณะวิศวกรรมศาสตร์ มหาวิทยาลัยเกษตรศาสตร์  Copyright 1984')
    C(' บทความประกอบ: ไมโครคอมพิวเตอร์ ฉบับ 21/2529 หน้า 93-97 (อธิบาย TSX รุ่น 3.52)')
    C('-' * 78)
    C(' ต้นฉบับ : THAI.COM  5,298 ไบต์   md5 d4db5c5ddd4bfc4bdeed613ba632bcc9')
    C(' วิธีได้มา: ถอดด้วย capstone (โหมด 16 บิต) แล้วใส่ชื่อ label และคำอธิบายจากการไล่โค้ดทีละ routine')
    C(' รูปแบบ  : syntax ของ NASM (org 100h, cpu 186) — ทุกไบต์ของไฟล์ถูกแสดงครบพร้อมที่อยู่และค่าฐานสิบหก')
    C('           แอสเซมเบิลกลับด้วย NASM 3.02 (-f bin) ได้ไบนารีตรงกับ THAI.COM ทุกไบต์ (5,298 ไบต์)')
    C('           หมายเหตุ: คำสั่ง reg-reg 10 จุดที่ต้นฉบับใช้รูป RM ถูกคงไว้เป็น db (NASM emit รูป MR)')
    C('')
    C(' ทำอะไร  : ดัก 3 interrupt ของ BIOS และเปิด API ผ่าน INT 69h')
    C('   INT 16h (AH=00h)     อ่านคีย์: ALT+F1..F10 = คีย์ลัด ; โหมดไทยแปล ASCII -> รหัส KU')
    C('   INT 10h (AH=09h,0Eh) แสดงผล 3 ระดับ (สระบน/วรรณยุกต์พิมพ์ที่แถวบน สระล่างที่แถวล่าง)')
    C('                         และรับคำสั่งด้วยรหัส 80h..85h')
    C('   INT 17h (AH=00h)     พิมพ์ 3 ระดับ (หนึ่งบรรทัดข้อความ = 3 แถวพิมพ์ซ้อนกัน)')
    C('   INT 69h              API (AH = หมายเลขฟังก์ชัน 00h..0Ah — ตัวจัดการบวก 1 แล้วค้นตาราง fntab)')
    C('')
    C(' ผังหน่วยความจำ (ที่อยู่เมื่อโหลดเป็น .COM ที่ PSP:0100h):')
    C('   0100h  จุดเข้า (jmp install)                    05C5h  hook INT 16h + คีย์ลัด + รหัสสั่งเครื่องพิมพ์')
    C('   0104h  ตัวแปรสถานะ (ถึง 0119h)                   07C9h  hook INT 10h + แสดงผล 3 ระดับ')
    C('   011Ah  ktbl  ASCII -> KU (80h ไบต์)               0A68h  hook INT 17h + พิมพ์ 3 ระดับ')
    C('   019Ah  lvl_u/lvl_m/lvl_l บัฟเฟอร์พิมพ์ (×100h)     0BD6h  พื้นที่เซฟรีจิสเตอร์ + fntab')
    C('   049Ah  lbuf  บัฟเฟอร์บรรทัดจอภาพ (FFh ไบต์)       0C0Ch  hook INT 69h + ฟังก์ชัน')
    C('   0599h  keytab  ALT+Fn (รายการละ 4 ไบต์)            0DF8h  banner + cmdlist + ข้อความเมนู')
    C('                                                          14DAh  install (ถูกทิ้งหลัง INT 27h)')
    C('')
    C('  INT 69h  (AH = หมายเลขฟังก์ชัน, DL = พารามิเตอร์ — ตัวจัดการบวก AH ด้วย 1 แล้วค้นตาราง fntab):')
    C('    AH   routine  ความหมาย')
    C('    00h  f01      อ่านโหมดแป้นพิมพ์    -> AL = 00h อังกฤษ / FFh ไทย')
    C('    01h  f02      อ่านโหมดแสดงผล      -> AL = 00h 1 ระดับ / FFh 3 ระดับ ; AH = 00h LF เดี่ยว / FFh LF คู่')
    C('    02h  f03      อ่านโหมดเครื่องพิมพ์  -> AL = 00h 1 ระดับ / FFh 3 ระดับ')
    C('    03h  f04      ตั้งโหมดแป้นพิมพ์    DL = 00h อังกฤษ / FFh หรือ 01h ไทย (พร้อมตั้งรูปเคอร์เซอร์)')
    C('    04h  f05      ตั้งโหมดแสดงผล      DL = 00h 1 ระดับ / FFh หรือ 01h 3 ระดับ')
    C('    05h  f06      จำนวนบรรทัด         DL = 00h LF เดี่ยว / FFh หรือ 01h LF คู่ (สลับจอ 8&12 บรรทัด)')
    C('    06h  f07      ตั้งโหมดเครื่องพิมพ์  DL = FFh หรือ 01h -> 3 ระดับ ; DL = 00h -> ส่งรหัสระยะบรรทัด 1 ระดับ')
    C('                                (แต่โหมดยังเป็น 3 ระดับเพราะค่าที่เขียนที่ prn1_init เป็น FFh)')
    C('    07h  f08      เลือกชนิดเครื่องพิมพ์ DL = 0 FX100 / 1 CITOH / 2 LQ1500')
    C('    08h  f09      อ่านคีย์ (ไม่แสดงผล)  -> AL = รหัส KU, AH = scan code')
    C('    09h  f0A      อ่านคีย์ + แสดงผล     -> AL = รหัส KU')
    C('    0Ah  f0B      อ่านข้อความ 1 บรรทัด  DS:DX = บัฟเฟอร์ ([0] = จำนวน, ตามด้วยรหัส KU .. CR)')
    C('    (03h..07h : ค่า DL นอกเหนือจากที่ระบุ = ไม่เปลี่ยนค่าเดิม) ; AH ตั้งแต่ 0Bh ขึ้นไป = ไม่ทำอะไร')
    C('')
    C(' INT 10h (AH=09h/0Eh) เมื่อ AL = รหัสคำสั่ง:  80h แสดงผล 1 ระดับ | 81h โหมดอังกฤษ | 82h แสดงผล 3 ระดับ')
    C('                                        83h โหมดไทย | 84h พิมพ์ 1 ระดับ | 85h พิมพ์ 3 ระดับ')
    C(' ALT+F1..F10 (ลำดับเดียวกัน): 1 ระดับจอ, อังกฤษ, 3 ระดับจอ, ไทย, 1 ระดับพิมพ์, 3 ระดับพิมพ์,')
    C('                             สลับจอโมโน/สี, สลับ 8/12 บรรทัด, ตัวอักษรปกติ, ตัวอักษรหนาแน่น')
    C('')
    C(' รหัสภาษาไทย (KU code) ที่ใช้ภายในและแสดงผล — เรียงตามลำดับพจนานุกรม:')
    C('        0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F')
    for hi in range(0xA0, 0xE6, 0x10):
        row = '   %Xh  ' % (hi >> 4)
        for lo in range(16):
            v = hi + lo
            if v in KU2TH:
                row += ' %3s' % (ku(v) or '?')
            else:
                row += '    '
        C(row)
    C('        E6h..FEh = ตัวอักษรประกอบ วรรณยุกต์ x สระบน (ดู merge)   EBh = ั้ (พิมพ์ตรงได้ด้วยปุ่ม \'&\')')
    C('   ลำดับสเกลใน merge: [DEh] +06h  ิ +0Eh  ั +0Ah  ี +13h  ึ +17h  ื +1Bh  (เช่น ่+ี = F3h, ้+ั = EBh)')
    C(' หลักฐาน: ตัวอักษร 27 ตัวยืนยันได้ตรงๆ จากข้อความไทยใน banner; ที่เหลืออนุมานจากตำแหน่งปุ่มบนแป้นพิมพ์ดีด')
    C('   ไทยแบบ Kedmanee (แถวอักษรของ ktbl ตรงกันเกือบทั้งหมด) ร่วมกับลำดับพจนานุกรม และตารางลิเกเจอร์ของ merge')
    C("   '?' = ไม่ทราบแน่ชัด: B0h (Shift+','), CDh (ไม่มีปุ่ม), D6h (Shift+O),")
    C('           DEh (ไม่มีปุ่ม) กับ DFh (Shift+H) = ็ และ ํ แต่ไม่ปรากฏว่าตัวไหนเป็นตัวไหน')
    C('   หมายเหตุ: ตาราง KU2STD.H ใน github.com/kytulendu/STUFF ให้ค่าต่างจากไฟล์นี้ (เช่น A3h: ไฟล์นี้ = ค')
    C('     แต่ตารางนั้น = ง , B9h: ไฟล์นี้ = ป แต่ตารางนั้น = ไ) — ตารางข้างต้นมาจาก THAI.COM โดยตรง')
    C('   แถวล่างของ ktbl ต่างจาก Kedmanee: x=ป c=แ v=อ b=ิ n=ื m=ท ,=ม .=ใ /=ฝ')
    C('')
    C(' ข้อสังเกตที่พบจากการถอด:')
    C('   1. ใช้ opcode 83h /r ที่ tbl_find และ fn_find — เป็นคำสั่งของ 80186 ขึ้นไป ทั้งที่แบนเนอร์เขียนว่า PC/XT/PCjr')
    C('      บน 8086/8088 แท้ opcode 83h ทำงานเหมือน 81h ทำให้การค้นตารางผิดพลาด')
    C('   2. ที่ prn1_init (0D26h) เขียน [prn3]=FFh ทั้งที่เส้นทางนี้คือ "พิมพ์ 1 ระดับ" (น่าจะตั้งใจเป็น 00h)')
    C('      ผลคือ INT 69h AH=07h DL=00h ไม่ได้เปลี่ยนเป็นพิมพ์ 1 ระดับจริง และ AH=08h จะดันโหมดเป็น 3 ระดับ')
    C('      ถ้าเดิมอยู่ในโหมด 1 ระดับ')
    C('   3. รายการ COMMAND 134-137 (เลือกความกว้าง 80/132/160/256 คอลัมน์) มีข้อความแต่ไม่มีโค้ดรองรับ')
    C('      ความกว้างถูกตั้งไว้คงที่ 132 คอลัมน์ ([pwid]=131)')
    C('   4. หมายเลขฟังก์ชัน (AH) ตรงกับตารางในบทความ (3.52) ตั้งแต่ 00h..07h เพราะตัวจัดการบวก AH ด้วย 1 ก่อนค้น')
    C('      fntab; ส่วนท้ายต่างกันหนึ่งตำแหน่ง: ไฟล์นี้ 08h อ่านคีย์, 09h อ่านคีย์+แสดงผล, 0Ah อ่านบรรทัด,')
    C('      0Bh ไม่มีฟังก์ชัน — ส่วนบทความระบุ 08h อ่านรหัสคีย์ ALT+Fn, 09h อ่านคีย์, 0Ah อ่านคีย์+แสดงผล,')
    C('      0Bh อ่านบรรทัด (น่าจะมีการเพิ่มฟังก์ชันใน 3.52)')
    C('   5. hook10 กับ AH=09h ไม่เลื่อนเคอร์เซอร์หลังพิมพ์ (ใช้ได้จริงกับ AH=0Eh ซึ่ง DOS ใช้)')
    C('   6. โค้ด/ข้อมูลที่ไม่ถูกใช้: cur_right, cur_row, cur_col, pad114 และไบต์ 90h ท้ายบัฟเฟอร์พิมพ์แต่ละอัน')
    C('      (เป็นค่าที่ปรากฏในไฟล์ ไม่มีโค้ดอ่าน)')
    C('   7. คีย์ลัด ALT+Fn ถูกกล้น (ไม่ส่งให้โปรแกรม) และมีเสียงบี๊บทุกครั้งที่กด')
    C('   8. INT 69h AH=0Ah: ค่า [disp3] เดิมที่เขียนเก็บไว้ที่ sv_ax ก่อนวนอ่านถูก f0A เขียนทับด้วย AX ของ')
    C('      คีย์ล่าสุดทุกครั้ง เมื่อจบฟังก์ชันจึงอ่าน sv_ax กลับมาได้ AL = 0Dh (CR) แล้วใส่กลับ [disp3] —')
    C('      โหมดการแสดงผลเดิมจึงหายไป (0Dh ทำให้ hook10 แสดงผลแบบ 1 ระดับ) และ AX ที่ผู้เรียกได้รับกลับ')
    C('      คือ scan code : 0Dh ของ ENTER แทนค่าเดิม')
    C('   9. บทความระบุคู่ค่าจำนวนบรรทัดว่า AH=00h -> 8 บรรทัด, FFh -> 12 บรรทัด ซึ่งกลับข้างกับตรรกะ LF ใน')
    C('      ไฟล์นี้ (dlf=FFh พิมพ์ LF เพิ่ม = เว้นแถวมากขึ้น = บรรทัดต่อจอน้อยลง) — น่าจะต่างกันเพราะคนละเวอร์ชัน')
    C('  10. การลบ (Backspace) ไม่ทำงานระหว่าง AH=0Ah อ่านบรรทัด: f0A เรียก putc3_store โดยตรง (ข้าม')
    C('      dispatch ของ putc3) BS จึงถูกเก็บเป็นไบต์ 08 ใน lbuf และนับในจำนวนตัวอักษร — ตรวจสอบด้วย')
    C('      emulator แล้ว (lbuf = B5 B2 C7 CA B8 08 0D, count=7) — routine ลบ backspace/bs_lower/bs_upper')
    C('      ทำงานเฉพาะเส้นทางแสดงผล: โปรแกรมพิมพ์ BS เองผ่าน INT 10h AH=09h/0Eh เท่านั้น (ลบลง lbuf+จอ')
    C('      แบบ 3 ระดับครบ: ลบ ุ/ู ที่แถวล่าง, ลบสระบน/ลิเกเจอร์ที่แถวบนพร้อมคืนสระที่ซ้อนอยู่ข้างใต้)')
    C('#' * 78)


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------
def main():
    header()
    raw('')
    raw('        cpu 186')
    raw('        org 100h')
    for a0, a1 in CODE_RANGES:
        for i in md.disasm(SRC[a0 - ORG:a1 - ORG], a0):
            STARTS.add(i.address)
    raw('')
    code(0x0100, 0x0104, PRE, EOL)

    # ---- variables
    C('')
    C('---- ตัวแปรสถานะของ TSR (ค่าเริ่มต้นตอนโหลด) ----')
    for a, n, sz, c in VARS:
        v = b(a) if sz == 1 else w(a)
        t = '%s  %s 0x%0*X' % (n, 'db' if sz == 1 else 'dw', 2 * sz, v)
        raw('%-28s; %04X%s' % (t, a, ('  ' + c) if c else ''))
        mark(a, a + sz, 'var')

    # ---- ktbl
    C('')
    C('---- ktbl: ตาราง XLAT แปลรหัสจากแป้นพิมพ์ ASCII -> รหัส KU  (ใช้เมื่อ [kbd_mode]=FFh โหมดไทย) ----')
    C('    ดัชนี = รหัส ASCII ของคีย์  (00h..20h คงค่าเดิม, 7Ch..FFh -> 20h)')
    C('')
    C('    คีย์      -> KU    ตัวอักษร        คีย์      -> KU    ตัวอักษร')
    ent = []
    for c in range(0x21, 0x7D):
        v = b(0x011A + c)
        if v == c:
            tgt = '(คงเดิม)'
        else:
            t = ku(v)
            if t is None and 0x20 <= v < 0x7F:
                t = "'" + (chr(v) if chr(v) != '\\' else '\\\\') + "'"
            tgt = '%02Xh %s' % (v, t or '')
        ent.append('%s -> %s' % (keyname(c), tgt))
    for i in range(0, len(ent), 2):
        C('    %-30s   %-30s' % (ent[i], ent[i + 1] if i + 1 < len(ent) else ''))
    raw('ktbl:')
    db_rows(0x011A, 0x019A, text=False)
    C('    (หลัง 0196h เป็น 20h จนครบตาราง)')

    # ---- buffers
    C('')
    C('---- บัฟเฟอร์ 3 ระดับสำหรับเครื่องพิมพ์ (แต่ละอัน 100h ไบต์) ----')
    for a, n, desc in [(0x019A, 'lvl_u', 'ระดับบน   : สระบน / วรรณยุกต์  — พิมพ์เป็นแถวแรก'),
                       (0x029A, 'lvl_m', 'ระดับกลาง : พยัญชนะ สระ ตัวเลข  — พิมพ์เป็นแถวที่สอง'),
                       (0x039A, 'lvl_l', 'ระดับล่าง  : ุ ู               — พิมพ์เป็นแถวที่สาม')]:
        assert b(a + 0xFF) == 0x90 and all(b(x) == 0x20 for x in range(a, a + 0xFF))
        raw('%s:' % n)
        raw('    times 0FFh db 0x20%s; %04X  %s' % (' ' * 36, a, desc))
        raw('    db 0x90                 ; %04X  ค่าในไฟล์ — ไม่มีโค้ดอ่าน (p_clear เขียนทับเป็น 20h)' % (a + 0xFF))
        mark(a, a + 0x100, 'buf')
    C('')
    C('---- lbuf: บัฟเฟอร์บรรทัดของจอภาพ (เก็บตัวอักษรที่พิมพ์ในบรรทัดปัจจุบันตามลำดับ) ----')
    assert all(b(x) == 0x20 for x in range(0x049A, 0x0599))
    raw('lbuf:')
    raw('    times 0FFh db 0x20%s; %04X' % (' ' * 35, 0x049A))
    mark(0x049A, 0x0599, 'buf')

    # ---- keytab
    C('')
    C('---- keytab: ALT+Fn -> routine  (หาโดย tbl_find; รายการละ dw scan code, dw routine) ----')
    keydesc = {
        0x68: ('ALT+F1', 'แสดงผล 1 ระดับ'), 0x69: ('ALT+F2', 'โหมดอังกฤษ'),
        0x6A: ('ALT+F3', 'แสดงผล 3 ระดับ'), 0x6B: ('ALT+F4', 'โหมดไทย'),
        0x6C: ('ALT+F5', 'พิมพ์ 1 ระดับ'), 0x6D: ('ALT+F6', 'พิมพ์ 3 ระดับ'),
        0x6E: ('ALT+F7', 'สลับจอโมโน/สี'), 0x6F: ('ALT+F8', 'สลับ 8/12 บรรทัด'),
        0x70: ('ALT+F9', 'ตัวอักษรปกติ'), 0x71: ('ALT+F10', 'ตัวอักษรหนาแน่น'),
        0x00: ('(จบตาราง)', 'คีย์ที่ไม่มีในรายการ -> key_none'),
    }
    raw('keytab:')
    a = 0x0599
    while True:
        k, r = w(a), w(a + 2)
        assert r in CODE_LABELS and (k >> 8) in keydesc and (k & 0xFF) == 0, (hex(a), hex(k), hex(r))
        kn, kd = keydesc[k >> 8]
        raw('    dw 0x%04X%s; %04X  %s%s' % (k, ' ' * 15, a, kn, '' if k == 0 else '  (AX: AL=00h, AH=scan code %02Xh)' % (k >> 8)))
        raw('    dw %s' % CODE_LABELS[r])
        mark(a, a + 4, 'keytab')
        a += 4
        if k == 0:
            break
    assert a == 0x05C5

    code(0x05C5, 0x0A68, PRE, EOL)
    code(0x0A68, 0x0BD6, PRE, EOL)      # hook INT 17h + printer 3-level code

    # ---- save area
    C('')
    C('---- พื้นที่เซฟรีจิสเตอร์ของผู้เรียก INT 69h ----')
    for a, n in DATA_LABELS:
        if 0x0BD6 <= a <= 0x0BE6:
            assert w(a) == 0
            raw('%-16s dw 0%s; %04X' % (n + ':', ' ' * 21, a))
            mark(a, a + 2, 'save')

    # ---- fntab
    C('')
    C('---- fntab: ตารางฟังก์ชัน INT 69h (รายการละ db หมายเลข, dw routine) ----')
    raw('fntab:')
    a = 0x0BE8
    while a < 0x0C0C:
        fn, r = b(a), w(a + 1)
        assert r in CODE_LABELS, (hex(a), hex(r))
        nm = CODE_LABELS[r]
        raw('    db 0x%02X%s; %04X' % (fn, ' ' * 49, a))
        raw('    dw %s' % nm)
        USED.add(nm)
        mark(a, a + 3, 'fntab')
        a += 3

    code(0x0C0C, 0x0DF8, PRE, EOL)

    # ---- text
    C('')
    C('---- banner: ข้อความเปิดโปรแกรม (จบด้วย \'$\' ที่ 1140h) พิมพ์ด้วย INT 21h AH=09h ที่ install ----')
    C('   ข้อความไทยเป็นรหัส KU ที่วางไว้สำหรับการแสดงผล 3 ระดับ (สระบน/สระล่างอยู่คนละแถวกับตัวอักษร):')
    C('      0E1Dh (ตัวอักษร): "โปรแกรมควบคมระบบงานภาษาไทย"  — ควบค[ุ]ม ที่ ุ หายไปอยู่ในบรรทัดถัดไป')
    C('      0E66h (สระล่าง) : ◌ุ ของคำว่า "ควบคุม"')
    C('      0FB0h (สระบน)   : ◌ิ ◌์ ◌ิ ◌ั ◌์ ของบรรทัดตัวอักษรข้างล่าง (คณะวิศว..., มหาวิทยาลัย..., ศาสตร์)')
    C('      1004h (ตัวอักษร): "คณะวศวกรรมศาสตร มหาวทยาลยเกษตรศาสตร"')
    assert b(0x1140) == 0x24 and all(b(x) != 0x24 for x in range(0x0DF8, 0x1140))
    raw('banner:')
    db_text(0x0DF8, 0x1141)

    C('')
    C('---- cmdlist: รายการคำสั่ง + ส่วนหัวของเมนูเครื่องพิมพ์ (จบด้วย \'$\' ที่ 14B7h) ----')
    assert b(0x14B7) == 0x24 and all(b(x) != 0x24 for x in range(0x1141, 0x14B7))
    raw('cmdlist:')
    db_text(0x1141, 0x14B8)

    C('')
    C('---- ข้อความเมนูเครื่องพิมพ์ (พิมพ์โดย install/menu_item) ----')
    for a0, a1, n, c in [(0x14B8, 0x14C2, 'pmenu_lq', 'ชนิด 2 = LQ1500'),
                         (0x14C2, 0x14CC, 'pmenu_citoh', 'ชนิด 1 = CITOH'),
                         (0x14CC, 0x14D6, 'pmenu_fx', 'ชนิด 0 = FX100')]:
        assert b(a1 - 1) == 0x24
        raw('%s:' % n)
        db_rows(a0, a1)
        C('    %s' % c)
    assert b(0x14D6) == 0x00 and b(0x14D7) == 0x0D and b(0x14D8) == 0x0A and b(0x14D9) == 0x24
    raw('pmenu_nul:   db 0x00             ; 14D6')
    raw('pmenu_crlf:  db 0x0D, 0x0A, 0x24 ; 14D7  CR LF \'$\'')
    mark(0x14D6, 0x14DA, 'pmenu')

    code(0x14DA, 0x15B2, PRE, EOL)

    # ---- checks
    missing = [hex(a + ORG) for a, c in enumerate(cov) if c is None]
    assert not missing, 'uncovered bytes: %s' % missing
    for a in list(PRE) + list(EOL):
        assert a in STARTS, 'comment attached to non-instruction %04X' % a
    for a in CODE_LABELS:
        assert a in STARTS, 'label not on instruction start %04X' % a
    unused = sorted(n for a, n in CODE_LABELS.items() if n not in USED)
    todo = sorted(a for a in UNNAMED if a not in CODE_LABELS)
    if todo:
        print('UNNAMED branch targets: ' + ' '.join('%04X' % a for a in todo))
        sys.exit(1)

    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(L) + '\n')
    print('instructions: %d  lines: %d' % (len(STARTS), len(L)))
    print('coverage: all %d bytes emitted' % len(SRC))
    print('code labels never referenced by any instruction:', ', '.join(unused) or '(none)')
    for n, e, a in EQU:
        print('equ %s = %s (%04X)' % (n, e, a))


main()
