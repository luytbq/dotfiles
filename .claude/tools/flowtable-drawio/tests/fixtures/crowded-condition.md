# Condition hết mặt trống

| id | type | parent | content | metadata |
|---|---|---|---|---|
| MSP | lane | | MSP | |
| MSP-1 | start | MSP | Bắt đầu | |
| E1 | edge | | | from=MSP-1; to=MSP-46 |
| MSP-46 | condition | MSP | state mới | |
| E2 | edge | | approved | from=MSP-46; to=MSP-47 |
| E3 | edge | | failed | from=MSP-46; to=MSP-48 |
| E4 | edge | | canceled | from=MSP-46; to=MSP-50 |
| MSP-47 | task | MSP | Invoice paid | |
| E5 | edge | | | from=MSP-47; to=MSP-53 |
| MSP-48 | condition | MSP | payment_flow đúng? | |
| MSP-49 | text | MSP | Ghi chú dài đứng cạnh condition | attach=MSP-48 |
| E6 | edge | | Yes | from=MSP-48; to=MSP-50 |
| E7 | edge | | No | from=MSP-48; to=MSP-51 |
| MSP-51 | condition | MSP | Hết max payment? | |
| E8 | edge | | Yes | from=MSP-51; to=MSP-50 |
| E9 | edge | | No | from=MSP-51; to=MSP-52 |
| MSP-52 | task | MSP | Giữ invoice | |
| E10 | edge | | | from=MSP-52; to=MSP-53 |
| MSP-50 | task | MSP | Đóng invoice | |
| E11 | edge | | | from=MSP-50; to=MSP-53 |
| MSP-53 | end | MSP | Lưu | |
