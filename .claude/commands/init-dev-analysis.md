Initialize a new Dev Analysis markdown file by gathering project metadata from the user.

## Instructions

Create a new file task-x-dev-analysis.md in the current working directory with the exact content below.

```markdown
---
product: xxxxx
project: xxxxx
function: xxxxx
description: xxxxx
creator: "LuytBQ"
reviewer: ""
doc_id: xxxxx
doc_title: xxxxx
changes:
  - version: 1
    content: "Tạo mới"
    date: "{today DD/MM}"
---

# I - Mô tả chung

## Mục đích

## Yêu cầu

# II - Dev Analysis

## Hiện trạng

(
  - mô tả hiện trạng của hệ thống liên quan đến vấn đề cần giải quyết, có thể bao gồm các luồng xử lý, các service liên quan, các điểm cần chú ý, v.v.
  - nếu có thể, hãy vẽ sơ đồ để minh họa hiện trạng của hệ thống
  - nếu cách điều tra hiện trạng không phải là quá hiển nhiên, hãy mô tả các bước đã thực hiện để điều tra hiện trạng kèm kết quả các bước
)

## Giải pháp

### Tổng quan
(
  - mô tả giải pháp tổng quan, có thể bao gồm các thay đổi về luồng xử lý, các service liên quan, các điểm cần chú ý, v.v.
  - nếu có thể, hãy vẽ sơ đồ để minh họa giải pháp tổng quan của hệ thống, highlight các điểm thay đổi so với hiện trạng nếu có thể
)

### Chi tiết
(
  - mô tả chi tiết giải pháp, có thể bao gồm các thay đổi về luồng xử lý, các service liên quan, các điểm cần chú ý, v.v.
  - nếu có thể, hãy vẽ sơ đồ để minh họa giải pháp chi tiết của hệ thống, highlight các điểm thay đổi so với hiện trạng nếu có thể
)

## Phạm vi ảnh hưởng

## Kế hoạch deploy
  (cần deploy những service gì, có yêu cầu gì đặc biệt về thứ tự deploy không)

## Monitor sau khi deploy

### Query dữ liệu
Ý nghĩa: kiểm tra hệ thống tạo giao dịch bình thường.
Điều kiện chấp nhận: tất cả các PTTT ảnh hưởng đều có payment thành công kể từ khi deploy.

TODO: viết SQL select payments ở đây

### Check log nginx API
Ý nghĩa: kiểm tra hệ thống tạo giao dịch bình thường.
Điều kiện chấp nhận: 
  - API response status 200|201
  - Nếu có lỗi, trace log để xác định nguyên nhân có liên quan không (lỗi người dùng, lỗi thời điểm của partner)

(
  - viết Graylog filter ở đây, liệt kê các API endpoint cần check
  - có thể dùng phép OR để check vài điều kiện một lúc hoặc tách ra thành nhiều filter riêng biệt nếu cần thiết
  - ví dụ: message:"/v1/payments" OR "/v1/refunds"
)

### Check log service các luồng ảnh hưởng
Ý nghĩa: kiểm tra hệ thống tạo giao dịch bình thường.
Điều kiện chấp nhận: 
  - Không log lỗi khi xử lý giao dịch
  - Nếu có lỗi, trace log để xác định nguyên nhân có liên quan không (lỗi người dùng, lỗi thời điểm của partner)

(
  - viết Graylog filter ở đây, liệt kê các service và các class/method cần check
  - đọc code để xác định các điều kiện của filter
  - mức độ chi tiết của filter phụ thuộc vào code, có thể check ở mức service hoặc class/method nếu cần thiết
  - có thể dùng phép OR để check vài điều kiện một lúc hoặc tách ra thành nhiều filter riêng biệt nếu cần thiết
  - ví dụ: log_service:msp AND log_class=vn.onepay.msp.resources.applepay.ApplePayments
)

### Check log service của tính năng mới deploy
Ý nghĩa: kiểm tra tính năng mới có hoạt động không
Điều kiện chấp nhận: 
  - (viết điều kiện chấp nhận cụ thể ở đây, ví dụ: có log thông báo start chạy tính năng, log cho thấy tính năng chạy thành công, không có log cho thấy lỗi liên quan đến tính năng mới)

(
  - viết Graylog filter ở đây, liệt kê các service và các class/method cần check
  - đọc code để xác định các điều kiện của filter
  - cần có đầy đủ điều kiện để xác định log liên quan đến tính năng mới, nếu trong code chưa có log phù hợp thì cần thêm log để phục vụ việc monitor sau này
  - có thể dùng phép OR để check vài điều kiện một lúc hoặc tách ra thành nhiều filter riêng biệt nếu cần thiết
  - ví dụ: log_service:msp AND message:"updatePaymentSDataPromotion" 
)

## Service Monitoring
  N/A

## Network Monitoring
  N/A

## Security
  N/A

## Audit Log
  N/A

```
