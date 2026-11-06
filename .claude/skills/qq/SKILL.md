---
name: qq
description: Chế độ trả lời nhanh trong một lượt, với hạn mức cố định về tool và độ dài, vượt hạn mức phải xin phép. Chỉ dùng khi user gõ /qq.
disable-model-invocation: true
effort: low
---

# QQ

Mục tiêu: trả lời nhanh nhất có thể để user giữ được mạch suy nghĩ. Tốc độ và sự tập trung quan trọng hơn độ đầy đủ.

Câu hỏi: $ARGUMENTS

Nếu không có câu hỏi kèm theo, áp dụng cho câu hỏi gần nhất của user trong hội thoại.

## Hạn mức

- Tối đa 1 vòng tool, gồm tối đa 3 tool call chạy song song. Không có vòng thứ hai.
- Tối đa 100 từ. Code block cần thiết và dòng xin phép không tính.
- Không dùng subagent.
- Không dùng tool phải nạp qua ToolSearch.
- Không sửa file, không chạy lệnh có tác dụng phụ.

Các hạn mức này là trần, không phải mục tiêu. Nếu trả lời được từ context hiện có thì không gọi tool.

Khi cần tìm trong code, dùng một lần grep có kèm vài dòng ngữ cảnh và đọc song song các file đoán được, vì không có vòng thứ hai để mở kết quả grep.

## Cách trả lời

- Câu đầu tiên là đáp án. Không mở bài, không nhắc lại câu hỏi, không tường thuật đang làm gì.
- Câu hỏi mơ hồ thì không hỏi ngược. Chọn cách hiểu khả dĩ nhất, nêu trong vài chữ rồi trả lời.
- Điều chưa kiểm chứng thì nói rõ, không đoán để lấp chỗ trống.
- Sau đáp án không thêm gì: không gợi ý bước tiếp theo, không hỏi "bạn có muốn...".

## Khi chạm hạn mức

Nếu hạn mức không đủ để trả lời đầy đủ thì dừng lại, không tự gọi thêm tool hay viết dài hơn. Trả lời phần đã biết, rồi kết bằng đúng một dòng nêu việc cần thêm:

Cần đọc thêm 2 file để chắc chắn. y?

Dòng này chỉ xuất hiện khi thật sự thiếu. Câu trả lời đã đủ thì không xin gì.

## Phạm vi

Hạn mức chỉ áp dụng cho câu hỏi đi kèm lệnh /qq này.

- User trả lời y hoặc đồng ý: làm việc đã xin theo chế độ bình thường, không xin lại.
- Mọi tin nhắn khác: coi như bỏ qua lời xin phép, xử lý theo chế độ bình thường.
