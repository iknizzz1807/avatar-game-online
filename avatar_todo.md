## PHASE 0 — SETUP

- [ ] 🟢 Tạo Godot 4 project, cấu trúc thư mục rõ ràng: `client/`, `server/`, `shared/`
- [ ] 🟢 Tạo Go project riêng, cấu trúc: `handlers/`, `models/`, `db/`, `services/`
- [ ] 🟢 Tạo file `Constants` dùng chung (bên Godot): item ID, giá cả, thời gian sinh trưởng, drop rate
- [ ] 🟢 Setup Git, 2 repo hoặc monorepo tùy team
- [ ] 🟢 Cấu hình Godot project nhận biết chạy chế độ **Client** hay **Dedicated Server**

---

## PHASE 1 — GO SERVER: DATABASE & LƯU TRỮ

### Thiết kế bảng
- [ ] 🟡 Bảng **users**: id, username, password (đã hash), tên hiển thị, số Xu, map hiện tại
- [ ] 🟡 Bảng **plots**: thuộc user nào, ô số mấy (0–15), trạng thái, loại hạt, thời điểm sẽ chín
- [ ] 🟡 Bảng **inventory**: user nào, item gì, số lượng bao nhiêu
- [ ] 🟢 Bảng **items** (tĩnh): toàn bộ vật phẩm trong game — tên, loại, giá mua, giá bán

### Khởi tạo
- [ ] 🟢 Server tự tạo bảng khi khởi động lần đầu nếu chưa có
- [ ] 🟢 Seed sẵn dữ liệu vật phẩm mặc định (3 hạt giống, cần câu, mồi câu)

---

## PHASE 2 — GO SERVER: XÁC THỰC (AUTH)

- [ ] 🟡 **Đăng ký**: nhận username + password + tên → kiểm tra username chưa tồn tại → lưu tài khoản → cấp **1.000 Xu** → trả token phiên
- [ ] 🟡 **Đăng nhập**: xác thực username + password → trả token + toàn bộ game state (Xu, inventory, 16 ô đất)
- [ ] 🟢 Password phải hash trước khi lưu, không lưu plaintext
- [ ] 🟢 Mọi request đến Go Server đều phải kèm token hợp lệ — không có token thì từ chối
- [ ] 🟢 Lỗi rõ ràng: "Sai mật khẩu" / "Tài khoản không tồn tại" / "Username đã được dùng"

---

## PHASE 3 — GO SERVER: HỆ THỐNG XU

- [ ] 🔴 **Mọi thay đổi Xu đều xử lý tại Go Server** — Godot Server và Client không được tự cộng/trừ
- [ ] 🟡 Trước khi trừ Xu: kiểm tra số dư đủ không → thiếu thì từ chối, trả lỗi `INSUFFICIENT_FUNDS`
- [ ] 🟢 Sau mỗi thay đổi: trả số Xu mới về đúng client đó
- [ ] 🟢 Không cho phép số Xu âm trong bất kỳ trường hợp nào

---

## PHASE 4 — GO SERVER: FARM LOGIC

### Gieo hạt
- [ ] 🟡 Client gửi lên: "gieo hạt X vào ô Y"
- [ ] 🟡 Go Server kiểm tra: ô phải **EMPTY** + đủ Xu
- [ ] 🟡 Thành công: trừ Xu, ô → **SEEDED**, lưu loại hạt giống

### Tưới nước
- [ ] 🟡 Go Server kiểm tra: ô phải **SEEDED**
- [ ] 🟡 Thành công: ô → **GROWING**, ghi lại **thời điểm sẽ chín** (= bây giờ + thời gian của loại hạt)
- [ ] 🔴 Thời điểm chín lưu trong DB — không để client tự tính

### Cây chín tự động
- [ ] 🔴 Go Server chạy tiến trình nền, định kỳ quét ô đang GROWING đã đến giờ → tự chuyển **READY**
- [ ] 🟡 Push thông báo "Cây đã chín!" về đúng client (qua Godot Server hoặc trực tiếp)

### Thu hoạch
- [ ] 🟡 Go Server kiểm tra: ô phải **READY** + túi đồ chưa đầy
- [ ] 🟡 Thành công: thêm nông sản vào inventory, ô → **EMPTY**

### Bán nông sản
- [ ] 🟡 Go Server tính tổng giá trị → xóa nông sản khỏi inventory → cộng Xu

### Cửa hàng hạt giống
- [ ] 🟡 Go Server kiểm tra Xu → trừ Xu → thêm hạt vào inventory

---

## PHASE 5 — GO SERVER: FISHING LOGIC

### Mua đồ câu cá
- [ ] 🟡 Go Server bán cần câu (200 Xu) và mồi (20 Xu/cái) — kiểm tra Xu như mọi giao dịch khác

### Bắt đầu câu
- [ ] 🟡 Go Server kiểm tra: player có cần + mồi không
- [ ] 🟡 Thành công: trừ 1 mồi, lưu trạng thái "player đang câu tại ghế X"
- [ ] 🟡 Thông báo cho Godot Server: "player A đang ngồi ghế X" → Godot Server broadcast cho zone

### Kết quả câu (RNG)
- [ ] 🔴 Go Server đặt timer **ngẫu nhiên 10–20 giây**
- [ ] 🔴 Hết timer → **Go Server tính RNG** theo bảng xác suất:

  | Kết quả | Tỉ lệ | Xu nhận |
  |---|---|---|
  | Câu trượt | 30% | 0 |
  | Cá nhỏ | 45% | 30 Xu |
  | Cá vừa | 20% | 80 Xu |
  | Cá lớn | 5% | 200 Xu |

- [ ] 🔴 Go Server cộng Xu (nếu có), lưu DB → gửi kết quả về client
- [ ] 🔴 Client **chỉ nhận kết quả** — không tự tính, không biết trước

### Kết thúc câu
- [ ] 🟡 Go Server xóa trạng thái "đang câu", thông báo Godot Server giải phóng ghế
- [ ] 🟡 Mất kết nối khi đang câu: Go Server tự kết thúc phiên câu + hoàn 1 mồi vào inventory

---

## PHASE 6 — GODOT DEDICATED SERVER: REAL-TIME SYNC

### Quản lý zone
- [ ] 🟡 Duy trì danh sách player đang online trong từng zone (farm, công viên, hồ câu)
- [ ] 🟡 Player vào zone → gửi cho họ danh sách player hiện có + vị trí + trạng thái
- [ ] 🟡 Player vào zone → thông báo các player cũ có người mới
- [ ] 🟡 Player rời / mất kết nối → thông báo cả zone

### Đồng bộ di chuyển
- [ ] 🔴 Nhận vị trí mới từ client → broadcast đến tất cả player khác trong cùng zone
- [ ] 🟡 Nhận trạng thái hành động (đứng / đi / ngồi / câu) → broadcast tương tự

### Đồng bộ ghế câu
- [ ] 🟡 Khi Go Server báo "player A ngồi ghế X" → Godot Server broadcast `seat_occupied` cho zone hồ câu
- [ ] 🟡 Khi Go Server báo "ghế X trống" → broadcast `seat_empty`

### Chat
- [ ] 🟡 Nhận tin nhắn từ client → broadcast đến toàn zone kèm tên người gửi
- [ ] 🟢 Giới hạn: 100 ký tự / tin, tối đa 3 tin / 5 giây / người

---

## PHASE 7 — GODOT CLIENT

### Màn hình Auth
- [X] 🟢 Form đăng ký / đăng nhập → gọi Go Server → lưu token
- [ ] 🟢 Sau đăng nhập: kết nối luôn vào Godot Server, load map mặc định (Công Viên)

### HUD
- [X] 🟢 Hiển thị số Xu — tự cập nhật mỗi khi Go Server trả về số mới
- [X] 🟢 Nút mở túi đồ, nút chuyển map

### Túi đồ (Inventory)
- [X] 🟡 20 ô, hiển thị icon + số lượng
- [X] 🟢 Click ô → tooltip tên item + nút Bán (nếu là nông sản/cá)

### Chat
- [X] 🟡 Chat box: lịch sử tin nhắn, ô nhập, nút gửi
- [X] 🟢 Chat bubble trên đầu nhân vật: hiện 4 giây rồi tự ẩn

### Farm Map
- [ ] 🟡 Hiển thị 16 ô đất với đúng trạng thái (lấy từ Go Server khi load map)
- [ ] 🟡 Ô đang GROWING: hiển thị countdown (tính từ `ready_at` Go Server trả về)
- [ ] 🟡 Click ô → hành động phù hợp → gửi request Go Server → cập nhật UI theo response

### Central Park
- [ ] 🔴 Kết nối Godot Server → nhận danh sách player → spawn nhân vật từng người
- [ ] 🔴 Di chuyển local player → gửi vị trí lên Godot Server → nhận vị trí người khác → di chuyển mượt
- [ ] 🟡 Click NPC thời trang → gọi Go Server mua đồ → broadcast skin mới qua Godot Server

### Fishing Lake
- [ ] 🟡 Hiển thị ghế trống / có người (nhận từ Godot Server)
- [ ] 🟡 Click ghế → gửi Go Server xin câu → nhận OK → gửi Godot Server cập nhật ghế
- [ ] 🟡 Chờ Go Server gửi kết quả → hiển thị animation + thông báo

---

## PHASE 8 — XỬ LÝ LỖI

| Tình huống | Nơi xử lý | Thông báo client |
|---|---|---|
| Không đủ Xu | Go Server | "Bạn không đủ Xu" |
| Túi đồ đầy | Go Server | "Túi đồ đã đầy (20/20)" |
| Ô đất sai trạng thái | Go Server | "Không thể thực hiện lúc này" |
| Ghế câu đã có người | Go Server | "Vị trí đã có người ngồi" |
| Hết mồi câu | Go Server | "Hết mồi — hãy mua thêm" |
| Mất kết nối Godot Server | Client | "Mất kết nối — đang thử lại..." |
| Mất kết nối Go Server | Client | "Không thể thực hiện — thử lại sau" |

- [ ] 🔴 Thao tác thay đổi nhiều bảng cùng lúc (trừ mồi + đánh dấu ghế) phải dùng **DB transaction**
- [ ] 🟡 Go Server khởi động lại: tự giải phóng ghế bị kẹt trạng thái "có người"

---

## PHASE 9 — KIỂM THỬ

### 1 người chơi
- [ ] 🟢 Đăng ký → đăng nhập → thấy 1.000 Xu
- [ ] 🟢 Trồng → tưới → logout → login lại → timer vẫn đúng → chín → thu hoạch → bán → Xu tăng
- [ ] 🟢 Mua cần + mồi → câu → nhận kết quả ngẫu nhiên

### Nhiều người chơi
- [ ] 🔴 2 client vào Công Viên → thấy nhau di chuyển
- [ ] 🔴 Client A chat → Client B thấy bubble + chatbox
- [ ] 🔴 Client A disconnect → Client B thấy nhân vật A biến mất
- [ ] 🟡 2 client click cùng ghế câu → chỉ 1 người được ngồi

### Bảo mật
- [ ] 🟡 Gửi request harvest ô chưa chín → Go Server từ chối
- [ ] 🟡 Gửi request không có token → Go Server từ chối toàn bộ

---

## PHASE 10 — BUILD & DEMO

- [ ] 🟢 Export Godot Client (Windows) + Godot Dedicated Server (headless)
- [ ] 🟢 Build Go Server thành binary chạy được
- [ ] 🟢 Chạy trên cùng mạng LAN: 1 máy chạy cả 2 server, máy khác kết nối vào
- [ ] 🟢 Chuẩn bị slide: sơ đồ kiến trúc 3 thành phần, giải thích tại sao phân chia như vậy
- [ ] 🟢 Demo điểm kỹ thuật: timer cây phía Go Server, RNG phía Go Server, sync di chuyển phía Godot Server

---

## ƯU TIÊN NẾU THIẾU THỜI GIAN

| Mức | Nội dung |
|---|---|
| **Bắt buộc** | Auth + Xu + Farm đầy đủ + Multiplayer sync cơ bản ở Công Viên |
| **Nên có** | Hồ câu cá + Chat + Inventory UI |
| **Nếu còn thời gian** | Thời trang NPC + Animation đẹp |
| **Để v2** | Kết bạn, leaderboard, sự kiện |
