import os
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import flowtable2drawio as ft  # noqa: E402
import mermaid2drawio as mm  # noqa: E402

FIX = os.path.join(HERE, 'fixtures', 'mermaid')
FIXTURES = ['payment-link.mmd', 'shapes.mmd', 'loop.mmd', 'nested.mmd', 'lr.mmd']

BASE = '''flowchart TD
    A[Bắt đầu] --> B[Kiểm tra]
    subgraph S1[Khung một]
        B --> C{Hợp lệ?}
        C -->|có| D[Xử lý]
    end
    subgraph S2[Khung hai]
        E[Lưu]
    end
    C -->|không| X[Trả lỗi]
    D --> E
    E --> F[Kết thúc]
'''


class MergeCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.src = os.path.join(self.tmp.name, 'flow.mmd')
        self.out = os.path.join(self.tmp.name, 'flow.drawio')

    def tearDown(self):
        self.tmp.cleanup()

    def write_src(self, text):
        with open(self.src, 'w', encoding='utf-8') as f:
            f.write(text)

    def build(self, *extra):
        return mm.main(['build', self.src, '-o', self.out, '--no-backup', *extra])

    def tree(self):
        return ET.parse(self.out)

    def cells(self):
        return {c.get('id'): c for c in self.tree().iter('mxCell')}

    def abs_box(self, cid):
        x, y, w, h = ft.read_drawio(self.out).abs_box(cid)
        return x, y, x + w, y + h

    def edit(self, fn):
        t = self.tree()
        fn({c.get('id'): c for c in t.iter('mxCell')}, t.getroot().find('.//root'))
        t.write(self.out, encoding='unicode')

    def merge(self, text=None):
        if text is not None:
            self.write_src(text)
        chart = mm.load(self.src)
        lay = mm.Layout(chart).run()
        extras, pages, rep = mm.merge_into(lay, ft.read_drawio(self.out))
        with open(self.out, 'w', encoding='utf-8') as f:
            f.write(mm.to_drawio(lay, chart.title, extras, pages))
        return lay, rep


class IdempotentTest(unittest.TestCase):
    def test_merge_without_changes_rewrites_same_file(self):
        with tempfile.TemporaryDirectory() as d:
            for name in FIXTURES:
                out = os.path.join(d, name + '.drawio')
                src = os.path.join(FIX, name)
                self.assertEqual(mm.main(['build', src, '-o', out]), 0)
                with open(out, encoding='utf-8') as f:
                    first = f.read()
                self.assertEqual(mm.main(['build', src, '-o', out, '--mode', 'merge', '--no-backup']), 0)
                with open(out, encoding='utf-8') as f:
                    self.assertEqual(f.read(), first, name)


class MergeTest(MergeCase):
    def setUp(self):
        super().setUp()
        self.write_src(BASE)
        self.assertEqual(self.build(), 0)

    def move(self, cid, dx, dy):
        def fn(cells, _root):
            g = cells[cid].find('mxGeometry')
            g.set('x', str(float(g.get('x')) + dx))
            g.set('y', str(float(g.get('y')) + dy))
        self.edit(fn)

    def test_dragged_node_keeps_position(self):
        before = self.abs_box('X')
        self.move('X', 60, 30)
        _, rep = self.merge()
        after = self.abs_box('X')
        self.assertAlmostEqual(after[0], before[0] + 60)
        self.assertAlmostEqual(after[1], before[1] + 30)
        self.assertIn('X', rep.pinned)

    def test_edge_to_dragged_node_drops_computed_label(self):
        self.move('X', 60, 30)
        _, rep = self.merge()
        self.assertIn('L-C-X-0', rep.labels_centered)
        g = self.cells()['L-C-X-0'].find('mxGeometry')
        self.assertIsNone(g.get('x'))

    def test_new_node_is_placed_below_its_source_and_edges_rerouted(self):
        _, rep = self.merge(BASE + '    F --> G[Gửi thông báo]\n')
        self.assertEqual(rep.placed, ['G'])
        self.assertEqual(rep.rerouted, ['L-F-G-0'])
        f, g = self.abs_box('F'), self.abs_box('G')
        self.assertGreater(g[1], f[3])
        style = self.cells()['L-F-G-0'].get('style')
        self.assertNotIn('exitX', style)

    def test_inserting_an_edge_elsewhere_keeps_other_edge_ids(self):
        _, rep = self.merge(BASE.replace('    A[Bắt đầu] --> B[Kiểm tra]\n',
                                         '    A[Bắt đầu] --> B[Kiểm tra]\n    A --> F\n'))
        self.assertIn('L-D-E-0', rep.kept_edges)
        self.assertEqual(rep.rerouted, ['L-A-F-0'])

    def test_removed_node_and_its_edges_disappear(self):
        _, rep = self.merge(BASE.replace('    C -->|không| X[Trả lỗi]\n', ''))
        self.assertIn('X', rep.removed)
        self.assertIn('L-C-X-0', rep.removed)
        self.assertNotIn('X', self.cells())

    def test_node_moved_to_another_existing_subgraph_is_replaced(self):
        # D thuộc subgraph đóng sớm nhất có nhắc tới nó, nên phải chuyển hẳn câu nhắc sang S2.
        text = BASE.replace('        C -->|có| D[Xử lý]\n', '').replace(
            '        E[Lưu]\n', '        E[Lưu]\n        C -->|có| D[Xử lý]\n')
        lay, rep = self.merge(text)
        self.assertIn('D', rep.cluster_changed)
        self.assertEqual(self.cells()['D'].get('parent'), 'S2')
        box, d = lay.clusters['S2'].box, lay.nodes['D'].box()
        self.assertTrue(box[0] <= d[0] and box[1] <= d[1] and d[2] <= box[2] and d[3] <= box[3])

    def test_new_subgraph_wraps_nodes_without_moving_them(self):
        before = self.abs_box('F')
        text = BASE.replace('    E --> F[Kết thúc]\n', '    subgraph S3[Khung ba]\n        E --> F[Kết thúc]\n    end\n')
        text = text.replace('        E[Lưu]\n', '        E[Lưu]\n        E\n')
        lay, rep = self.merge(text)
        self.assertIn('F', rep.pinned)
        self.assertEqual(self.abs_box('F'), before)
        box = lay.clusters['S3'].box
        self.assertTrue(box[0] < before[0] and box[1] < before[1] and before[2] < box[2] and before[3] < box[3])

    def test_cluster_grows_to_fit_member_moved_outside(self):
        old = self.abs_box('S1')
        self.move('D', 0, 400)
        _, rep = self.merge()
        self.assertIn('S1', rep.clusters_grown)
        new = self.abs_box('S1')
        self.assertGreater(new[3], old[3])
        self.assertEqual(new[:2], old[:2])

    def test_freehand_cells_are_kept_and_follow_their_parent(self):
        def fn(cells, root):
            note = ET.SubElement(root, 'mxCell', id='note1', value='ghi chú', vertex='1', parent='S1',
                                 style='text;html=1;')
            ET.SubElement(note, 'mxGeometry', x='5', y='5', width='60', height='20', **{'as': 'geometry'})
            link = ET.SubElement(root, 'mxCell', id='link1', edge='1', parent='1', source='note1', target='X',
                                 style='endArrow=classic;')
            ET.SubElement(link, 'mxGeometry', relative='1', **{'as': 'geometry'})
        self.edit(fn)
        note_before = self.abs_box('note1')
        _, rep = self.merge(BASE.replace('    C -->|không| X[Trả lỗi]\n', ''))
        self.assertEqual(rep.freehand_kept, ['note1', 'link1'])
        self.assertEqual(rep.freehand_detached, ['link1.target'])
        cells = self.cells()
        self.assertEqual(cells['note1'].get('parent'), 'S1')
        self.assertEqual(self.abs_box('note1'), note_before)
        self.assertIsNone(cells['link1'].get('target'))

    def test_freehand_child_of_removed_node_moves_to_layer(self):
        def fn(cells, root):
            tag = ET.SubElement(root, 'mxCell', id='tag1', value='!', vertex='1', parent='X', style='text;html=1;')
            ET.SubElement(tag, 'mxGeometry', x='2', y='3', width='20', height='20', **{'as': 'geometry'})
        self.edit(fn)
        before = self.abs_box('tag1')
        _, rep = self.merge(BASE.replace('    C -->|không| X[Trả lỗi]\n', ''))
        self.assertEqual(rep.freehand_moved, ['tag1'])
        self.assertEqual(self.cells()['tag1'].get('parent'), '1')
        self.assertEqual(self.abs_box('tag1'), before)

    def test_file_not_generated_by_tool_is_refused(self):
        with open(self.out, 'w', encoding='utf-8') as f:
            f.write('<mxfile><diagram><mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"/>'
                    '<mxCell id="A" vertex="1" parent="1"><mxGeometry x="0" y="0" width="10" height="10" '
                    'as="geometry"/></mxCell></root></mxGraphModel></diagram></mxfile>')
        self.assertEqual(self.build('--mode', 'merge'), 4)

    def test_other_pages_are_kept(self):
        def fn(_cells, _root):
            pass
        t = self.tree()
        page = ET.SubElement(t.getroot(), 'diagram', id='p2', name='Trang hai')
        ET.SubElement(page, 'mxGraphModel')
        t.write(self.out, encoding='unicode')
        self.merge()
        names = [d.get('name') for d in self.tree().getroot().findall('diagram')]
        self.assertEqual(names[1:], ['Trang hai'])

    def test_cli_merge_prints_report_and_writes_backup(self):
        self.assertEqual(mm.main(['build', self.src, '-o', self.out, '--mode', 'merge']), 0)
        self.assertTrue(os.path.exists(self.out + '.bak'))


if __name__ == '__main__':
    unittest.main()
