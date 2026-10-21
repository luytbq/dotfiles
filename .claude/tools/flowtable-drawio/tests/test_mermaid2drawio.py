import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import mermaid2drawio as mm  # noqa: E402

FIX = os.path.join(HERE, 'fixtures', 'mermaid')
FIXTURES = ['payment-link.mmd', 'shapes.mmd', 'loop.mmd', 'nested.mmd', 'lr.mmd']


def parse(body):
    return mm.parse_mermaid(body)


def errors(chart):
    return [i for i in chart.issues if i.level == 'error']


def build(name):
    chart = mm.load(os.path.join(FIX, name))
    assert not errors(chart), errors(chart)
    return chart, mm.Layout(chart).run()


class ParseNodeTest(unittest.TestCase):
    def test_every_shape_delimiter(self):
        ch = parse('flowchart TD\n A[a] --> B(b) --> C([c]) --> D[[d]] --> E[(e)] --> F((f)) --> G(((g)))\n'
                   ' G --> H{h} --> I{{i}} --> J>j] --> K[/k/] --> L[\\l\\] --> M[/m\\] --> N[\\n/]')
        shapes = {n.id: n.shape for n in ch.nodes.values()}
        self.assertEqual(shapes, {
            'A': 'rect', 'B': 'round', 'C': 'stadium', 'D': 'subroutine', 'E': 'cylinder', 'F': 'circle',
            'G': 'dcircle', 'H': 'diamond', 'I': 'hexagon', 'J': 'asym', 'K': 'lean_r', 'L': 'lean_l',
            'M': 'trapezoid', 'N': 'trapezoid_inv'})

    def test_quoted_text_with_br_and_entities(self):
        ch = parse('flowchart TD\n A["x = 1<br/>y #quot;z#quot; #35;"]')
        self.assertEqual(mm.clean_text(ch.nodes['A'].text), ['x = 1', 'y "z" #'])

    def test_later_definition_overrides_text(self):
        ch = parse('flowchart TD\n A --> B\n B{Hỏi}')
        self.assertEqual((ch.nodes['B'].shape, ch.nodes['B'].text), ('diamond', 'Hỏi'))

    def test_highlight_class_marks_nodes(self):
        ch = parse('flowchart TD\n A:::highlight --> B\n class B highlight')
        self.assertIn('highlight', ch.nodes['A'].classes)
        self.assertIn('highlight', ch.nodes['B'].classes)

    def test_other_class_and_style_are_warnings(self):
        ch = parse('flowchart TD\n A --> B\n classDef foo fill:#f00\n style A fill:#f00')
        self.assertFalse(errors(ch))
        self.assertEqual(len([i for i in ch.issues if i.level == 'warning']), 2)


class ParseLinkTest(unittest.TestCase):
    def link(self, text):
        ch = parse('flowchart TD\n' + text)
        self.assertFalse(errors(ch), errors(ch))
        return ch.links

    def test_arrow_kinds(self):
        got = [(l.style, l.start, l.end) for l in self.link(
            'A --> B\nA --- B\nA -.-> B\nA -.- B\nA ==> B\nA <--> B\nA --o B\nA --x B\nA ~~~ B')]
        self.assertEqual(got, [
            ('solid', None, 'arrow'), ('solid', None, None), ('dotted', None, 'arrow'), ('dotted', None, None),
            ('thick', None, 'arrow'), ('solid', 'arrow', 'arrow'), ('solid', None, 'circle'),
            ('solid', None, 'cross'), ('invisible', None, None)])

    def test_label_forms(self):
        got = [l.text for l in self.link(
            'A -- "có" --> B\nA -->|không| B\nA -- chữ trần --> B\nA -. chấm .-> B\nA == đậm ==> B')]
        self.assertEqual(got, ['có', 'không', 'chữ trần', 'chấm', 'đậm'])

    def test_long_arrow_adds_rank_length(self):
        self.assertEqual([l.minlen for l in self.link('A --> B\nA ---> B\nA ----> B\nA -..-> B')], [1, 2, 3, 2])

    def test_chain_and_ampersand_expand_to_every_pair(self):
        pairs = [(l.src, l.dst) for l in self.link('A & B --> C & D --> E')]
        self.assertEqual(pairs, [('A', 'C'), ('A', 'D'), ('B', 'C'), ('B', 'D'), ('C', 'E'), ('D', 'E')])

    def test_semicolon_splits_statements(self):
        self.assertEqual(len(self.link('A --> B; B --> C')), 2)


class ParseStructureTest(unittest.TestCase):
    def test_node_belongs_to_first_closed_subgraph_that_mentions_it(self):
        ch = parse('flowchart TD\n F --> G\n subgraph S[Khung]\n  G --> H\n end\n H --> K')
        self.assertEqual({n.id: n.cluster for n in ch.nodes.values()}, {'F': None, 'G': 'S', 'H': 'S', 'K': None})

    def test_inner_subgraph_claims_before_outer(self):
        ch = parse('flowchart TD\n subgraph O\n  A --> B\n  subgraph I\n   B --> C\n  end\n end')
        self.assertEqual((ch.nodes['A'].cluster, ch.nodes['B'].cluster, ch.nodes['C'].cluster), ('O', 'I', 'I'))
        self.assertEqual(ch.subs['I'].parent, 'O')

    def test_subgraph_title_forms(self):
        ch = parse('flowchart TD\n subgraph a["Tiêu đề A"]\n x\n end\n subgraph b\n y\n end\n'
                   ' subgraph "Có dấu cách"\n z\n end')
        self.assertEqual([(s.id, s.title) for s in ch.subs.values()],
                         [('a', 'Tiêu đề A'), ('b', 'b'), ('subGraph2', 'Có dấu cách')])

    def test_frontmatter_title_and_direction(self):
        ch = parse('---\ntitle: Luồng A\n---\ngraph LR\n A --> B')
        self.assertEqual((ch.title, ch.direction), ('Luồng A', 'LR'))

    def test_errors_carry_line_numbers(self):
        cases = {
            'flowchart XY\n A': 'dòng 1',
            'flowchart TD\n A --> B\n subgraph S\n C': 'dòng 3',
            'flowchart TD\n subgraph S\n A\n end\n B --> S': 'dòng 5',
            'flowchart TD\n A --> B\n A -> B': 'dòng 3',
            'flowchart TD\n end': 'dòng 2',
        }
        for body, loc in cases.items():
            errs = errors(parse(body))
            self.assertTrue(errs, body)
            self.assertEqual(errs[0].loc, loc, body)

    def test_missing_header_is_error(self):
        self.assertTrue(errors(parse('A --> B')))

    def test_markdown_file_uses_first_mermaid_block(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, 'doc.md')
            with open(p, 'w', encoding='utf-8') as f:
                f.write('# Tài liệu\n\nchữ\n\n```mermaid\nflowchart TD\n A --> B -> C\n```\n')
            ch = mm.load(p)
        self.assertEqual(ch.title, 'Tài liệu')
        self.assertEqual(errors(ch)[0].loc, 'dòng 7')


class LayoutTest(unittest.TestCase):
    def test_fixtures_have_no_layout_errors(self):
        for name in FIXTURES:
            _, lay = build(name)
            errs = [m for level, m in lay.check() if level == 'error']
            self.assertEqual(errs, [], name)

    def test_output_is_deterministic(self):
        for name in FIXTURES:
            a = mm.to_drawio(build(name)[1], 't')
            b = mm.to_drawio(build(name)[1], 't')
            self.assertEqual(a, b, name)

    def test_outside_node_is_pushed_beside_cluster(self):
        _, lay = build('payment-link.mmd')
        box = lay.clusters['MSP2'].box
        m = lay.nodes['M'].box()
        self.assertTrue(m[2] <= box[0] or m[0] >= box[2])

    def test_primary_branch_keeps_column(self):
        _, lay = build('payment-link.mmd')
        cols = {lay.nodes[i].col for i in 'GHJLOPQRTUWYZ'}
        self.assertEqual(len(cols), 1)
        self.assertLess(lay.nodes['I'].col, lay.nodes['H'].col)

    def test_nested_cluster_box_inside_parent(self):
        _, lay = build('nested.mmd')
        o, i = lay.clusters['GW'].box, lay.clusters['RISK'].box
        self.assertTrue(o[0] < i[0] and o[1] < i[1] and i[2] < o[2] and i[3] < o[3])

    def test_cycle_edges_are_marked_back(self):
        _, lay = build('loop.mmd')
        back = {(e.src, e.dst) for e in lay.edges if e.back}
        self.assertEqual(back, {('Max', 'Call'), ('Poll', 'Poll')})

    def test_left_to_right_flows_along_x(self):
        _, lay = build('lr.mmd')
        xs = [lay.nodes[i].x for i in ('A', 'B', 'C', 'D', 'E', 'F')]
        self.assertEqual(xs, sorted(xs))
        for e in lay.drawn_edges():
            self.assertLess(e.pts[0][0], e.pts[-1][0] + 0.01)

    def test_labels_are_placed_on_their_edge(self):
        _, lay = build('payment-link.mmd')
        for e in lay.drawn_edges():
            if e.lines:
                self.assertIsNotNone(e.label, e.id)

    def test_slanted_shape_ports_sit_on_outline(self):
        _, lay = build('shapes.mmd')
        e = next(e for e in lay.edges if e.src == 'H')
        h = lay.nodes['H']
        self.assertAlmostEqual(e.pts[0][0], h.x + h.w - mm.SLANT / 2)


class CliTest(unittest.TestCase):
    def test_existing_output_needs_explicit_mode(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, 'x.drawio')
            src = os.path.join(FIX, 'lr.mmd')
            self.assertEqual(mm.main(['build', src, '-o', out]), 0)
            self.assertEqual(mm.main(['build', src, '-o', out]), 4)
            self.assertEqual(mm.main(['build', src, '-o', out, '--mode', 'merge']), 0)
            self.assertEqual(mm.main(['build', src, '-o', out, '--mode', 'force']), 0)
            self.assertTrue(os.path.exists(out + '.bak'))

    def test_syntax_error_exits_1(self):
        with tempfile.TemporaryDirectory() as d:
            src = os.path.join(d, 'bad.mmd')
            with open(src, 'w', encoding='utf-8') as f:
                f.write('flowchart TD\n A -> B\n')
            self.assertEqual(mm.main(['check', src]), 1)
            self.assertEqual(mm.main(['build', src]), 1)


if __name__ == '__main__':
    unittest.main()
