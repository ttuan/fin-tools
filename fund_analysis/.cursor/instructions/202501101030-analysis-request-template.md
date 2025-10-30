# TEMPLATE YÊU CẦU PHÂN TÍCH QUỸ ĐẦU TƯ

## 📋 Template gửi dữ liệu mới

### Khi bạn có dữ liệu mới, hãy gửi theo format:

```
Tôi có dữ liệu giao dịch quỹ tháng [THÁNG/NĂM] mới.

File dữ liệu: [TÊN FILE]
Cấu trúc dữ liệu: [MÔ TẢ CẤU TRÚC NẾU KHÁC]

Yêu cầu phân tích:
1. Áp dụng phương pháp phân tích đã thiết lập (phân biệt giao dịch thực vs biến động giá)
2. Tạo báo cáo chi tiết với:
   - Thống kê giao dịch thực vs điều chỉnh giá
   - Top cổ phiếu được mua/bán nhiều
   - Cổ phiếu được nắm giữ ổn định (core holdings)
   - Phân tích xu hướng ngành
   - Khuyến nghị đầu tư cụ thể

[CÁC YÊU CẦU BỔ SUNG NẾU CÓ]
```

## 🎯 Kết quả sẽ nhận được:

### 1. Báo cáo phân tích chi tiết (.md)
- Phương pháp phân tích cải tiến
- Thống kê chi tiết theo từng loại giao dịch
- Top cổ phiếu mua/bán/ổn định
- Phân tích xu hướng ngành
- Khuyến nghị đầu tư cụ thể

### 2. Script Python (.py)
- Code phân tích tự động
- Tạo biểu đồ trực quan
- Xuất các file CSV chi tiết

### 3. Biểu đồ trực quan (.png)
- 9 biểu đồ phân tích chuyên sâu
- So sánh giao dịch thực vs điều chỉnh giá
- Top cổ phiếu mua/bán/ổn định

### 4. Dữ liệu chi tiết (.csv)
- Giao dịch mua chi tiết
- Giao dịch bán chi tiết
- Cổ phiếu ổn định
- Dữ liệu giao dịch thực
- Dữ liệu điều chỉnh giá

## 🔄 So sánh với tháng trước

### Nếu muốn so sánh xu hướng, hãy gửi thêm:
```
So sánh với tháng trước:
- Cổ phiếu nào từ "hot" thành "cold"?
- Cổ phiếu nào từ "cold" thành "hot"?
- Ngành nào thay đổi xu hướng?
- Quỹ nào thay đổi chiến lược?
```

## 📊 Các loại phân tích đặc biệt

### Phân tích theo yêu cầu:
- **Phân tích quỹ cụ thể**: Tập trung vào 1 vài quỹ
- **Phân tích ngành cụ thể**: Chỉ phân tích 1 ngành
- **Phân tích cổ phiếu cụ thể**: Theo dõi cổ phiếu quan tâm
- **So sánh theo thời gian**: Xu hướng qua nhiều tháng

## ⚡ Lưu ý quan trọng

### Để có kết quả tốt nhất:
1. **File dữ liệu** phải có cấu trúc tương tự như trước
2. **Mô tả rõ** nếu có thay đổi cấu trúc dữ liệu
3. **Nêu rõ yêu cầu** phân tích đặc biệt nếu có
4. **Đính kèm file** hoặc đảm bảo file có thể truy cập được

### Cấu trúc dữ liệu chuẩn:
```csv
Fund Name,Fund Code,Stock Code,Previous %,Current %,Change %,Change Points,Status
```

### Các trạng thái chuẩn:
- **CHANGED**: Điều chỉnh tỷ trọng
- **REMOVED**: Loại bỏ khỏi danh mục
- **NEW**: Thêm mới vào danh mục

---

**Lưu file template này để sử dụng cho các lần phân tích tiếp theo!**
