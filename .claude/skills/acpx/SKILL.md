---
name: acpx
description: Gọi các agent harness khác (opencode, agy, và mọi agent có ACP) từ Claude Code qua acpx, theo kiểu một lượt hoặc session thường trực có tên giữ ngữ cảnh suốt task, và giao tiếp sức cho harness khác khi quota Claude sắp cạn. Dùng khi user muốn nhờ, hỏi, giao việc cho opencode, agy, gemini, codex hay "model khác", muốn review chéo bởi model khác họ, muốn mở hoặc nói tiếp với một session phản biện/review, hỏi còn bao nhiêu quota, hoặc khi Claude sắp hết quota và cần harness khác làm tiếp.
---

# acpx: dùng harness khác từ Claude

Claude vẫn là người chịu trách nhiệm cuối. Harness khác là đồng nghiệp: kết quả của họ là bằng chứng cần kiểm chứng, không phải kết luận. Việc giao gì cho ai không cố định; đọc [harnesses.md](harnesses.md) để đề xuất, còn user gọi đích danh harness nào thì dùng đúng harness đó.

## Trước khi giao việc

0. Cần có acpx và quota-axi trên PATH; thiếu thì đề nghị user cài:

```sh
npm install -g acpx quota-axi
```

1. Đọc [harnesses.md](harnesses.md): lệnh gọi, model, chi phí, điểm mạnh của từng harness.
2. Xem quota thật, không đoán:

```sh
quota-axi --max-age 5m
```

3. Ghi prompt ra file trong scratchpad, không nhét chuỗi dài vào argv. Prompt phải tự đủ ngữ cảnh: harness khác không có CLAUDE.md, memory hay lịch sử chat của Claude, nên nêu rõ repo, file, mục tiêu, quy ước liên quan và dạng kết quả muốn nhận (vd mỗi nhận định kèm file:line).
4. Chạy bằng run_in_background, timeout rộng; không chặn session của user.

## Một lượt

```sh
acpx --cwd <repo> --approve-reads --format quiet --timeout 900 \
  --model <model> <agent> exec --file <prompt-file>
```

- --approve-reads: chỉ cho đọc. Chỉ dùng --approve-all khi user cho phép harness đó sửa file trong lượt này.
- Nhiều harness trả lời cùng một câu: acpx compare --cwd <repo> --approve-reads --file <prompt-file> <agent1> <agent2>.

## Session thường trực theo task

Dùng khi một vai cần nhớ ngữ cảnh qua nhiều lượt, vd người phản biện suốt task. Session gắn với cwd; đặt tên theo task và vai: <task-slug>-<vai>.

```sh
cd <repo>
acpx <agent> sessions new --name <task>-reviewer
acpx --approve-reads --format quiet --model <model> <agent> -s <task>-reviewer --file <prompt-file>
acpx <agent> sessions history <task>-reviewer   # xem lại
acpx <agent> sessions close <task>-reviewer     # task xong
```

- Ngay sau khi tạo session, nếu đang trong tmux ($TMUX khác rỗng) thì mở pane theo dõi để user quan sát trực tiếp, và đóng pane đó khi đóng session:

```sh
tmux split-window -h -d -c <repo> "acpx <agent> sessions watch -s <task>-<vai>"
```

  Không trong tmux thì báo user lệnh watch ở trên để tự chạy. agy chạy headless nên không có watch; báo conversation_id để user mở lại bằng agy --conversation <id>.
- Người review và người sửa luôn là hai session khác nhau, để người review không bị cuốn theo lập luận của người sửa. Claude thường là người sửa; session harness khác là người review.
- Lượt đầu nạp bối cảnh task (dev-analysis, notes, diff); các lượt sau chỉ gửi phần mới.
- acpx <agent> sessions list để xem session nào đang mở trước khi tạo mới.

## Tiếp sức khi Claude sắp hết quota

Khi quota-axi báo claude runway là projected_exhaustion và còn dưới khoảng 15%, hoặc user yêu cầu:

1. Hỏi user trước khi chuyển: harness nào làm tiếp, có cho sửa file không.
2. Dùng skill handoff để ghi tài liệu bàn giao vào scratchpad.
3. Mở session <task>-relay ở harness được chọn, lượt đầu là: "Đọc <handoff-file> rồi làm tiếp phần việc trong đó".
4. Khi Claude có quota lại: đọc acpx <agent> sessions read <task>-relay và git diff, kiểm chứng toàn bộ thay đổi trước khi nhận tiếp.

## Báo kết quả cho user

- Luôn ghi rõ harness và model đã làm, vd "opencode/deepseek-v4.1-flash-free nói...". Không trình bày kết quả của harness khác như của Claude.
- Đọc lại code tại từng file:line để kiểm chứng; tách mục đã xác nhận, mục sai, mục chưa rõ, và nói rõ đã loại những mục nào vì sao.
- Không tự sửa file theo kết quả của harness khác khi user chưa duyệt.
- Lệnh lỗi hoặc quá timeout: báo nguyên văn lỗi, không tự chạy lại vòng vòng.
- Lưu output thô vào scratchpad và báo đường dẫn.

## Harness không có ACP

Khai lệnh CLI thay thế trong [harnesses.md](harnesses.md) và gọi theo đúng mẫu đó (vd agy). Thêm harness mới: thử một lượt "reply with exactly: OK", rồi bổ sung một mục vào harnesses.md.
