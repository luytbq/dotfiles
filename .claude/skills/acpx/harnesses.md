# Hồ sơ harness

File này do user tự sửa. Claude đọc để đề xuất; mục "Mạnh ở" chỉ là gợi ý, không phải luật. Khi kết quả thực tế cho thấy một nhận định ở đây sai, đề xuất user sửa file.

## Cài trên máy mới

- Node 22 trở lên, rồi npm install -g acpx quota-axi.
- opencode bản 1.18 trở lên (model free cần bản này). ~/.acpx/config.json trỏ thẳng tới "opencode acp": chưa cài opencode thì acpx báo lỗi, không tự chạy qua npx.
- agy: cài và đăng nhập Google. Trên Linux adapter antigravity của acpx không chạy (thiếu agy_acp_server.par); macOS chưa kiểm tra, thử acpx antigravity exec "reply with exactly: OK" trước khi dùng CLI thay thế.
- tmux: tùy chọn, chỉ để mở pane watch.

## opencode

- Gọi qua acpx: agent opencode. Có session thường trực.
- Model:
  - opencode/deepseek-v4.1-flash-free: free, mặc định cho việc rõ ràng, nhiều lượt.
  - Các model free khác: opencode models | grep free.
  - github-copilot/gpt-6.1-sol và các model github-copilot/*: tốn quota Copilot, dùng khi cần chất lượng cao hơn.
- Mạnh ở: review chéo bởi model khác họ Claude, tìm bug, phản biện.
- Ngữ cảnh: opencode nạp CLAUDE.md global, ~/.claude/skills, ~/.claude/rules; cấu hình riêng theo workspace (nếu có) nằm ở wrapper ~/.local/bin/opencode. Không có hooks của Claude. acpx gọi opencode cài sẵn nhờ ~/.acpx/config.json; xóa file đó thì acpx quay về npx opencode-ai và mất các cấu hình này.
- Lưu ý: lượt đầu nạp khoảng 50k token system prompt; session giữ cache nên các lượt sau rẻ. Model free cần opencode từ 1.18 trở lên.

## agy (Antigravity CLI)

- Trên Linux không chạy được qua acpx (adapter antigravity cần agy_acp_server.par, bản Linux không có). Gọi CLI trực tiếp:

```sh
cd <repo> && agy --output-format json --print-timeout 900s -p "$(cat <prompt-file>)"
# lượt tiếp theo cùng hội thoại: thêm --conversation <conversation_id lấy từ JSON lượt trước>
```

- Headless tự từ chối tool cần quyền command; không dùng --dangerously-skip-permissions khi user chưa cho phép.
- Quota: quota-axi --provider agy. Scope gemini là free tier; scope claude_gpt thường đã cạn.
- Mạnh ở: đọc nhiều, ngữ cảnh dài, ý kiến thứ hai từ họ Gemini.

## claude (qua acpx)

- Tài khoản Pro, quota hiếm. Chỉ gọi qua acpx khi cần một phiên Claude độc lập (vd người review không thấy lập luận của phiên chính).
