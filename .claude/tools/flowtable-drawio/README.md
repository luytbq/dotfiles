# flowtable2drawio

Chuyển một Flow Table (định dạng mô tả ở flow-table-format.md cạnh file này) thành file draw.io kiểu activity-swimlane: mỗi lane là một cột dọc, luồng đi từ trên xuống. Bảng viết trong .md, .csv hoặc .xlsx đều được.

Tool chỉ dùng thư viện chuẩn của Python 3.10+. Mọi toạ độ đều do code tính và kết quả tất định, nên cùng một bảng luôn ra cùng một file. AI hay người dùng không cần, và không nên, sửa toạ độ trong XML bằng tay. Subagent flowtable-drawio (~/.claude/agents/flowtable-drawio.md) gọi tool này.

## Cách chạy

```
python3 ~/.claude/tools/flowtable-drawio/flowtable2drawio.py check  <file> [--sheet TÊN] [--delimiter ,] [--encoding utf-8]
python3 ~/.claude/tools/flowtable-drawio/flowtable2drawio.py build  <file> [-o out.drawio] [--mode merge|force] [--png [out.png]] [--verify] [--layout-json out.json] [--title "..."] [--no-backup] [--sheet TÊN] [--delimiter ,] [--encoding utf-8]
```

- check: kiểm tra bảng theo mục "Kiểm tra một bảng có hợp lệ không" của định dạng.
- build: chạy check trước, bảng có lỗi thì dừng. Nếu không có lỗi, tool dựng layout, ghi file .drawio rồi tự kiểm hình học. Đường ra mặc định nằm cạnh file nguồn, cùng tên, đuôi .drawio.
- --png: xuất ảnh bằng drawio CLI (scale 2), mặc định cạnh file .drawio.
- --verify: xuất SVG bằng drawio CLI rồi so từng đường dây draw.io vẽ ra với toạ độ đã tính. Bước này bắt trường hợp draw.io tự đi lại đường khác waypoint.
- --mode: bắt buộc khi file đích đã tồn tại, xem mục Generate lại bên dưới.
- --no-backup: không tạo file .drawio.bak trước khi ghi đè.
- --sheet, --delimiter, --encoding: chỉ dùng cho xlsx và csv, xem mục Định dạng đầu vào bên dưới.
- Tool đọc bảng đầu tiên có header id | type | parent | content | metadata.

Exit code:

| code | ý nghĩa |
|---|---|
| 0 | ổn (có thể vẫn có cảnh báo) |
| 1 | bảng có lỗi, không vẽ |
| 2 | layout tự kiểm có lỗi (dây cắt node, hai dây chồng nhau, node chồng nhau) |
| 3 | ảnh render lệch toạ độ, hoặc drawio CLI lỗi |
| 4 | file đích đã tồn tại mà chưa chọn chế độ, hoặc không đọc được file đích |

Các dòng in ra có dạng ERROR/WARNING kèm số dòng và id trong bảng, hoặc kèm tiền tố layout: / render:.

## Định dạng đầu vào

Thiết kế đầy đủ: docs/input-formats-design.md.

.md, .csv và .xlsx là ba nguồn ngang hàng: build đọc thẳng, không có bước chuyển đổi trung gian, và cùng một nội dung bảng thì ba định dạng cho ra file .drawio giống hệt nhau.

Chung cho cả ba:
- Hàng header là hàng đầu tiên có đủ 5 tên cột id, type, parent, content, metadata.
- Tiêu đề sơ đồ lấy theo thứ tự: cờ --title, heading # đầu tiên (md) hoặc ô không rỗng đầu tiên phía trên header (csv, xlsx), cuối cùng là tên file bỏ đuôi.

Riêng csv và xlsx:
- Mọi hàng phía trên header bị bỏ qua, nên đầu file được phép có tiêu đề và ghi chú. Bảng kết thúc ở hàng đầu tiên có cả 5 ô đều rỗng, nên phía dưới cũng ghi chú được. Cột thừa bên phải bị bỏ qua.
- Xuống dòng trong ô: nhận cả xuống dòng thật lẫn thẻ br. Gạch đứng là ký tự thường. Không xử lý escape kiểu markdown, và tool cảnh báo khi thấy gạch chéo ngược kèm gạch đứng vì đó thường là dán từ md sang mà chưa dọn.

csv:
- Dấu phân cách tự đoán trong dấu phẩy, chấm phẩy, tab; bảng mã thử utf-8-sig, utf-8, rồi cp1252. Phải lùi về cp1252 thì tool cảnh báo.
- Đoán sai thì ghi đè bằng --delimiter và --encoding.

xlsx:
- Lấy sheet đầu tiên có hàng header, hoặc sheet chỉ định bằng --sheet. Tên sheet đã dùng được in ra và mọi lỗi đều ghi kèm tên sheet.
- Ô công thức lấy giá trị đã lưu trong file; chưa có giá trị thì đọc thành rỗng và cảnh báo.
- Cảnh báo với hàng ẩn trong vùng bảng, ô gộp trong vùng bảng, và ô kiểu số ở cột id hoặc parent (id dạng 4.10 bị Excel đổi thành 4.1, nên để cột đó là Text).

## Cách tool xếp hình

1. Xếp hàng: tool duyệt theo thứ tự topo, cùng mức thì ưu tiên thứ tự dòng trong bảng, và bỏ qua cạnh back=true. Đích chỉ có một nguồn thì được đặt cùng hàng với nguồn để mũi tên đi ngang, miễn là các ô trên đường đi còn trống; điều này áp dụng cho cả đích khác lane lẫn nhánh phụ cùng lane, nên một nhánh phụ không bắt buộc phải tụt xuống dưới node đã rẽ ra nó. Riêng condition có từ 2 nhánh phụ trở lên thì không nhận mũi tên ngang.
   Node có nhiều nhánh cùng lane đi vào thì quay về cột của node rẽ gần nhất mà mọi nhánh đều đi qua, thay vì bám theo cột của nhánh được xếp sau cùng. Nhờ vậy luồng chung sau khi hợp nhánh nằm thẳng cột với chỗ đã rẽ ra. Không có node rẽ chung thì giữ cách cũ.
2. Cột con: cạnh ra cuối cùng của một node được coi là nhánh chính và giữ nguyên cột. Mỗi nhánh phụ được đặt về phía lane mà nhánh đó rốt cuộc dẫn tới: tool đi dọc nhánh tới cạnh đầu tiên rời khỏi lane, và dừng ở node hợp nhánh vì từ đó là luồng chung. Nhờ vậy một nhánh chỉ để trả lỗi về lane bên trái sẽ nằm bên trái, mũi tên ra khỏi nó không phải vòng ngược qua các node khác. Nhánh không rời lane thì không rõ hướng, và các nhánh như vậy lần lượt sang phải rồi sang trái. Nếu một mặt đã có mũi tên ngang thì mọi nhánh phụ dồn sang mặt còn lại. Condition có từ 2 nhánh phụ trở lên thì không nhận mũi tên ngang, để giữ cả hai mặt bên cho các nhánh.
3. db và text đứng cùng hàng với node được attach, về phía không có cạnh nối, và bám sát node đó đúng --attach-gap. Ô sát bên được ưu tiên hơn phía thuận: mặt thuận đã kín thì tool lấy ô sát bên mặt kia trước khi lùi ra xa. Mặt đang đỡ một db hoặc text không được dùng làm cổng ra, nên cạnh đi ra sẽ chọn mặt khác hoặc đi xuống đáy; nhờ vậy không có đoạn dây nào cắt qua chỗ đã chừa. Máng bên cạnh được nới thêm đúng phần chừa đó, và dây chạy ở phía ngoài. Khi mặt đó đã có dây ngang không tránh được, hoặc node có nhiều hơn một db/text cùng phía, thì phần tử không bám sát được và quay về cách cũ là căn giữa ô bên cạnh.
4. Đi dây: có 4 kiểu.
   - A: thẳng đứng.
   - B: thẳng ngang.
   - C: hình chữ L, ra từ mặt bên rồi đi xuống đỉnh node đích.
   - D: tổng quát, đi qua kênh ngang giữa các hàng và máng dọc giữa các cột.
   Mỗi kênh hoặc máng được chia thành nhiều track, gán theo thuật toán tô màu khoảng. Các cạnh cùng đích được dùng chung track, nên chúng gộp thành một đường chung.
5. Nhãn cạnh: tool thử các vị trí dọc theo đường dây, gần nguồn trước, và chọn chỗ đầu tiên không đè node, nhãn khác, dây khác, header hay biên lane. Kênh và máng được chừa thêm chỗ cho nhãn.
6. Chữ trong node được đo bằng độ rộng glyph thật của Verdana.ttf và ngắt dòng sẵn sao cho các dòng dài xấp xỉ nhau. Vì vậy style của node không bật whiteSpace=wrap: nếu bật, draw.io có thể ngắt ra số dòng khác với kích thước node đã tính. Không có font thì tool dùng độ rộng ước lượng và in cảnh báo.

## Generate lại khi file .drawio đã có

Thiết kế đầy đủ: docs/merge-design.md.

File đích đã tồn tại thì tool không tự ghi đè. Chạy trong terminal, tool hỏi chọn merge hay force. Chạy không có terminal (agent gọi), tool dừng với exit code 4 và yêu cầu truyền --mode. Trước khi ghi đè, tool chép file cũ thành <file>.drawio.bak.

force sinh lại toàn bộ, bỏ mọi chỉnh sửa tay.

merge giữ lại từ file hiện có, đối chiếu theo id:
- vị trí element (neo theo tâm; kích thước vẫn tính lại theo chữ);
- vị trí và bề rộng lane; lane chỉ được nới khi có element không vừa, khi đó các lane bên phải dịch sang;
- waypoint và điểm neo của edge, với điều kiện hai đầu edge đều là element cũ và from/to không đổi;
- cell người dùng tự vẽ (không mang dấu flowtable=1 trong style), kể cả chữ và style của chúng.

Sinh lại từ bảng: chữ, style, loại hình, lane chứa phần tử, thêm hoặc xoá element và edge.

Những chỗ cần chỉnh tay sau khi merge đều được liệt kê trong báo cáo:
- element mới, và element mới phải dịch xuống vì chồng chỗ;
- edge nối tới element mới hoặc đã đổi from/to: draw.io tự đi dây nên có thể cắt qua node;
- edge đã sửa tay: nhãn về giữa đường;
- cell tự vẽ bị mất đầu nối vì node kia đã bị xoá khỏi bảng.

Ở chế độ merge, tool không tự kiểm dây và nhãn, cũng không kiểm render, vì đường dây lúc này đến từ file cũ hoặc do draw.io tự đi.

## Tham số layout

Mọi trường của Config đều có cờ CLI tương ứng, ví dụ --track-gap 14 hay --task-max-w 280. Tất cả nhận số nguyên (px).

| cờ | mặc định | tác dụng |
|---|---|---|
| --task-min-w / --task-max-w | 120 / 240 | bề rộng hộp task |
| --cond-wrap | 150 | bề rộng ngắt dòng trong hình thoi |
| --term-wrap | 170 | ngắt dòng start/end/external |
| --db-wrap / --text-wrap | 130 / 260 | ngắt dòng db / ghi chú |
| --label-wrap | 180 | ngắt dòng nhãn cạnh |
| --track-gap | 12 | khoảng cách giữa hai track |
| --gutter-margin / --channel-margin | 15 / 12 | lề từ mép máng/kênh tới track đầu |
| --min-gutter / --min-channel | 24 / 30 | khoảng trống tối thiểu giữa hai cột / hai hàng |
| --attach-gap | 40 | khoảng cách từ db/text tới node nó attach |

## Giới hạn đã biết

- Mới hỗ trợ kiểu activity-swimlane dọc.
- Hình thoi và elip chỉ nối dây ở 4 điểm giữa cạnh. Condition có nhiều nhánh ra hơn số mặt còn trống thì các nhánh dùng chung một điểm ra rồi mới tách.
- Nếu cả hai mặt của node đều có cạnh sang lane khác, db/text được đặt bên phải. Khi đó cạnh ra bên phải phải đi vòng qua kênh.
- Nhánh kết thúc sớm có thể tạo một đường chung dài chạy dọc lane. Tool coi đó là chấp nhận được, không tự đổi cách xếp.

## mermaid2drawio: Mermaid flowchart

mermaid2drawio.py dựng file draw.io từ một Mermaid flowchart, theo cùng nguyên tắc: mọi toạ độ do code tính, kết quả tất định, có tự kiểm hình học và --verify. Khác flowtable2drawio ở chỗ không có lane: subgraph được vẽ thành khung bao lấy các node của nó, giống cách mermaid hiển thị. Phần đo chữ, hình học, xuất ảnh và kiểm render được import từ flowtable2drawio.py.

```
python3 ~/.claude/tools/flowtable-drawio/mermaid2drawio.py check <file.mmd|file.md>
python3 ~/.claude/tools/flowtable-drawio/mermaid2drawio.py build <file.mmd|file.md> [-o out.drawio] [--mode merge|force] [--png [out.png]] [--verify] [--layout-json out.json] [--title "..."] [--no-backup]
```

- Đầu vào: file .mmd, hoặc khối mermaid đầu tiên trong file .md. Số dòng trong thông báo lỗi là số dòng của file gốc.
- Tiêu đề trang lấy theo thứ tự: --title, title trong frontmatter mermaid, heading # đứng trước khối (md), tên file.
- Exit code giống flowtable2drawio. File đích đã có thì phải chọn --mode merge hoặc --mode force như tool cũ, file cũ được chép ra .bak (tắt bằng --no-backup).

Cú pháp đọc được:
- Header flowchart hoặc graph với hướng TD, TB, BT, LR, RL.
- Mọi hình node cơ bản: [], (), ([]), [[]], [()], (()), ((())), {}, {{}}, >], [//], [\\], [/\], [\/]. Chữ có nháy hoặc không, br thành xuống dòng, entity dạng #quot; và #35;.
- Mũi tên -->, ---, -.->, -.-, ==>, ===, <-->, --o, --x, ~~~ (cạnh ẩn, chỉ ảnh hưởng xếp hàng), mũi tên dài hơn (--->) làm đích xuống thêm hàng. Nhãn dạng -- "x" -->, -->|x|, -. x .->, == x ==>. Chuỗi A --> B --> C và A & B --> C & D.
- subgraph id[tiêu đề], subgraph id, subgraph "tiêu đề", lồng nhau.
- class tên highlight (hoặc :::highlight) tô màu nhấn. classDef, style, linkStyle, click, direction trong subgraph: bỏ qua kèm cảnh báo.

Chưa hỗ trợ, báo lỗi: nối cạnh vào id của subgraph, cú pháp node mới dạng A@{ shape: ... }.

Một node thuộc subgraph nào theo đúng quy tắc của mermaid: subgraph đóng sớm nhất có nhắc tới node đó. Nhắc tới node ở ngoài mọi subgraph không giữ node lại ở ngoài. Ví dụ `F --> G` viết ở ngoài, sau đó `G --> H` viết trong subgraph S, thì G thuộc S.

Cách tool xếp hình (tính theo chiều TB; LR, RL, BT thì xoay hoặc lật ở bước cuối):
1. Cạnh tạo vòng được đánh dấu back bằng DFS theo thứ tự viết. Hàng tính theo đường dài nhất; node nguồn phụ được kéo xuống sát đích.
2. Nhánh chính của một node là đích có đường đi xuôi dài nhất, hoà thì lấy cạnh viết sau. Nhánh chính giữ cột. Nhánh viết trước nhánh chính đứng bên trái, nhánh viết sau đứng bên phải.
3. Mỗi subgraph được xếp cục bộ thành một hình chữ nhật ô rồi đặt vào cha như một khối liền. Mọi ô của hình này đều coi như đã có chủ, nên node ngoài cùng hàng bị đẩy sang bên cạnh khung chứ không lọt vào trong.
4. Máng giữa hai cột và kênh giữa hai hàng chia slot cho viền khung, băng tiêu đề, dải nhãn và track đi dây. Track của một cạnh nằm trong vùng thuộc subgraph chung thấp nhất của hai đầu, nên dây nội bộ không lòi ra ngoài khung.
5. Đi dây: A thẳng đứng; C chữ L ra mặt bên rồi xuống đỉnh đích; Z qua một kênh; D qua kênh, máng, kênh; B (cạnh back và tự nối) ra đáy, lên máng bên phải, vào đỉnh. Cạnh cùng nguồn hoặc cùng đích dùng chung track để gộp đường.
6. Nhãn cạnh đặt trên đoạn dọc cuối, ngay trên node đích và dưới mọi track của kênh đó, vì đoạn phía trên thường là dây chung của nhiều nhánh. Vị trí nào nằm trên dây chung với cạnh khác bị phạt, nên nhãn tự dời sang phần dây riêng nếu còn chỗ.
7. Tiêu đề khung thử căn trái, phải rồi giữa, lấy chỗ đầu tiên không bị dây cắt. Khung được nới khi tiêu đề dài hơn nội dung.
8. Hình có cạnh xiên (hình bình hành, hình thang, cờ) có cổng trái phải lùi vào đúng chỗ đường viền, và edge dùng exitPerimeter=0 để draw.io không tự chiếu lại điểm nối.

Generate lại với --mode merge giữ từ file hiện có, đối chiếu theo id cell:
- vị trí node (neo theo tâm; kích thước vẫn tính lại theo chữ);
- khung subgraph: giữ vị trí và kích thước cũ, chỉ nới ra khi nội dung không vừa; subgraph mới được dựng bao quanh node của nó mà không dời node;
- waypoint và điểm neo của edge, khi cả hai node đầu mút đều được giữ vị trí;
- cell tự vẽ (không mang dấu mermaid2drawio=1 trong style): chép nguyên, đi theo cha nếu cha còn; cha là node hoặc khung đã bị xoá thì chuyển ra ngoài, giữ vị trí tuyệt đối; edge tự vẽ nối vào node đã xoá thì mất đầu nối đó;
- các trang khác của file.

Id của node và subgraph là id trong mermaid. Id của edge là L-nguồn-đích-số, với số là lần xuất hiện thứ mấy của cặp nguồn-đích đó, nên thêm hay bớt cạnh ở chỗ khác không làm đổi id. Node đang nằm trong một khung còn tồn tại mà nay thuộc chỗ khác thì được đặt lại như node mới. Node mới lấy láng giềng đã giữ làm mốc, lệch đúng như trong layout mới tính, chồng thì dịch xuống. Edge nối tới node mới hoặc node được đặt lại thì để draw.io tự đi dây. Edge mà đường dây hoặc node đầu mút đã bị sửa tay thì nhãn về giữa đường. Mọi chỗ cần chỉnh tay đều được in trong báo cáo merge:. Merge lại một sơ đồ không đổi cho ra đúng file cũ. Ở chế độ merge, tool không tự kiểm dây, nhãn và render; file không do mermaid2drawio sinh thì bị từ chối với exit code 4.

Tham số layout có cờ CLI như tool cũ (--task-max-w, --track-gap, --min-gutter, --min-channel, --cluster-pad, --title-wrap, ...); chạy build --help để xem đủ.

Giới hạn đã biết:
- Nhiều cạnh có nhãn cùng đi vào một node thì các nhãn dễ chen nhau trên đoạn dây chung; tool cảnh báo khi không tìm được chỗ trống.
- direction riêng trong subgraph bị bỏ qua.

## Test

```
cd ~/.claude/tools/flowtable-drawio && python3 -m unittest discover -s tests
```

Fixtures nằm trong tests/fixtures:
- order.md: ví dụ trong tài liệu định dạng.
- retry.md: có cạnh back, condition 3 nhánh và mục "Phần còn lại".
- crowded-condition.md: condition hết mặt trống (mặt trái nhận dây ngang vào, mặt phải đỡ ghi chú, mặt dưới đã có nhánh), nhánh còn lại phải dùng chung cổng dưới chứ không ra ở mặt có dây vào.
- mermaid/*.mmd: fixture của mermaid2drawio (luồng link thanh toán có 3 subgraph, đủ các hình và kiểu mũi tên theo hướng LR, vòng lặp và tự nối, subgraph lồng, LR có subgraph).

test_merge_mermaid.py dựng lại các tình huống merge của mermaid2drawio: merge không đổi ra đúng file cũ, kéo node, thêm/xoá node, chèn cạnh không làm đổi id cạnh khác, chuyển node sang subgraph khác, subgraph mới bao node cũ, khung nới ra, cell tự vẽ, file không do tool sinh, trang phụ. test_mermaid2drawio.py kiểm parser mermaid (hình, mũi tên, nhãn, subgraph, lỗi kèm số dòng), layout (không lỗi tự kiểm, tất định, node ngoài không lọt vào khung, nhánh chính giữ cột, cạnh back) và CLI. test_flowtable2drawio.py kiểm parse, validate, layout và đi dây. test_merge.py dựng lại các tình huống generate lại: kéo node, thêm điểm gấp, thêm ghi chú tay, chèn và xoá dòng trong bảng, thêm lane, đổi lane của node, file drawio nén, file nhiều trang. test_inputs.py kiểm đọc csv và xlsx, gồm cả bảng mã, dấu phân cách, ô gộp, hàng ẩn, ô công thức, và khẳng định md, csv, xlsx cho ra cùng một file. Helper xlsx_fixture.py sinh file .xlsx ngay trong test, không cần thư viện ngoài.
