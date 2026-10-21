#!/usr/bin/env python3
"""Dựng file draw.io từ một Mermaid flowchart.

Đọc file .mmd, hoặc khối ```mermaid đầu tiên trong file .md. Toàn bộ toạ độ (ô lưới,
khung subgraph, kênh đi dây, điểm gấp, vị trí nhãn) được tính tất định trong file này;
cùng một sơ đồ luôn ra cùng một file.

Mô hình layout (tính trong hệ toạ độ TB, hướng khác thì xoay/lật ở bước cuối):
- Mỗi node chiếm một ô (hàng = rank, cột = col). Hàng tính theo đường dài nhất.
- Mỗi subgraph chiếm trọn một hình chữ nhật ô; node ngoài subgraph không được đặt
  vào ô nào của hình đó, kể cả ô trống.
- Giữa hai cột là máng (gutter), giữa hai hàng là kênh (channel). Viền khung, băng
  tiêu đề, dải nhãn và track đi dây đều có slot riêng trong máng/kênh, nên dây
  không bao giờ trùng viền hay cắt qua ô có node.

Đoạn chung với flowtable2drawio.py (đo chữ Verdana, hình học, xuất và kiểm render)
được import từ file đó.

Generate lại khi file đích đã có: --mode force sinh lại toàn bộ; --mode merge giữ vị trí
node, khung subgraph, waypoint của edge và cell tự vẽ từ file đang có (lớp Merger).

Exit code: 0 ổn, 1 sơ đồ có lỗi, 2 layout tự kiểm có lỗi, 3 ảnh render lệch toạ độ,
4 file đích đã có mà chưa chọn chế độ, hoặc không merge được vào file đó.
"""
import argparse
import copy
import html
import json
import os
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass, field

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from flowtable2drawio import (  # noqa: E402
    CONSTRAINT_KEYS, FONT, HIGHLIGHT_EDGE, HIGHLIGHT_NODE, LAYER_IDS, FlowTableError, Issue, TextMeasure, area,
    collinear_overlap, drawio_bin, export, fmt, html_lines, num, path_len, read_drawio, rnd, seg_hits, shrink,
    verify_svg)

# Dấu nhận biết cell do tool sinh; merge dùng nó để tách cell người dùng tự vẽ.
MARK_KEY = 'mermaid2drawio'
MARK = f'{MARK_KEY}=1;'
DIRECTIONS = {'TD': 'TB', 'TB': 'TB', 'BT': 'BT', 'LR': 'LR', 'RL': 'RL'}
HIGHLIGHT_CLASS = 'highlight'
RESERVED_IDS = {'0', '1'}

# (mở, đóng, hình). Thứ tự quan trọng: dấu mở dài phải thử trước dấu mở ngắn.
SHAPE_DELIMS = [
    ('(((', ')))', 'dcircle'),
    ('((', '))', 'circle'),
    ('([', '])', 'stadium'),
    ('[[', ']]', 'subroutine'),
    ('[(', ')]', 'cylinder'),
    ('[/', '/]', 'lean_r'),
    ('[/', '\\]', 'trapezoid'),
    ('[\\', '\\]', 'lean_l'),
    ('[\\', '/]', 'trapezoid_inv'),
    ('{{', '}}', 'hexagon'),
    ('(', ')', 'round'),
    ('[', ']', 'rect'),
    ('{', '}', 'diamond'),
    ('>', ']', 'asym'),
]
# Hình có cạnh xiên dùng size cố định; cổng trái/phải của chúng nằm lùi vào trong
# hộp bao một đoạn, nên điểm đầu/cuối dây phải dịch theo (xem snap_ports).
SLANT = 16
SHAPE_STYLE = {
    'rect': 'rounded=0;html=1;',
    'round': 'rounded=1;arcSize=20;html=1;',
    'stadium': 'rounded=1;arcSize=50;html=1;',
    'subroutine': 'shape=process;size=8;fixedSize=1;html=1;',
    'cylinder': 'shape=cylinder3;html=1;boundedLbl=1;backgroundOutline=1;size=8;',
    'circle': 'ellipse;html=1;',
    'dcircle': 'ellipse;shape=doubleEllipse;html=1;',
    'diamond': 'rhombus;html=1;',
    'hexagon': f'shape=hexagon;perimeter=hexagonPerimeter2;size={SLANT};fixedSize=1;html=1;',
    'lean_r': f'shape=parallelogram;perimeter=parallelogramPerimeter;size={SLANT};fixedSize=1;html=1;',
    'lean_l': f'shape=parallelogram;perimeter=parallelogramPerimeter;size={SLANT};fixedSize=1;flipH=1;html=1;',
    'trapezoid': f'shape=trapezoid;perimeter=trapezoidPerimeter;size={SLANT};fixedSize=1;html=1;',
    'trapezoid_inv': f'shape=trapezoid;perimeter=trapezoidPerimeter;size={SLANT};fixedSize=1;flipV=1;html=1;',
    'asym': f'shape=step;perimeter=stepPerimeter;size={SLANT};fixedSize=1;html=1;',
}
# Khoảng lùi của cổng (trái, phải) so với hộp bao, tính ở nửa chiều cao.
PORT_INSET = {
    'lean_r': (SLANT / 2, SLANT / 2),
    'lean_l': (SLANT / 2, SLANT / 2),
    'trapezoid': (SLANT / 2, SLANT / 2),
    'trapezoid_inv': (SLANT / 2, SLANT / 2),
    'asym': (SLANT, 0),
}
EXTRA_W = {'stadium': 20, 'subroutine': 16, 'hexagon': 2 * SLANT, 'lean_r': SLANT, 'lean_l': SLANT,
           'trapezoid': 2 * SLANT, 'trapezoid_inv': 2 * SLANT, 'asym': SLANT}
CLUSTER_FILL = ['#f5f5f5', '#ebebeb', '#e0e0e0', '#d6d6d6']
ARROW_STYLE = {'arrow': 'classic', 'circle': 'oval', 'cross': 'cross'}


# ---------------------------------------------------------------- model

@dataclass
class MNode:
    id: str
    order: int
    line: int
    shape: str = 'rect'
    text: str = None
    classes: set = field(default_factory=set)
    cluster: str = None


@dataclass
class MSub:
    id: str
    title: str
    parent: str
    order: int
    line: int
    mentions: list = field(default_factory=list)


@dataclass
class MLink:
    src: str
    dst: str
    text: str
    style: str
    start: str
    end: str
    minlen: int
    line: int
    order: int


@dataclass
class Chart:
    source: str
    title: str = None
    direction: str = 'TB'
    nodes: dict = field(default_factory=dict)
    subs: dict = field(default_factory=dict)
    links: list = field(default_factory=list)
    issues: list = field(default_factory=list)


# ---------------------------------------------------------------- parse

ID_CHARS = r'[^\s\[\](){}<>|&;:"\'`=.@-]'
ID_RE = re.compile(rf'{ID_CHARS}+(?:[-.]{ID_CHARS}+)*')
CLASS_RE = re.compile(r':::([\w-]+)')
LABEL_OPEN_RE = re.compile(r'(?P<s>[<ox](?=[-=]))?(?P<op>--|==|-\.)(?=[\s"])')
LINK_RE = re.compile(r'(?P<s>[<ox](?=[-=~]))?(?P<b>-{2,}|-\.+-|={2,}|~{3,})(?P<e>>|[ox](?!\w))?')
LABEL_CLOSE_RE = {
    '--': re.compile(r'\s*(?P<b>-{2,})(?P<e>>|[ox](?!\w))?'),
    '==': re.compile(r'\s*(?P<b>={2,})(?P<e>>|[ox](?!\w))?'),
    '-.': re.compile(r'\s*(?P<b>\.+-)(?P<e>>|[ox](?!\w))?'),
}
HEADER_RE = re.compile(r'^(flowchart|graph)(?:\s+(\w+))?$', re.I)
SUB_BRACKET_RE = re.compile(r'^(\S+?)\s*\[\s*(.*?)\s*\]$')
BR_RE = re.compile(r'<br\s*/?>', re.I)
END_KIND = {'>': 'arrow', 'o': 'circle', 'x': 'cross', '<': 'arrow', None: None}


def clean_text(t):
    t = t.strip()
    if len(t) >= 2 and t[0] == '"' and t[-1] == '"':
        t = t[1:-1]
    if len(t) >= 2 and t[0] == '`' and t[-1] == '`':
        t = t[1:-1]
    t = re.sub(r'#(\d+);', r'&#\1;', t)
    t = re.sub(r'#([A-Za-z]+);', r'&\1;', t)
    t = BR_RE.sub('\n', t)
    t = html.unescape(t)
    return [l.strip() for l in t.split('\n')]


def split_statements(line):
    out, cur, depth, quote, pipe = [], '', 0, False, False
    for ch in line:
        if ch == '"':
            quote = not quote
        elif not quote:
            if ch in '[({':
                depth += 1
            elif ch in '])}':
                depth = max(0, depth - 1)
            elif ch == '|':
                pipe = not pipe
            elif ch == ';' and depth == 0 and not pipe:
                out.append(cur)
                cur = ''
                continue
        cur += ch
    out.append(cur)
    return [s.strip() for s in out if s.strip()]


class ParseError(Exception):
    pass


class ChainParser:
    """Đọc một câu lệnh dạng chuỗi node-link-node, trả về các nhóm node và link giữa chúng."""

    def __init__(self, s):
        self.s = s
        self.i = 0

    def ws(self):
        while self.i < len(self.s) and self.s[self.i].isspace():
            self.i += 1

    def at_end(self):
        self.ws()
        return self.i >= len(self.s)

    def node(self):
        self.ws()
        m = ID_RE.match(self.s, self.i)
        if not m:
            raise ParseError(f'không đọc được id node tại "{self.s[self.i:self.i + 20]}"')
        nid = m.group(0)
        self.i = m.end()
        shape, text = None, None
        for op in dict.fromkeys(op for op, _, _ in SHAPE_DELIMS):
            if not self.s.startswith(op, self.i):
                continue
            # Cùng một dấu mở ([/ hoặc [\) có hai dấu đóng: lấy dấu đóng gần nhất, dấu xa
            # hơn có thể thuộc node khác trên cùng dòng.
            found = [(got[1], name, got[0]) for o, cl, name in SHAPE_DELIMS if o == op
                     for got in [self.shape_text(self.i + len(op), cl)] if got]
            if not found:
                continue
            self.i, shape, text = min(found)
            break
        classes = set()
        m = CLASS_RE.match(self.s, self.i)
        if m:
            classes.add(m.group(1))
            self.i = m.end()
        return nid, shape, text, classes

    def shape_text(self, j, close):
        s = self.s
        while j < len(s) and s[j] == ' ':
            j += 1
        if j < len(s) and s[j] == '"':
            k = s.find('"', j + 1)
            if k < 0:
                raise ParseError('thiếu dấu " đóng chữ của node')
            text = s[j + 1:k]
            k += 1
            while k < len(s) and s[k] == ' ':
                k += 1
            if not s.startswith(close, k):
                return None
            return text, k + len(close)
        k = s.find(close, j)
        if k < 0:
            return None
        return s[j:k].strip(), k + len(close)

    def group(self):
        items = [self.node()]
        while True:
            self.ws()
            if self.i < len(self.s) and self.s[self.i] == '&':
                self.i += 1
                items.append(self.node())
            else:
                return items

    def link(self):
        self.ws()
        s = self.s
        text = None
        m = LABEL_OPEN_RE.match(s, self.i)
        if m:
            op = m.group('op')
            j = m.end()
            while j < len(s) and s[j] == ' ':
                j += 1
            close = None
            if j < len(s) and s[j] == '"':
                k = s.find('"', j + 1)
                if k < 0:
                    raise ParseError('thiếu dấu " đóng nhãn cạnh')
                text = s[j + 1:k]
                c = LABEL_CLOSE_RE[op].match(s, k + 1)
                if c and (c.group('e') or op == '-.' or len(c.group('b')) >= 3):
                    close = c
            else:
                for c in LABEL_CLOSE_RE[op].finditer(s, j):
                    if c.group('e') or op == '-.' or len(c.group('b')) >= 3:
                        close = c
                        text = s[j:c.start()]
                        break
            if close is None:
                raise ParseError(f'không tìm thấy đầu mũi tên đóng nhãn "{s[j:j + 20]}"')
            self.i = close.end()
            body, end = close.group('b'), close.group('e')
            style = {'--': 'solid', '==': 'thick', '-.': 'dotted'}[op]
            start = m.group('s')
        else:
            m = LINK_RE.match(s, self.i)
            if not m:
                raise ParseError(f'không đọc được mũi tên tại "{s[self.i:self.i + 20]}"')
            body, end, start = m.group('b'), m.group('e'), m.group('s')
            if body in ('--', '==') and not end:
                raise ParseError(f'mũi tên "{body}" không hợp lệ')
            self.i = m.end()
            style = ('invisible' if body[0] == '~' else 'thick' if body[0] == '=' else
                     'dotted' if '.' in body else 'solid')
        if style == 'dotted':
            length = body.count('.')
        elif style == 'invisible':
            length = len(body) - 2
        else:
            length = len(body) - (1 if end else 2)
        self.ws()
        if self.i < len(s) and s[self.i] == '|':
            k = s.find('|', self.i + 1)
            if k < 0:
                raise ParseError('thiếu dấu | đóng nhãn cạnh')
            text = s[self.i + 1:k]
            self.i = k + 1
        return {'text': text, 'style': style, 'start': END_KIND[start], 'end': END_KIND[end],
                'minlen': max(1, length)}

    def parse(self):
        groups, links = [self.group()], []
        while not self.at_end():
            links.append(self.link())
            groups.append(self.group())
        return groups, links


def parse_mermaid(text, source='<text>', title=None):
    ch = Chart(source, title)
    lines = text.split('\n')
    start = 0
    stripped = [l.strip() for l in lines]
    first = next((i for i, l in enumerate(stripped) if l), None)
    if first is not None and stripped[first] == '---':
        end = next((i for i in range(first + 1, len(lines)) if stripped[i] == '---'), None)
        if end is not None:
            for l in stripped[first + 1:end]:
                if l.startswith('title:'):
                    ch.title = l[6:].strip().strip('"\'') or ch.title
            start = end + 1

    def err(ln, msg, nid=''):
        ch.issues.append(Issue('error', f'dòng {ln}', nid, msg))

    def warn(ln, msg, nid=''):
        ch.issues.append(Issue('warning', f'dòng {ln}', nid, msg))

    header = False
    stack = []
    claimed_order = []
    mentioned_at = {}

    def touch(nid, shape, txt, classes, ln):
        n = ch.nodes.get(nid)
        if n is None:
            n = ch.nodes[nid] = MNode(nid, len(ch.nodes), ln)
            mentioned_at[nid] = ln
        if shape:
            n.shape, n.text = shape, txt
        n.classes |= classes
        if stack:
            stack[-1].mentions.append(nid)

    for ln0, raw in enumerate(lines[start:], start=start + 1):
        line = raw.strip()
        if not line or line.startswith('%%'):
            continue
        for st in split_statements(line):
            if not header:
                m = HEADER_RE.match(st)
                if not m:
                    err(ln0, 'dòng đầu phải là "flowchart <hướng>" hoặc "graph <hướng>"')
                    return ch
                d = (m.group(2) or 'TB').upper()
                if d not in DIRECTIONS:
                    err(ln0, f'hướng "{m.group(2)}" không hợp lệ, dùng TD, TB, BT, LR hoặc RL')
                    return ch
                ch.direction = DIRECTIONS[d]
                header = True
                continue
            word = st.split()[0]
            rest = st[len(word):].strip()
            if word == 'subgraph':
                m = SUB_BRACKET_RE.match(rest)
                if m:
                    sid, stitle = m.group(1), m.group(2)
                elif rest.startswith('"') or ' ' in rest or not rest:
                    sid, stitle = f'subGraph{len(ch.subs)}', rest or ' '
                else:
                    sid, stitle = rest, rest
                if sid in ch.subs:
                    err(ln0, f'subgraph {sid} bị khai báo hai lần', sid)
                    continue
                sub = MSub(sid, '\n'.join(clean_text(stitle)), stack[-1].id if stack else None,
                           len(ch.subs), ln0)
                ch.subs[sid] = sub
                stack.append(sub)
                if stack[:-1]:
                    stack[-2].mentions.append(sid)
            elif st == 'end':
                if not stack:
                    err(ln0, '"end" không khớp với subgraph nào')
                    continue
                claimed_order.append(stack.pop())
            elif word == 'direction':
                warn(ln0, 'direction bên trong subgraph chưa hỗ trợ, cả sơ đồ dùng chung một hướng')
            elif word == 'classDef':
                if rest.split()[:1] != [HIGHLIGHT_CLASS]:
                    warn(ln0, 'classDef bị bỏ qua; chỉ class tên highlight được tô màu nhấn')
            elif word == 'class':
                parts = rest.split()
                if len(parts) != 2:
                    err(ln0, 'cú pháp class phải là "class id1,id2 tên"')
                    continue
                if parts[1] != HIGHLIGHT_CLASS:
                    warn(ln0, f'class {parts[1]} bị bỏ qua; chỉ class tên highlight được tô màu nhấn')
                    continue
                for nid in parts[0].split(','):
                    touch(nid.strip(), None, None, {HIGHLIGHT_CLASS}, ln0)
            elif word in ('style', 'linkStyle', 'click'):
                warn(ln0, f'{word} bị bỏ qua, style lấy theo mặc định của tool')
            else:
                try:
                    groups, links = ChainParser(st).parse()
                except ParseError as ex:
                    err(ln0, str(ex))
                    continue
                for g in groups:
                    for nid, shape, txt, classes in g:
                        touch(nid, shape, txt, classes, ln0)
                for k, lk in enumerate(links):
                    for a in groups[k]:
                        for b in groups[k + 1]:
                            ch.links.append(MLink(a[0], b[0], lk['text'], lk['style'], lk['start'], lk['end'],
                                                  lk['minlen'], ln0, len(ch.links)))
    if not header:
        err(1, 'không có dòng "flowchart <hướng>"')
        return ch
    for sub in stack:
        err(sub.line, f'subgraph {sub.id} thiếu "end"', sub.id)
    # Như mermaid: node thuộc subgraph đóng sớm nhất có nhắc tới nó; nhắc ở ngoài mọi
    # subgraph không giữ node lại ở ngoài.
    for sub in claimed_order:
        for nid in sub.mentions:
            n = ch.nodes.get(nid)
            if n is not None and n.cluster is None:
                n.cluster = sub.id
    for nid in ch.nodes:
        if nid in ch.subs:
            err(mentioned_at[nid], f'{nid} là id của subgraph; nối cạnh vào subgraph chưa hỗ trợ', nid)
    for lk in ch.links:
        if lk.src == lk.dst and lk.style == 'invisible':
            warn(lk.line, 'cạnh ẩn tự nối vào chính nó bị bỏ qua', lk.src)
    if not ch.nodes:
        err(1, 'sơ đồ không có node nào')
    return ch


MD_BLOCK_RE = re.compile(r'^```\s*mermaid\s*$(.*?)^```\s*$', re.M | re.S)


def load(path):
    try:
        with open(path, encoding='utf-8-sig') as f:
            text = f.read()
    except OSError as ex:
        raise FlowTableError(f'không đọc được {path}: {ex.strerror}')
    title = None
    if path.lower().endswith(('.md', '.markdown')):
        m = MD_BLOCK_RE.search(text)
        if not m:
            raise FlowTableError(f'{path} không có khối ```mermaid')
        h = re.search(r'^#\s+(.+?)\s*$', text[:m.start()], re.M)
        title = h.group(1) if h else None
        offset = text[:m.start(1)].count('\n')
        body = '\n' * offset + m.group(1)
    else:
        body = text
    ch = parse_mermaid(body, path)
    ch.title = ch.title or title or os.path.splitext(os.path.basename(path))[0]
    return ch


# ---------------------------------------------------------------- layout model

@dataclass
class Config:
    task_min_w: int = 120
    task_max_w: int = 240
    cond_wrap: int = 150
    term_wrap: int = 150
    db_wrap: int = 130
    label_wrap: int = 180
    title_wrap: int = 320
    track_gap: int = 12
    gutter_margin: int = 12
    channel_margin: int = 10
    min_gutter: int = 40
    min_channel: int = 36
    mid_gap: int = 20
    cluster_pad: int = 16
    title_pad: int = 6
    label_pad: int = 4
    empty_col: int = 40
    empty_row: int = 20


@dataclass
class Node:
    id: str
    cid: str
    shape: str
    lines: list
    order: int
    cluster: str
    highlight: bool
    w: float
    h: float
    tw: float = 0.0
    th: float = 0.0
    rank: int = 0
    col: int = 0
    tx: float = 0.0
    ty: float = 0.0
    x: float = 0.0
    y: float = 0.0

    @property
    def kind(self):
        return self.shape

    def box(self):
        return (self.x, self.y, self.x + self.w, self.y + self.h)


@dataclass
class Cluster:
    id: str
    cid: str
    lines: list
    title_w: float
    title_h: float
    parent: str
    order: int
    depth: int = 1
    r0: int = 0
    r1: int = 0
    c0: int = 0
    c1: int = 0
    tbox: tuple = None
    tband: tuple = None
    box: tuple = None
    band: tuple = None
    title: tuple = None
    title_align: str = 'left'


@dataclass
class Track:
    kind: str
    idx: int
    zone: object
    key: tuple
    lo: int
    hi: int
    order: int
    stubs: list = field(default_factory=list)
    track: int = None


@dataclass
class Edge:
    id: str
    src: str
    dst: str
    lines: list
    lw: float
    lh: float
    order: int
    style: str
    start: str
    end: str
    minlen: int
    back: bool = False
    ctx: str = None
    case: str = None
    route: list = None
    label_at: tuple = None
    tpts: list = None
    pts: list = None
    anchor: tuple = None
    label: tuple = None
    label_t: float = 0.0
    label_off: tuple = (0.0, 0.0)
    exit_frac: tuple = (0.5, 1.0)
    entry_frac: tuple = (0.5, 0.0)
    # Các trường dưới chỉ đặt khi merge.
    waypoints: list = None
    constraints: dict = None
    auto: bool = False
    label_mode: str = 'computed'

    @property
    def start_arrow(self):
        return self.start is not None

    @property
    def visible(self):
        return self.style != 'invisible'


def cell_id(raw, used):
    cid = raw if raw not in RESERVED_IDS else f'n{raw}'
    while cid in used:
        cid = '_' + cid
    used.add(cid)
    return cid


class Layout:
    def __init__(self, chart, cfg=None, tm=None):
        self.cfg = cfg or Config()
        self.tm = tm or TextMeasure()
        self.dir = chart.direction
        self.horizontal = self.dir in ('LR', 'RL')
        self.warnings = []
        used = set()
        self.nodes = {}
        for n in sorted(chart.nodes.values(), key=lambda n: n.order):
            if n.id in chart.subs:
                continue
            lines = clean_text(n.text) if n.text is not None else [n.id]
            lines, w, h = self.size_node(n.shape, lines)
            nd = Node(n.id, cell_id(n.id, used), n.shape, lines, n.order, n.cluster,
                      HIGHLIGHT_CLASS in n.classes, w, h)
            nd.tw, nd.th = (h, w) if self.horizontal else (w, h)
            self.nodes[n.id] = nd
        self.clusters = {}
        for s in sorted(chart.subs.values(), key=lambda s: s.order):
            lines = self.tm.wrap(s.title.split('\n'), self.cfg.title_wrap)
            tw, th = self.tm.box(lines)
            self.clusters[s.id] = Cluster(s.id, cell_id(s.id, used), lines, tw, th, s.parent, s.order)
        self.edges = []
        # Id edge theo cặp nguồn-đích và lần xuất hiện của cặp đó (như L_A_B_0 của mermaid),
        # để chèn cạnh ở chỗ khác không làm đổi id; merge đối chiếu edge theo id này.
        seen_pair = defaultdict(int)
        for lk in chart.links:
            if lk.src not in self.nodes or lk.dst not in self.nodes:
                continue
            if lk.style == 'invisible' and lk.src == lk.dst:
                continue
            lines = self.tm.wrap(clean_text(lk.text), self.cfg.label_wrap) if lk.text and lk.text.strip() else []
            lw, lh = self.tm.box(lines) if lines else (0, 0)
            k = seen_pair[(lk.src, lk.dst)]
            seen_pair[(lk.src, lk.dst)] += 1
            eid = cell_id(f'L-{lk.src}-{lk.dst}-{k}', used)
            self.edges.append(Edge(eid, lk.src, lk.dst, lines, rnd(lw + 2 * self.cfg.label_pad) if lines else 0,
                                   rnd(lh + 2) if lines else 0, lk.order, lk.style, lk.start, lk.end,
                                   lk.minlen))
        self.origin = (40.0, 40.0)

    # ------------------------------------------------ sizing

    def size_node(self, shape, lines):
        tm, cfg = self.tm, self.cfg
        if shape == 'diamond':
            wl = tm.wrap(lines, cfg.cond_wrap)
            tw, th = tm.box(wl)
            # Chữ nằm lọt hình thoi khi tw/W + th/H <= 1.
            return wl, rnd(max(100, tw / 0.6 + 10)), rnd(max(60, th / 0.4 + 10))
        if shape in ('circle', 'dcircle'):
            wl = tm.wrap(lines, cfg.term_wrap)
            tw, th = tm.box(wl)
            d = rnd(max(50, max(tw, th) * 1.42 + 16 + (12 if shape == 'dcircle' else 0)))
            return wl, d, d
        if shape == 'cylinder':
            wl = tm.wrap(lines, cfg.db_wrap)
            tw, th = tm.box(wl)
            return wl, rnd(max(100, tw + 24)), rnd(max(60, th + 34))
        extra = EXTRA_W.get(shape, 0)
        wl = tm.wrap(lines, cfg.task_max_w - 32)
        tw, th = tm.box(wl)
        return wl, rnd(max(cfg.task_min_w, tw + 32 + extra)), rnd(max(40, th + 20))

    # ------------------------------------------------ helpers

    def ancestors(self, cid):
        out = []
        while cid is not None:
            out.append(cid)
            cid = self.clusters[cid].parent
        return out

    def lca(self, a, b):
        pa = self.ancestors(self.nodes[a].cluster)
        pb = set(self.ancestors(self.nodes[b].cluster))
        return next((c for c in pa if c in pb), None)

    # ------------------------------------------------ ranks

    def rank_nodes(self):
        order = sorted(self.nodes, key=lambda i: self.nodes[i].order)
        outs = defaultdict(list)
        ins_any = defaultdict(int)
        for e in self.edges:
            outs[e.src].append(e)
            if e.src != e.dst:
                ins_any[e.dst] += 1
        state = {}
        roots = [v for v in order if not ins_any[v]] + order
        for root in roots:
            if root in state:
                continue
            state[root] = 1
            stack = [(root, iter(outs[root]))]
            while stack:
                v, it = stack[-1]
                e = next(it, None)
                if e is None:
                    state[v] = 2
                    stack.pop()
                    continue
                w = e.dst
                if w == v or state.get(w) == 1:
                    e.back = True
                elif w not in state:
                    state[w] = 1
                    stack.append((w, iter(outs[w])))
        fwd = [e for e in self.edges if not e.back]
        self.fouts, self.fins = defaultdict(list), defaultdict(list)
        for e in fwd:
            self.fouts[e.src].append(e)
            self.fins[e.dst].append(e)
        indeg = {v: len(self.fins[v]) for v in order}
        ready = [v for v in order if not indeg[v]]
        topo = []
        while ready:
            ready.sort(key=lambda i: self.nodes[i].order)
            v = ready.pop(0)
            topo.append(v)
            for e in self.fouts[v]:
                indeg[e.dst] -= 1
                if not indeg[e.dst]:
                    ready.append(e.dst)
        rank = {}
        for v in topo:
            rank[v] = max((rank[e.src] + e.minlen for e in self.fins[v]), default=0)
        # Node nguồn (trừ nguồn đầu tiên) được kéo xuống sát node đích gần nhất.
        for v in reversed(topo):
            if not self.fins[v] and self.fouts[v] and v != topo[0]:
                rank[v] = max(rank[v], min(rank[e.dst] - e.minlen for e in self.fouts[v]))
        base = min(rank.values())
        for v, r in rank.items():
            self.nodes[v].rank = r - base
        self.topo = topo
        down = {}
        for v in reversed(topo):
            down[v] = max((1 + down[e.dst] for e in self.fouts[v] if e.visible), default=0)
        # Nhánh chính: đích có đường đi xuôi dài nhất, hoà thì cạnh viết sau. Nhánh phụ
        # viết trước nhánh chính đứng bên trái, viết sau đứng bên phải.
        self.primary, self.offset = {}, {}
        for v in order:
            outs_v = [e for e in self.fouts[v] if e.visible]
            if not outs_v:
                continue
            dsts = []
            for e in outs_v:
                if e.dst not in dsts:
                    dsts.append(e.dst)
            main = max(range(len(dsts)), key=lambda k: (down[dsts[k]], k))
            self.primary[v] = dsts[main]
            off = {}
            for k, d in enumerate(dsts):
                off[d] = k - main
            for e in self.fouts[v]:
                self.offset[e.id] = off.get(e.dst, 0)

    # ------------------------------------------------ columns

    def desired(self, v, pos):
        cands = [e for e in self.fins[v] if e.src in pos]
        if not cands:
            return None
        prim = [e for e in cands if self.primary.get(e.src) == v]
        pool = prim or cands
        e = max(pool, key=lambda e: (self.nodes[e.src].rank, e.order))
        off = self.offset.get(e.id, 0)
        return pos[e.src][1] + off, (-1 if off < 0 else 1)

    @staticmethod
    def search(want, dirn, fits):
        if fits(want):
            return want
        k = 1
        while True:
            for c in (want + dirn * k, want - dirn * k):
                if fits(c):
                    return c
            k += 1

    def place_block(self, cid):
        kids = [n for n in self.nodes.values() if n.cluster == cid]
        subs = [s for s in self.clusters.values() if s.parent == cid and s.id in self.alive]
        sub_lay = {s.id: self.place_block(s.id) for s in subs}
        entries = [(n.rank, n.order, 'n', n.id) for n in kids]
        for s in subs:
            spos = sub_lay[s.id][0]
            entries.append((min(r for r, _ in spos.values()), min(self.nodes[m].order for m in spos), 's', s.id))
        entries.sort()
        occ, pos, rects = set(), {}, {}
        for _, _, kind, key in entries:
            if kind == 'n':
                r = self.nodes[key].rank
                want, dirn = self.desired(key, pos) or (0, 1)
                c = self.search(want, dirn, lambda c: (r, c) not in occ)
                pos[key] = (r, c)
                occ.add((r, c))
                continue
            spos, srects, sw = sub_lay[key]
            want_o, dirn = 0, 1
            for m in sorted(spos, key=lambda m: (spos[m][0], self.nodes[m].order)):
                d = self.desired(m, pos)
                if d:
                    want_o, dirn = d[0] - spos[m][1], d[1]
                    break
            r0 = min(r for r, _ in spos.values())
            r1 = max(r for r, _ in spos.values())
            cells = [(r, c) for r in range(r0, r1 + 1) for c in range(sw)]
            o = self.search(want_o, dirn, lambda o: all((r, c + o) not in occ for r, c in cells))
            for m, (r, c) in spos.items():
                pos[m] = (r, c + o)
            for sid, (a, b) in srects.items():
                rects[sid] = (a + o, b + o)
            occ.update((r, c + o) for r, c in cells)
        cols = [c for _, c in pos.values()] + [c for ab in rects.values() for c in ab]
        mn = min(cols)
        pos = {k: (r, c - mn) for k, (r, c) in pos.items()}
        rects = {k: (a - mn, b - mn) for k, (a, b) in rects.items()}
        width = max(cols) - mn + 1
        if cid is not None:
            rects[cid] = (0, width - 1)
        return pos, rects, width

    def place(self):
        members = defaultdict(list)
        for n in self.nodes.values():
            for c in self.ancestors(n.cluster):
                members[c].append(n.id)
        self.members = members
        self.alive = {c for c in self.clusters if members[c]}
        for c in self.clusters:
            if c not in self.alive:
                self.warnings.append(f'subgraph {c} không có node nào, không vẽ')
        pos, rects, width = self.place_block(None)
        for nid, (r, c) in pos.items():
            self.nodes[nid].col = c
        self.nc = width
        self.nr = max(n.rank for n in self.nodes.values()) + 1
        for cid in self.alive:
            cl = self.clusters[cid]
            cl.c0, cl.c1 = rects[cid]
            ranks = [self.nodes[m].rank for m in members[cid]]
            cl.r0, cl.r1 = min(ranks), max(ranks)
            cl.depth = len(self.ancestors(cid))
        self.cell = {(n.rank, n.col): n.id for n in self.nodes.values()}

    # ------------------------------------------------ routing (lưới)

    def zone_of(self, kind, idx, ctx):
        if ctx is None:
            return 'M'
        cl = self.clusters[ctx]
        lo, hi = (cl.c0, cl.c1) if kind == 'G' else (cl.r0, cl.r1)
        if hi == idx - 1:
            return ('E', cl.depth)
        if lo == idx:
            return ('S', cl.depth)
        return 'M'

    def track(self, kind, idx, ctx, key, lo, hi, order, stubs=()):
        zone = self.zone_of(kind, idx, ctx)
        k = (kind, idx, zone, key)
        t = self.tracks.get(k)
        if t is None:
            t = self.tracks[k] = Track(kind, idx, zone, key, lo, hi, order)
        t.lo, t.hi = min(t.lo, lo), max(t.hi, hi)
        t.stubs.extend(stubs)
        return t

    def free_col(self, rows, c):
        return all((r, c) not in self.cell and (r, c) not in self.col_use for r in rows)

    def route(self):
        self.tracks = {}
        self.col_use, self.row_use = set(), set()
        vis = [e for e in self.edges if e.visible]
        for e in vis:
            e.ctx = self.lca(e.src, e.dst)
        bottom_exits = defaultdict(int)
        for e in vis:
            u, v = self.nodes[e.src], self.nodes[e.dst]
            if e.back or u.col != v.col or not self.free_col(range(u.rank + 1, v.rank), u.col):
                continue
            e.case = 'A'
            self.col_use.update((r, u.col) for r in range(u.rank + 1, v.rank))
            e.route = [(('cc', u.col), ('nb', e.src)), (('cc', u.col), ('nt', e.dst))]
        for e in vis:
            if e.case:
                continue
            u, v = self.nodes[e.src], self.nodes[e.dst]
            if e.back or u.col == v.col:
                continue
            step = 1 if v.col > u.col else -1
            between = list(range(u.col + step, v.col + step, step))
            if any((u.rank, c) in self.cell or (u.rank, c) in self.row_use for c in between):
                continue
            if not self.free_col(range(u.rank, v.rank), v.col):
                continue
            e.case = 'C'
            self.row_use.update((u.rank, c) for c in between)
            self.col_use.update((r, v.col) for r in range(u.rank, v.rank))
            side = ('nr' if step > 0 else 'nl', e.src)
            e.route = [(side, ('rc', u.rank)), (('cc', v.col), ('rc', u.rank)), (('cc', v.col), ('nt', e.dst))]
        rest = [e for e in vis if not e.case]
        for e in rest:
            bottom_exits[e.src] += 1
        for e in rest:
            u, v = self.nodes[e.src], self.nodes[e.dst]
            c1, c2 = u.col, v.col
            k1 = u.rank + 1
            if not e.back and c1 != c2 and self.free_col(range(u.rank + 1, v.rank), c2):
                e.case = 'Z'
                self.col_use.update((r, c2) for r in range(u.rank + 1, v.rank))
                key = ('src', e.src) if bottom_exits[e.src] > 1 else ('dst', e.dst)
                t = self.track('C', k1, e.ctx, key, min(2 * c1 + 1, 2 * c2 + 1), max(2 * c1 + 1, 2 * c2 + 1),
                               e.order, [(('c', c1), 'up'), (('c', c2), 'down')])
                e.route = [(('cc', c1), ('nb', e.src)), (('cc', c1), ('ct', t)),
                           (('cc', c2), ('ct', t)), (('cc', c2), ('nt', e.dst))]
                continue
            if e.back:
                e.case = 'B'
                g = max(c1, c2) + 1
            else:
                e.case = 'D'
                g = c2 if c1 <= c2 else c2 + 1
            k2 = v.rank
            gt = self.track('G', g, e.ctx, ('e', e.id), min(2 * k1, 2 * k2), max(2 * k1, 2 * k2), e.order)
            up_first = 'down' if k2 > k1 else 'up'
            t1 = self.track('C', k1, e.ctx, ('src', e.src), min(2 * c1 + 1, 2 * g), max(2 * c1 + 1, 2 * g),
                            e.order, [(('c', c1), 'up'), (('g', gt), up_first)])
            t2 = self.track('C', k2, e.ctx, ('dst', e.dst), min(2 * c2 + 1, 2 * g), max(2 * c2 + 1, 2 * g),
                            e.order, [(('g', gt), 'up' if k2 > k1 else 'down'), (('c', c2), 'down')])
            e.route = [(('cc', c1), ('nb', e.src)), (('cc', c1), ('ct', t1)), (('gt', gt), ('ct', t1)),
                       (('gt', gt), ('ct', t2)), (('cc', c2), ('ct', t2)), (('cc', c2), ('nt', e.dst))]
        # Nhãn nằm trên đoạn dọc cuối, ngay trên node đích và dưới mọi track của kênh đó:
        # đoạn phía trên có thể là dây chung của nhiều cạnh cùng nguồn, đặt nhãn ở đó sẽ
        # không rõ nhãn thuộc nhánh nào.
        for e in vis:
            v = self.nodes[e.dst]
            e.label_at = (('cc', v.col), v.rank)

    def assign_tracks(self):
        groups = defaultdict(list)
        for t in self.tracks.values():
            groups[(t.kind, t.idx, t.zone)].append(t)
        for gk in sorted((k for k in groups if k[0] == 'G'), key=str):
            self.color(groups[gk], {})
        for gk in sorted((k for k in groups if k[0] == 'C'), key=str):
            self.color(groups[gk], self.stub_constraints(groups[gk]))

    @staticmethod
    def stub_pos(p):
        if p[0] == 'g':
            t = p[1]
            return ('g', t.idx, t.zone, t.track)
        return p

    def stub_constraints(self, items):
        """a phải nằm trên b khi a có dây đi lên và b có dây đi xuống ở cùng một điểm."""
        above = defaultdict(set)
        for a in items:
            ups = {self.stub_pos(p) for p, d in a.stubs if d == 'up'}
            for b in items:
                if a is b:
                    continue
                if ups & {self.stub_pos(p) for p, d in b.stubs if d == 'down'}:
                    above[id(a)].add(id(b))
        return above

    @staticmethod
    def color(items, above):
        items = sorted(items, key=lambda t: (t.lo, t.hi, t.order))
        preds = defaultdict(set)
        for a in items:
            for b in above.get(id(a), ()):
                preds[b].add(id(a))
        done, by_id = set(), {id(t): t for t in items}
        seq = []
        while len(seq) < len(items):
            ready = [t for t in items if id(t) not in done and not (preds[id(t)] - done)]
            if not ready:
                ready = [t for t in items if id(t) not in done]
            t = ready[0]
            done.add(id(t))
            seq.append(t)
        placed = []
        for t in seq:
            lb = max((by_id[p].track + 1 for p in preds[id(t)] if by_id[p].track is not None), default=0)
            k = lb
            while any(o.track == k and t.lo <= o.hi and o.lo <= t.hi for o in placed):
                k += 1
            t.track = k
            placed.append(t)

    # ------------------------------------------------ geometry (TB)

    def slot_layout(self, kind, idx, cur):
        cfg = self.cfg
        cls = [self.clusters[c] for c in self.alive]
        if kind == 'G':
            ending = [c for c in cls if c.c1 == idx - 1]
            starting = [c for c in cls if c.c0 == idx]
            margin, minimal = cfg.gutter_margin, cfg.min_gutter
        else:
            ending = [c for c in cls if c.r1 == idx - 1]
            starting = [c for c in cls if c.r0 == idx]
            margin, minimal = cfg.channel_margin, cfg.min_channel
        pos = {}
        state = {'cur': cur}

        def zone(z):
            n = self.ntracks.get((kind, idx, z), 0)
            band = self.bands.get((idx, z), 0) if kind == 'C' else 0
            if not n and not band:
                return
            state['cur'] += margin
            if n:
                pos[('track', z)] = state['cur']
                state['cur'] += (n - 1) * cfg.track_gap
                if band:
                    state['cur'] += margin
            if band:
                pos[('band', z)] = state['cur']
                state['cur'] += band
            state['cur'] += margin

        def title(group, grp_list):
            if self.title_slot != (kind, group[0]):
                return
            th = max(c.title_h for c in grp_list if c.depth == group[1])
            pos[('title', group)] = state['cur'] + cfg.title_pad
            state['cur'] += th + 2 * cfg.title_pad

        for d in sorted({c.depth for c in ending}, reverse=True):
            zone(('E', d))
            title(('E', d), ending)
            state['cur'] += cfg.cluster_pad
            pos[('border', ('E', d))] = state['cur']
        mid0 = state['cur']
        zone('M')
        need = cfg.mid_gap if (ending or starting) else minimal
        used = state['cur'] - mid0
        if used < need:
            shift = rnd((need - used) / 2)
            for k in list(pos):
                if k[1] == 'M':
                    pos[k] += shift
            state['cur'] = mid0 + need
        for d in sorted({c.depth for c in starting}):
            pos[('border', ('S', d))] = state['cur']
            title(('S', d), starting)
            zone(('S', d))
            state['cur'] += cfg.cluster_pad
        return state['cur'], pos

    def compute_geometry(self):
        cfg = self.cfg
        self.ntracks = defaultdict(int)
        for t in self.tracks.values():
            k = (t.kind, t.idx, t.zone)
            self.ntracks[k] = max(self.ntracks[k], t.track + 1)
        self.bands = defaultdict(int)
        for e in self.edges:
            if e.lines and e.label_at:
                k = e.label_at[1]
                z = self.zone_of('C', k, e.ctx)
                self.bands[(k, z)] = max(self.bands[(k, z)], e.lw if self.horizontal else e.lh)
        self.title_slot = {'TB': ('C', 'S'), 'BT': ('C', 'E'), 'LR': ('G', 'S'), 'RL': ('G', 'S')}[self.dir]
        col_w = [0] * self.nc
        row_h = [0] * self.nr
        for n in self.nodes.values():
            col_w[n.col] = max(col_w[n.col], n.tw)
            row_h[n.rank] = max(row_h[n.rank], n.th)
        col_w = [w or cfg.empty_col for w in col_w]
        row_h = [h or cfg.empty_row for h in row_h]
        for _ in range(8):
            self.col_x, self.gpos, self.W = self.axis('G', col_w)
            self.row_y, self.cpos, self.H = self.axis('C', row_h)
            self.col_w, self.row_h = col_w, row_h
            grown = False
            for cid in sorted(self.alive, key=lambda c: -self.clusters[c].depth):
                cl = self.clusters[cid]
                x0, y0, x1, y1 = self.cluster_tbox(cl)
                need = cl.title_w + 2 * 8
                if self.title_slot[0] == 'C':
                    if x1 - x0 < need:
                        col_w[cl.c1] += rnd(need - (x1 - x0))
                        grown = True
                elif y1 - y0 < need:
                    row_h[cl.r1] += rnd(need - (y1 - y0))
                    grown = True
            if not grown:
                break
        for n in self.nodes.values():
            n.tx = self.col_x[n.col] + (self.col_w[n.col] - n.tw) / 2
            n.ty = self.row_y[n.rank] + (self.row_h[n.rank] - n.th) / 2
        for cid in self.alive:
            cl = self.clusters[cid]
            cl.tbox = self.cluster_tbox(cl)
            x0, y0, x1, y1 = cl.tbox
            grp = ('S' if self.title_slot[1] == 'S' else 'E', cl.depth)
            if self.title_slot[0] == 'C':
                idx = cl.r0 if grp[0] == 'S' else cl.r1 + 1
                t = self.cpos[idx][('title', grp)]
                cl.tband = (x0, t, x1, t + cl.title_h)
            else:
                t = self.gpos[cl.c0][('title', grp)]
                cl.tband = (t, y0, t + cl.title_h, y1)

    def axis(self, kind, sizes):
        starts, slots = [], []
        cur = 0
        for i in range(len(sizes) + 1):
            cur, pos = self.slot_layout(kind, i, cur)
            slots.append(pos)
            if i < len(sizes):
                starts.append(cur)
                cur += sizes[i]
        return starts, slots, cur

    def cluster_tbox(self, cl):
        return (self.gpos[cl.c0][('border', ('S', cl.depth))], self.cpos[cl.r0][('border', ('S', cl.depth))],
                self.gpos[cl.c1 + 1][('border', ('E', cl.depth))], self.cpos[cl.r1 + 1][('border', ('E', cl.depth))])

    def ex(self, x):
        k, v = x
        if k == 'cc':
            return self.col_x[v] + self.col_w[v] / 2
        if k == 'gt':
            return self.gpos[v.idx][('track', v.zone)] + v.track * self.cfg.track_gap
        n = self.nodes[v]
        return n.tx if k == 'nl' else n.tx + n.tw

    def ey(self, y):
        k, v = y
        if k == 'rc':
            return self.row_y[v] + self.row_h[v] / 2
        if k == 'ct':
            return self.cpos[v.idx][('track', v.zone)] + v.track * self.cfg.track_gap
        n = self.nodes[v]
        return n.ty if k == 'nt' else n.ty + n.th

    # ------------------------------------------------ transform

    def T(self, x, y):
        ox, oy = self.origin
        if self.dir == 'TB':
            return (ox + x, oy + y)
        if self.dir == 'BT':
            return (ox + x, oy + self.H - y)
        if self.dir == 'LR':
            return (ox + y, oy + x)
        return (ox + self.H - y, oy + x)

    def Tbox(self, b):
        (ax, ay), (bx, by) = self.T(b[0], b[1]), self.T(b[2], b[3])
        return (min(ax, bx), min(ay, by), max(ax, bx), max(ay, by))

    def to_real(self):
        for n in self.nodes.values():
            x0, y0, _, _ = self.Tbox((n.tx, n.ty, n.tx + n.tw, n.ty + n.th))
            n.x, n.y = x0, y0
        for cid in self.alive:
            cl = self.clusters[cid]
            cl.box = self.Tbox(cl.tbox)
            cl.band = self.Tbox(cl.tband)
        if self.horizontal:
            self.pool_w, self.pool_h = self.H, self.W
        else:
            self.pool_w, self.pool_h = self.W, self.H
        for e in self.edges:
            if not e.visible:
                continue
            pts = [self.T(self.ex(x), self.ey(y)) for x, y in e.route]
            pts = self.snap_ports(e, pts)
            e.pts = simplify(pts)
            ax, k = e.label_at
            e.anchor = self.T(self.ex(ax), self.band_center(e, k)) if e.lines else None
            u, v = self.nodes[e.src], self.nodes[e.dst]
            e.exit_frac = frac(u, e.pts[0])
            e.entry_frac = frac(v, e.pts[-1])

    def band_center(self, e, k):
        z = self.zone_of('C', k, e.ctx)
        return self.cpos[k][('band', z)] + self.bands[(k, z)] / 2

    def snap_ports(self, e, pts):
        for end, nid in ((0, e.src), (-1, e.dst)):
            n = self.nodes[nid]
            inset = PORT_INSET.get(n.shape)
            if not inset:
                continue
            x, y = pts[end]
            if abs(x - n.x) < 0.01:
                pts[end] = (x + inset[0], y)
            elif abs(x - (n.x + n.w)) < 0.01:
                pts[end] = (x - inset[1], y)
        return pts

    # ------------------------------------------------ titles, labels

    def segments(self, skip=None):
        out = []
        for e in self.edges:
            if e.pts and e.id != skip:
                out.extend((e.id, a, b) for a, b in zip(e.pts, e.pts[1:]))
        return out

    def borders(self):
        out = []
        for cid in self.alive:
            x0, y0, x1, y1 = self.clusters[cid].box
            out += [(cid, (x0, y0), (x1, y0)), (cid, (x1, y0), (x1, y1)),
                    (cid, (x0, y1), (x1, y1)), (cid, (x0, y0), (x0, y1))]
        return out

    def place_titles(self):
        segs = self.segments()
        nodes = [n.box() for n in self.nodes.values()]
        for cid in sorted(self.alive, key=lambda c: self.clusters[c].order):
            cl = self.clusters[cid]
            bx0, by0, bx1, _ = cl.band
            w, h = cl.title_w, cl.title_h
            best = None
            for align, x in (('left', bx0 + 8), ('right', bx1 - 8 - w), ('center', (bx0 + bx1 - w) / 2)):
                box = (x, by0, x + w, by0 + h)
                cost = sum(100 for _, a, b in segs if seg_hits(a, b, box))
                cost += sum(area(box, nb) for nb in nodes)
                if best is None or cost < best[0]:
                    best = (cost, align, box)
                if cost == 0:
                    break
            cost, cl.title_align, cl.title = best
            if cost:
                self.warnings.append(f'subgraph {cid}: tiêu đề không tránh được dây')

    def place_labels(self):
        boxes = [n.box() for n in self.nodes.values()]
        titles = [self.clusters[c].title for c in self.alive]
        borders = self.borders()
        placed = []
        for e in sorted(self.edges, key=lambda x: x.order):
            if not e.lines or not e.pts:
                continue
            segs = self.segments(skip=e.id)
            best = None
            for box, dist, anchor in self.label_candidates(e):
                cost = sum(area(box, b) * 4 for b in boxes + titles + placed)
                # Điểm neo trên đoạn dây chung với cạnh khác thì người đọc không biết nhãn
                # thuộc cạnh nào.
                cost += sum(30 for _, a, b in segs if on_segment(anchor, a, b))
                cost += sum(100 for _, a, b in segs if seg_hits(a, b, box))
                cost += sum(50 for _, a, b in borders if seg_hits(a, b, box))
                if best is None or cost < best[0]:
                    best = (cost, box, dist, anchor)
                if cost == 0:
                    break
            if best is None:
                self.warnings.append(f'{e.id}: đường quá ngắn, không có chỗ đặt nhãn')
                continue
            cost, box, dist, anchor = best
            if cost:
                self.warnings.append(f'{e.id}: nhãn "{" ".join(e.lines)}" không tìm được chỗ trống hoàn toàn')
            placed.append(box)
            e.label = box
            total = path_len(e.pts)
            e.label_t = round(2 * dist / total - 1, 4) if total else 0
            cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
            e.label_off = (round(cx - anchor[0], 2), round(cy - anchor[1], 2))

    def label_candidates(self, e):
        w, h = e.lw, e.lh
        out = []

        def around(p, vertical, dist):
            px, py = p
            out.append(((px - w / 2, py - h / 2, px + w / 2, py + h / 2), dist, p))
            if vertical:
                for cx in (px + 5 + w / 2, px - 5 - w / 2):
                    out.append(((cx - w / 2, py - h / 2, cx + w / 2, py + h / 2), dist, p))
            else:
                for cy in (py - 3 - h / 2, py + 3 + h / 2):
                    out.append(((px - w / 2, cy - h / 2, px + w / 2, cy + h / 2), dist, p))

        acc = 0.0
        segs = []
        for a, b in zip(e.pts, e.pts[1:]):
            L = abs(b[0] - a[0]) + abs(b[1] - a[1])
            segs.append((a, b, acc, L))
            acc += L
        if e.anchor:
            for a, b, s0, L in segs:
                if on_segment(e.anchor, a, b):
                    around(e.anchor, abs(a[0] - b[0]) < 0.01,
                           s0 + abs(e.anchor[0] - a[0]) + abs(e.anchor[1] - a[1]))
                    break
        for a, b, s0, L in segs:
            if L < 12:
                continue
            for f in (0.5, 0.25, 0.75):
                p = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
                around(p, abs(a[0] - b[0]) < 0.01, s0 + L * f)
        return out

    # ------------------------------------------------ checks

    def check(self):
        issues = []
        nodes = sorted(self.nodes.values(), key=lambda n: n.order)
        for i, a in enumerate(nodes):
            for b in nodes[i + 1:]:
                if area(a.box(), b.box()) > 0:
                    issues.append(('error', f'{a.id} và {b.id} chồng lên nhau'))
        alive = sorted(self.alive, key=lambda c: self.clusters[c].order)
        for cid in alive:
            box = self.clusters[cid].box
            inside = set(self.members[cid])
            for n in nodes:
                nb = n.box()
                if n.id in inside:
                    if nb[0] < box[0] or nb[1] < box[1] or nb[2] > box[2] or nb[3] > box[3]:
                        issues.append(('error', f'{n.id} tràn ra ngoài khung {cid}'))
                elif area(nb, box) > 0:
                    issues.append(('error', f'{n.id} nằm trong khung {cid} dù không thuộc subgraph đó'))
            for other in alive:
                if other == cid or cid in self.ancestors(other) or other in self.ancestors(cid):
                    continue
                if other > cid and area(box, self.clusters[other].box) > 0:
                    issues.append(('error', f'khung {cid} và {other} chồng lên nhau'))
        borders = self.borders()
        allsegs = []
        for e in self.edges:
            if not e.pts:
                continue
            pts = e.pts
            for k, (a, b) in enumerate(zip(pts, pts[1:])):
                if abs(a[0] - b[0]) > 0.01 and abs(a[1] - b[1]) > 0.01:
                    issues.append(('error', f'{e.id}: đoạn {k} không vuông góc'))
                for n in nodes:
                    if n.id in (e.src, e.dst) and (k == 0 or k == len(pts) - 2):
                        continue
                    if seg_hits(a, b, shrink(n.box(), 1)):
                        issues.append(('error', f'{e.id}: dây cắt qua {n.id}'))
                for cid, p, q in borders:
                    if collinear_overlap(a, b, p, q) > 1:
                        issues.append(('error', f'{e.id}: dây chạy trùng viền khung {cid}'))
                allsegs.append((e, a, b))
        for i, (e1, a1, b1) in enumerate(allsegs):
            for e2, a2, b2 in allsegs[i + 1:]:
                if e1 is e2 or e1.dst == e2.dst or e1.src == e2.src:
                    continue
                if collinear_overlap(a1, b1, a2, b2) > 1:
                    issues.append(('error', f'{e1.id} và {e2.id} chồng dây'))
        labels = [(e, e.label) for e in self.edges if e.label]
        for i, (e, lb) in enumerate(labels):
            for n in nodes:
                if area(lb, n.box()) > 0:
                    issues.append(('warning', f'nhãn {e.id} đè lên {n.id}'))
            for e2, lb2 in labels[i + 1:]:
                if area(lb, lb2) > 0:
                    issues.append(('warning', f'nhãn {e.id} đè nhãn {e2.id}'))
            for e2, a, b in allsegs:
                if e2 is not e and seg_hits(a, b, lb):
                    issues.append(('warning', f'nhãn {e.id} đè dây {e2.id}'))
            for cid in alive:
                if area(lb, self.clusters[cid].title) > 0:
                    issues.append(('warning', f'nhãn {e.id} đè tiêu đề khung {cid}'))
        for cid in alive:
            tb = self.clusters[cid].title
            for e2, a, b in allsegs:
                if seg_hits(a, b, tb):
                    issues.append(('warning', f'tiêu đề khung {cid} bị dây {e2.id} cắt qua'))
            for n in nodes:
                if area(tb, n.box()) > 0:
                    issues.append(('error', f'tiêu đề khung {cid} đè lên {n.id}'))
        seen, out = set(), []
        for x in issues:
            if x not in seen:
                seen.add(x)
                out.append(x)
        return out

    # ------------------------------------------------ run

    def run(self):
        self.rank_nodes()
        self.place()
        self.route()
        self.assign_tracks()
        self.compute_geometry()
        self.to_real()
        self.place_titles()
        self.place_labels()
        return self

    def drawn_edges(self):
        return [e for e in self.edges if e.visible]

    def to_json(self):
        return {
            'direction': self.dir,
            'size': {'w': self.pool_w, 'h': self.pool_h},
            'clusters': {c: {'box': self.clusters[c].box, 'title': self.clusters[c].title,
                             'rows': [self.clusters[c].r0, self.clusters[c].r1],
                             'cols': [self.clusters[c].c0, self.clusters[c].c1]}
                         for c in sorted(self.alive)},
            'nodes': {n.id: {'shape': n.shape, 'rank': n.rank, 'col': n.col, 'x': n.x, 'y': n.y, 'w': n.w, 'h': n.h}
                      for n in self.nodes.values()},
            'edges': {e.id: {'case': e.case, 'back': e.back, 'points': e.pts, 'label': e.label}
                      for e in self.drawn_edges()},
        }


def simplify(pts):
    out = []
    for p in pts:
        if out and abs(out[-1][0] - p[0]) < 0.01 and abs(out[-1][1] - p[1]) < 0.01:
            continue
        out.append(p)
    k = 1
    while k < len(out) - 1:
        a, b, c = out[k - 1], out[k], out[k + 1]
        if (abs(a[0] - b[0]) < 0.01 and abs(b[0] - c[0]) < 0.01) or \
                (abs(a[1] - b[1]) < 0.01 and abs(b[1] - c[1]) < 0.01):
            del out[k]
        else:
            k += 1
    return out


def frac(n, p):
    return (round((p[0] - n.x) / n.w, 4), round((p[1] - n.y) / n.h, 4))


def on_segment(p, a, b):
    return (min(a[0], b[0]) - 0.01 <= p[0] <= max(a[0], b[0]) + 0.01 and
            min(a[1], b[1]) - 0.01 <= p[1] <= max(a[1], b[1]) + 0.01)


# ---------------------------------------------------------------- xml

def edge_ports(lay, e):
    """exitX, exitY, entryX, entryY đúng như ghi vào style; draw.io lật toạ độ cổng theo flipH/flipV."""
    def port(nid, fr):
        st = SHAPE_STYLE[lay.nodes[nid].shape]
        return (1 - fr[0] if 'flipH=1' in st else fr[0], 1 - fr[1] if 'flipV=1' in st else fr[1])
    return port(e.src, e.exit_frac) + port(e.dst, e.entry_frac)


def content_extent(lay):
    """Góc phải dưới của mọi thứ tool vẽ, tính cùng một cách cho build mới và merge."""
    xs, ys = [lay.origin[0]], [lay.origin[1]]
    for n in lay.nodes.values():
        xs.append(n.x + n.w)
        ys.append(n.y + n.h)
    for cid in lay.alive:
        b = lay.clusters[cid].box
        xs.append(b[2])
        ys.append(b[3])
    for e in lay.drawn_edges():
        pts = e.waypoints if e.waypoints is not None else (e.pts or [])
        xs += [p[0] for p in pts]
        ys += [p[1] for p in pts]
        if e.label and e.label_mode == 'computed' and not e.auto:
            xs.append(e.label[2])
            ys.append(e.label[3])
    return max(xs), max(ys)


def to_drawio(lay, title, extras=(), other_pages=()):
    ox, oy = lay.origin
    right, bottom = content_extent(lay)
    for b in getattr(lay, 'extra_boxes', ()):
        right, bottom = max(right, b[2]), max(bottom, b[3])
    mxfile = ET.Element('mxfile', host='mermaid2drawio')
    diagram = ET.SubElement(mxfile, 'diagram', id='mermaid', name=(title or 'Flow')[:80])
    model = ET.SubElement(diagram, 'mxGraphModel', grid='1', gridSize='10', guides='1', tooltips='1',
                          connect='1', arrows='1', fold='1', page='1', pageScale='1',
                          pageWidth=fmt(rnd(right + ox)), pageHeight=fmt(rnd(bottom + oy)),
                          math='0', shadow='0')
    root = ET.SubElement(model, 'root')
    ET.SubElement(root, 'mxCell', id='0')
    ET.SubElement(root, 'mxCell', id='1', parent='0')

    def geo(cell, x, y, w, h):
        ET.SubElement(cell, 'mxGeometry', x=fmt(x), y=fmt(y), width=fmt(w), height=fmt(h), **{'as': 'geometry'})

    def parent_of(cid):
        if cid is None:
            return '1', 0.0, 0.0
        cl = lay.clusters[cid]
        return cl.cid, cl.box[0], cl.box[1]

    for cid in sorted(lay.alive, key=lambda c: (lay.clusters[c].depth, lay.clusters[c].order)):
        cl = lay.clusters[cid]
        pid, px, py = parent_of(cl.parent)
        x0, y0, x1, y1 = cl.box
        tx0, ty0, tx1, _ = cl.title
        if cl.title_align == 'left':
            align = f'align=left;spacingLeft={fmt(tx0 - x0)};'
        elif cl.title_align == 'right':
            align = f'align=right;spacingRight={fmt(x1 - tx1)};'
        else:
            align = 'align=center;'
        fill = CLUSTER_FILL[min(cl.depth, len(CLUSTER_FILL)) - 1]
        style = (f'rounded=0;html=1;container=1;collapsible=0;recursiveResize=0;verticalAlign=top;spacing=0;'
                 f'spacingTop={fmt(ty0 - y0)};{align}fillColor={fill};strokeColor=#666666;')
        c = ET.SubElement(root, 'mxCell', id=cl.cid, value=html_lines(cl.lines), vertex='1', parent=pid,
                          style=style + FONT + MARK)
        geo(c, x0 - px, y0 - py, x1 - x0, y1 - y0)
    for n in sorted(lay.nodes.values(), key=lambda n: n.order):
        style = SHAPE_STYLE[n.shape] + (HIGHLIGHT_NODE if n.highlight else '')
        pid, px, py = parent_of(n.cluster)
        c = ET.SubElement(root, 'mxCell', id=n.cid, value=html_lines(n.lines), vertex='1', parent=pid,
                          style=style + FONT + MARK)
        geo(c, n.x - px, n.y - py, n.w, n.h)
    for e in sorted(lay.drawn_edges(), key=lambda x: x.order):
        style = ('edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;'
                 'labelBackgroundColor=default;')
        if e.auto:
            pass
        elif e.constraints is not None:
            style += ''.join(f'{k}={v};' for k, v in e.constraints.items())
        else:
            ex, ey, nx, ny = edge_ports(lay, e)
            style += (f'exitX={fmt(ex)};exitY={fmt(ey)};exitDx=0;exitDy=0;exitPerimeter=0;'
                      f'entryX={fmt(nx)};entryY={fmt(ny)};entryDx=0;entryDy=0;entryPerimeter=0;')
        style += f'endArrow={ARROW_STYLE[e.end]};endFill=1;' if e.end else 'endArrow=none;'
        if e.start:
            style += f'startArrow={ARROW_STYLE[e.start]};startFill=1;'
        if e.style == 'dotted':
            style += 'dashed=1;'
        elif e.style == 'thick':
            style += 'strokeWidth=2;'
        c = ET.SubElement(root, 'mxCell', id=e.id, value=html_lines(e.lines), edge='1', parent='1',
                          source=lay.nodes[e.src].cid, target=lay.nodes[e.dst].cid, style=style + FONT + MARK)
        g = ET.SubElement(c, 'mxGeometry', relative='1', **{'as': 'geometry'})
        with_label = bool(e.label) and e.label_mode == 'computed' and not e.auto
        if with_label:
            g.set('x', fmt(e.label_t))
        if e.auto:
            pts = []
        elif e.waypoints is not None:
            pts = e.waypoints
        else:
            pts = e.pts[1:-1]
        if pts:
            arr = ET.SubElement(g, 'Array', **{'as': 'points'})
            for x, y in pts:
                ET.SubElement(arr, 'mxPoint', x=fmt(x), y=fmt(y))
        if with_label:
            ET.SubElement(g, 'mxPoint', x=fmt(e.label_off[0]), y=fmt(e.label_off[1]), **{'as': 'offset'})
    for el in extras:
        root.append(el)
    for page in other_pages:
        mxfile.append(page)
    ET.indent(mxfile, space='  ')
    return ET.tostring(mxfile, encoding='unicode')


# ---------------------------------------------------------------- merge

@dataclass
class MergeReport:
    pinned: list = field(default_factory=list)
    placed: list = field(default_factory=list)
    shifted: list = field(default_factory=list)
    cluster_changed: list = field(default_factory=list)
    kept_edges: list = field(default_factory=list)
    rerouted: list = field(default_factory=list)
    labels_centered: list = field(default_factory=list)
    removed: list = field(default_factory=list)
    clusters_grown: list = field(default_factory=list)
    freehand_kept: list = field(default_factory=list)
    freehand_moved: list = field(default_factory=list)
    freehand_detached: list = field(default_factory=list)
    overlaps: list = field(default_factory=list)

    def lines(self):
        def row(label, xs):
            return f'merge: {label} ({len(xs)}): ' + (', '.join(xs) if xs else '-')
        return [
            row('giữ vị trí', self.pinned),
            row('node mới', self.placed),
            row('node mới phải dịch xuống vì chồng', self.shifted),
            row('đổi subgraph, đặt lại', self.cluster_changed),
            row('edge giữ waypoint', self.kept_edges),
            row('edge để draw.io tự đi dây, cần chỉnh tay', self.rerouted),
            row('edge đã sửa tay, nhãn về giữa đường', self.labels_centered),
            row('xoá vì không còn trong mermaid', self.removed),
            row('khung subgraph được nới', self.clusters_grown),
            row('cell tự vẽ giữ lại', self.freehand_kept),
            row('cell tự vẽ chuyển ra ngoài (cha đã bị xoá)', self.freehand_moved),
            row('cell tự vẽ mất đầu nối', self.freehand_detached),
            row('phần tử chồng nhau', self.overlaps),
        ]


class Merger:
    """Áp layout mới tính lên file đang có: giữ hình học của phần tử cũ theo id cell.

    Node cũ giữ tâm (kích thước tính lại theo chữ). Node mới đặt theo láng giềng đã
    giữ, lệch đúng như trong layout mới tính, chồng thì dịch xuống. Khung subgraph cũ
    giữ nguyên và chỉ nới ra cho vừa nội dung. Edge giữ waypoint khi cả hai đầu được
    giữ vị trí. Cell không mang dấu mermaid2drawio=1 là cell người dùng tự vẽ, chép sang.
    """
    PAD = 10
    STEP = 10

    def __init__(self, lay, old):
        self.lay = lay
        self.old = old
        self.rep = MergeReport()

    def run(self):
        lay, old = self.lay, self.old
        cells = old.cells
        self.gen = {cid for cid, c in cells.items() if MARK_KEY in c.style}
        if not self.gen:
            raise FlowTableError('file đích không do mermaid2drawio sinh (không cell nào mang dấu '
                                 'mermaid2drawio=1); dùng --mode force để sinh lại toàn bộ')
        self.gen |= set(LAYER_IDS)
        self.node_cid = {n.cid: n for n in lay.nodes.values()}
        self.cluster_cid = {lay.clusters[c].cid: lay.clusters[c] for c in lay.alive}
        edges = lay.drawn_edges()
        self.alive_ids = set(self.node_cid) | set(self.cluster_cid) | {e.id for e in edges} | set(LAYER_IDS)
        # Ảnh chụp layout mới tính: khoảng lệch cho node mới và mốc để biết edge đã bị sửa chưa.
        self.fresh_c = {n.id: (n.x + n.w / 2, n.y + n.h / 2) for n in lay.nodes.values()}
        self.fresh_wp = {e.id: e.pts[1:-1] for e in edges}
        self.fresh_ports = {e.id: edge_ports(lay, e) for e in edges}
        self.old_cluster_box = {}
        for cl in self.cluster_cid.values():
            c = cells.get(cl.cid)
            if c is not None and c.vertex and cl.cid in self.gen:
                x, y, w, h = old.abs_box(cl.cid)
                self.old_cluster_box[cl.id] = (x, y, x + w, y + h)
        self.freehand = [cid for cid, c in sorted(cells.items(), key=lambda kv: kv[1].order)
                         if cid not in self.gen]
        self.fh_boxes = []
        for cid in self.freehand:
            if cells[cid].vertex:
                x, y, w, h = old.abs_box(cid)
                self.fh_boxes.append((x, y, x + w, y + h))
        self.final = {}
        self.place_old_nodes()
        self.place_new_nodes()
        self.route_edges()
        self.fit_clusters()
        lay.place_titles()
        extras = self.collect_freehand()
        lay.extra_boxes = self.fh_boxes
        self.finish()
        for cid in sorted(self.gen - self.alive_ids):
            self.rep.removed.append(cid)
        return extras, old.other_pages, self.rep

    # ---- node

    def place_old_nodes(self):
        lay, old = self.lay, self.old
        self.pinned = set()
        for n in sorted(lay.nodes.values(), key=lambda n: n.order):
            c = old.cells.get(n.cid)
            if c is None or not c.vertex or n.cid not in self.gen:
                continue
            want = lay.clusters[n.cluster].cid if n.cluster else '1'
            # Node đang nằm trong một khung vẫn còn mà nay thuộc chỗ khác: giữ vị trí cũ thì
            # nó kẹt trong khung cũ, nên đặt lại như node mới.
            if c.parent != want and c.parent in self.cluster_cid:
                self.rep.cluster_changed.append(n.id)
                continue
            ax, ay, w, h = old.abs_box(n.cid)
            n.x, n.y = ax + w / 2 - n.w / 2, ay + h / 2 - n.h / 2
            self.final[n.id] = n
            self.pinned.add(n.id)
            self.rep.pinned.append(n.id)

    def neighbors(self, nid):
        out = []
        for back in (False, True):
            out += [e.src for e in self.lay.edges if e.dst == nid and e.back == back]
            out += [e.dst for e in self.lay.edges if e.src == nid and e.back == back]
        return out

    def find_anchor(self, v):
        lay = self.lay
        for e in sorted((e for e in lay.edges if e.dst == v.id), key=lambda e: (e.back, e.order)):
            if e.src in self.final:
                return e.src
        for e in sorted((e for e in lay.edges if e.src == v.id), key=lambda e: (e.back, e.order)):
            if e.dst in self.final:
                return e.dst
        seen, frontier = {v.id}, [v.id]
        while frontier:
            nxt = []
            for n in frontier:
                for m in self.neighbors(n):
                    if m in seen:
                        continue
                    if m in self.final:
                        return m
                    seen.add(m)
                    nxt.append(m)
            frontier = sorted(nxt, key=lambda i: lay.nodes[i].order)
        return None

    def obstacles(self, n):
        mine = set(self.lay.ancestors(n.cluster))
        boxes = [o.box() for i, o in self.final.items() if i != n.id]
        boxes += self.fh_boxes
        boxes += [b for cid, b in self.old_cluster_box.items() if cid not in mine]
        return boxes

    def put(self, n, cx, cy):
        n.x, n.y = cx - n.w / 2, cy - n.h / 2
        obs = self.obstacles(n)
        m = self.PAD
        moved = False
        while any(area((n.x - m, n.y - m, n.x + n.w + m, n.y + n.h + m), b) > 0 for b in obs):
            n.y += self.STEP
            moved = True
        if moved:
            self.rep.shifted.append(n.id)
        self.final[n.id] = n
        self.rep.placed.append(n.id)

    def place_new_nodes(self):
        lay = self.lay
        order = {v: k for k, v in enumerate(lay.topo)}
        pending = sorted((n for n in lay.nodes.values() if n.id not in self.final),
                         key=lambda n: (order.get(n.id, 1e9), n.order))
        for n in pending:
            a = self.find_anchor(n)
            fv = self.fresh_c[n.id]
            if a is None:
                bottom = max((b[3] for b in self.obstacles(n)), default=lay.origin[1])
                self.put(n, fv[0], bottom + lay.cfg.min_channel + n.h / 2)
                continue
            an, fa = self.final[a], self.fresh_c[a]
            self.put(n, an.x + an.w / 2 + fv[0] - fa[0], an.y + an.h / 2 + fv[1] - fa[1])

    # ---- edge

    def route_edges(self):
        lay, old = self.lay, self.old
        for e in lay.drawn_edges():
            c = old.cells.get(e.id)
            src, dst = lay.nodes[e.src], lay.nodes[e.dst]
            keep = (c is not None and c.edge and e.id in self.gen
                    and c.cell.get('source') == src.cid and c.cell.get('target') == dst.cid
                    and e.src in self.pinned and e.dst in self.pinned)
            if not keep:
                e.auto = True
                e.pts = None
                self.rep.rerouted.append(e.id)
                continue
            px, py = old.origin(c.parent)
            e.waypoints = [(px + x, py + y) for x, y in c.points()]
            st = c.style
            e.constraints = {k: st[k] for k in CONSTRAINT_KEYS if k in st and st[k] is not None}
            self.rep.kept_edges.append(e.id)
            if self.untouched(e):
                continue
            e.label_mode = 'none'
            e.pts = [self.port_point(src, e.constraints, 'exit')] + e.waypoints + \
                [self.port_point(dst, e.constraints, 'entry')]
            if e.lines:
                self.rep.labels_centered.append(e.id)

    def untouched(self, e):
        for nid in (e.src, e.dst):
            n, (fx, fy) = self.final[nid], self.fresh_c[nid]
            if abs(n.x + n.w / 2 - fx) > 2 or abs(n.y + n.h / 2 - fy) > 2:
                return False
        fresh = self.fresh_wp[e.id]
        if len(fresh) != len(e.waypoints):
            return False
        if any(abs(a[0] - b[0]) > 2 or abs(a[1] - b[1]) > 2 for a, b in zip(fresh, e.waypoints)):
            return False
        for k, v in zip(('exitX', 'exitY', 'entryX', 'entryY'), self.fresh_ports[e.id]):
            try:
                # So với đúng giá trị đã ghi ra file (fmt làm tròn 2 chữ số).
                if k not in e.constraints or abs(float(e.constraints[k]) - float(fmt(v))) > 1e-6:
                    return False
            except ValueError:
                return False
        return True

    @staticmethod
    def port_point(n, cons, end):
        try:
            fx = float(cons.get(end + 'X', 0.5))
            fy = float(cons.get(end + 'Y', 0.5))
        except ValueError:
            fx = fy = 0.5
        return (n.x + fx * n.w, n.y + fy * n.h)

    # ---- subgraph

    def fit_clusters(self):
        lay, cfg = self.lay, self.lay.cfg
        pad, tpad = cfg.cluster_pad, cfg.title_pad
        # Băng tiêu đề nằm cách viền trên đúng như layout mới tính (BT đặt tiêu đề ở nhóm viền
        # kết thúc nên có thêm cluster_pad).
        t_off = pad + tpad if lay.dir == 'BT' else tpad
        for cid in sorted(lay.alive, key=lambda c: (-lay.clusters[c].depth, lay.clusters[c].order)):
            cl = lay.clusters[cid]
            boxes = [self.final[m].box() for m in lay.members[cid]]
            boxes += [lay.clusters[k].box for k in lay.alive if lay.clusters[k].parent == cid]
            x0 = min(b[0] for b in boxes) - pad
            y0 = min(b[1] for b in boxes) - pad - cl.title_h - 2 * tpad
            x1 = max(b[2] for b in boxes) + pad
            y1 = max(b[3] for b in boxes) + pad
            x1 = max(x1, x0 + cl.title_w + 16)
            need = (x0, y0, x1, y1)
            ob = self.old_cluster_box.get(cid)
            if ob is None:
                box = need
            else:
                box = (min(ob[0], x0), min(ob[1], y0), max(ob[2], x1), max(ob[3], y1))
                if box != ob:
                    self.rep.clusters_grown.append(cid)
            cl.box = box
            cl.band = (box[0], box[1] + t_off, box[2], box[1] + t_off + cl.title_h)

    # ---- cell tự vẽ

    def new_origin(self, cid):
        n = self.node_cid.get(cid)
        if n is not None:
            return n.x, n.y
        cl = self.cluster_cid.get(cid)
        if cl is not None:
            return cl.box[0], cl.box[1]
        return None

    @staticmethod
    def shift_geo(g, dx, dy, vertex):
        if g is None or (not dx and not dy):
            return
        if vertex and g.get('relative') != '1':
            g.set('x', fmt(num(g, 'x') + dx))
            g.set('y', fmt(num(g, 'y') + dy))
            return
        for pt in g.iter('mxPoint'):
            if pt.get('as') == 'offset':
                continue
            pt.set('x', fmt(num(pt, 'x') + dx))
            pt.set('y', fmt(num(pt, 'y') + dy))

    def collect_freehand(self):
        old = self.old
        extras = []
        for cid in self.freehand:
            c = old.cells[cid]
            el = copy.deepcopy(c.elem)
            cell = el if el.tag == 'mxCell' else el.find('mxCell')
            g = cell.find('mxGeometry')
            p = c.parent
            if p in self.gen and p not in LAYER_IDS:
                ox, oy = old.origin(p)
                if p in self.alive_ids:
                    no = self.new_origin(p)
                    if no is not None:
                        self.shift_geo(g, ox - no[0], oy - no[1], c.vertex)
                else:
                    cell.set('parent', '1')
                    self.shift_geo(g, ox, oy, c.vertex)
                    self.rep.freehand_moved.append(cid)
            if c.edge:
                self.detach(c, cell)
            extras.append(el)
            self.rep.freehand_kept.append(cid)
        return extras

    def detach(self, c, cell):
        old = self.old
        for end, pt_name in (('source', 'sourcePoint'), ('target', 'targetPoint')):
            ref = cell.get(end)
            if not ref or ref not in self.gen or ref in self.alive_ids or ref not in old.cells:
                continue
            ax, ay, w, h = old.abs_box(ref)
            px, py = (0.0, 0.0) if cell.get('parent') == '1' else old.origin(c.parent)
            del cell.attrib[end]
            g = cell.find('mxGeometry')
            if g is None:
                g = ET.SubElement(cell, 'mxGeometry', relative='1', **{'as': 'geometry'})
            for pt in g.findall('mxPoint'):
                if pt.get('as') == pt_name:
                    g.remove(pt)
            ET.SubElement(g, 'mxPoint', x=fmt(ax + w / 2 - px), y=fmt(ay + h / 2 - py), **{'as': pt_name})
            self.rep.freehand_detached.append(f'{c.id}.{end}')

    def finish(self):
        lay = self.lay
        nodes = sorted(lay.nodes.values(), key=lambda n: n.order)
        for k, a in enumerate(nodes):
            for b in nodes[k + 1:]:
                if area(a.box(), b.box()) > 0:
                    self.rep.overlaps.append(f'{a.id}/{b.id}')
        for cid in sorted(lay.alive, key=lambda c: lay.clusters[c].order):
            inside = set(lay.members[cid])
            for n in nodes:
                if n.id not in inside and area(n.box(), lay.clusters[cid].box) > 0:
                    self.rep.overlaps.append(f'{n.id}/khung {cid}')


def merge_into(lay, old):
    return Merger(lay, old).run()


# ---------------------------------------------------------------- cli

class VerifyView:
    """Mặt phẳng dữ liệu mà verify_svg cần: node theo id cell và các cạnh có vẽ."""

    def __init__(self, lay):
        self.items = {n.cid: argparse.Namespace(id=n.cid, order=n.order, x=n.x, y=n.y)
                      for n in lay.nodes.values()}
        self.edges = lay.drawn_edges()


def print_issues(issues):
    for x in sorted(issues, key=lambda i: i.level != 'error'):
        print(x)
    ne = sum(1 for x in issues if x.level == 'error')
    print(f'check: {ne} lỗi, {len(issues) - ne} cảnh báo')
    return ne


def cmd_check(args):
    try:
        chart = load(args.file)
    except FlowTableError as ex:
        print(f'ERROR   {ex}')
        return 1
    print(f'check: đọc mermaid từ {chart.source} ({len(chart.nodes)} node, {len(chart.links)} cạnh, '
          f'{len(chart.subs)} subgraph, hướng {chart.direction})')
    return 1 if print_issues(chart.issues) else 0


def choose_mode(args, out):
    """Trả về 'new' | 'force' | 'merge', hoặc None nếu phải dừng."""
    if not os.path.exists(out):
        return 'new'
    if args.mode:
        return args.mode
    if not sys.stdin.isatty():
        print(f'ERROR   {out} đã tồn tại; chọn --mode merge (giữ vị trí, khung, waypoint đã sửa tay) '
              'hoặc --mode force (sinh lại toàn bộ)')
        return None
    ans = input(f'{out} đã tồn tại. [m]erge giữ chỉnh sửa tay / [f]orce sinh lại toàn bộ / [q]uit: ').strip().lower()
    return {'m': 'merge', 'merge': 'merge', 'f': 'force', 'force': 'force'}.get(ans)


def cmd_build(args):
    try:
        chart = load(args.file)
    except FlowTableError as ex:
        print(f'ERROR   {ex}')
        return 1
    print(f'check: đọc mermaid từ {chart.source}')
    if print_issues(chart.issues):
        print('build: dừng vì sơ đồ có lỗi')
        return 1
    cfg = Config()
    for k in vars(cfg):
        v = getattr(args, k, None)
        if v is not None:
            setattr(cfg, k, v)
    tm = TextMeasure(font_path=args.font)
    if not tm.font:
        print('WARNING không đọc được font Verdana, dùng độ rộng ước lượng')
    out = args.output or os.path.splitext(args.file)[0] + '.drawio'
    mode = choose_mode(args, out)
    if mode is None:
        print('build: dừng, chưa chọn chế độ ghi')
        return 4
    old = None
    if mode == 'merge':
        try:
            old = read_drawio(out)
        except FlowTableError as ex:
            print(f'ERROR   {ex}; không ghi đè. Dùng --mode force nếu muốn sinh lại toàn bộ')
            return 4
    lay = Layout(chart, cfg, tm).run()
    issues = lay.check()
    extras, pages, report = [], [], None
    if old is not None:
        try:
            extras, pages, report = merge_into(lay, old)
        except FlowTableError as ex:
            print(f'ERROR   {ex}')
            return 4
    backup = None
    if mode in ('merge', 'force') and not args.no_backup:
        backup = out + '.bak'
        shutil.copy2(out, backup)
    title = args.title or chart.title
    with open(out, 'w', encoding='utf-8') as f:
        f.write(to_drawio(lay, title, extras, pages))
    right, bottom = content_extent(lay)
    labels = {'new': 'tạo mới', 'force': 'force, sinh lại toàn bộ', 'merge': 'merge, giữ chỉnh sửa tay'}
    print(f'build: chế độ {labels[mode]}')
    print(f'build: đã ghi {out} ({len(lay.nodes)} node, {len(lay.alive)} subgraph, '
          f'{len(lay.drawn_edges())} cạnh, hướng {lay.dir}, {fmt(right - lay.origin[0])}x{fmt(bottom - lay.origin[1])}px)')
    if backup:
        print(f'build: bản sao file cũ {backup}')
    if args.layout_json:
        with open(args.layout_json, 'w', encoding='utf-8') as f:
            json.dump(lay.to_json(), f, ensure_ascii=False, indent=1)
    for w in lay.warnings:
        print(f'WARNING layout: {w}')
    code = 0
    if report is not None:
        for line in report.lines():
            print(line)
        print('layout: merge không tự kiểm dây và nhãn; xem danh sách ở trên và ảnh PNG')
    else:
        for level, msg in issues:
            print(f'{level.upper():7} layout: {msg}')
        nerr = sum(1 for l, _ in issues if l == 'error')
        print(f'layout: {nerr} lỗi, {len(issues) - nerr} cảnh báo')
        code = 2 if nerr else 0
    if args.png or args.verify:
        if not drawio_bin():
            print('WARNING không có drawio CLI, bỏ qua xuất ảnh và kiểm render')
            return code
        if report is not None and args.verify:
            print('render: bỏ qua kiểm render ở chế độ merge (đường dây giữ từ file hoặc do draw.io tự đi)')
            args.verify = False
        try:
            if args.png:
                png = os.path.splitext(out)[0] + '.png' if args.png is True else args.png
                export(out, png, 'png', scale=2)
                print(f'png: {png}')
            if args.verify:
                with tempfile.TemporaryDirectory() as d:
                    svg = os.path.join(d, 'render.svg')
                    export(out, svg, 'svg')
                    probs = verify_svg(VerifyView(lay), svg)
                for p in probs:
                    print(f'ERROR   render: {p}')
                print(f'render: {len(probs)} điểm lệch')
                if probs and not code:
                    code = 3
        except FlowTableError as ex:
            print(f'ERROR   {ex}')
            return code or 3
    return code


def main(argv=None):
    ap = argparse.ArgumentParser(description='Mermaid flowchart (.mmd, .md) --> draw.io')
    sub = ap.add_subparsers(dest='cmd', required=True)
    c = sub.add_parser('check', help='kiểm tra cú pháp mermaid flowchart')
    c.add_argument('file')
    c.set_defaults(fn=cmd_check)
    b = sub.add_parser('build', help='kiểm tra, dựng layout và ghi file .drawio')
    b.add_argument('file')
    b.add_argument('-o', '--output', help='mặc định: cạnh file nguồn, cùng tên, đuôi .drawio')
    b.add_argument('--title', help='tên trang, mặc định lấy title trong frontmatter, heading # hoặc tên file')
    b.add_argument('--layout-json', help='ghi toạ độ đã tính ra file json')
    b.add_argument('--png', nargs='?', const=True, help='xuất ảnh PNG (mặc định cạnh file .drawio)')
    b.add_argument('--verify', action='store_true', help='xuất SVG bằng drawio CLI và so với toạ độ đã tính')
    b.add_argument('--font', help='đường dẫn Verdana.ttf nếu không nằm ở vị trí mặc định')
    b.add_argument('--mode', choices=['merge', 'force'],
                   help='khi file đích đã có: merge giữ vị trí/khung/waypoint đã sửa tay, force sinh lại toàn bộ')
    b.add_argument('--no-backup', action='store_true', help='không tạo <file>.drawio.bak trước khi ghi đè')
    for k, v in vars(Config()).items():
        b.add_argument('--' + k.replace('_', '-'), dest=k, type=int, default=None, help=f'mặc định {v}')
    b.set_defaults(fn=cmd_build)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == '__main__':
    sys.exit(main())
