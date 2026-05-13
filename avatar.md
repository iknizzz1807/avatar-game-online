## 1. Tổng quan Game

### 1.1 Thể loại & Mô tả
FarmWorld Online là game **social simulation 2D top-down**, kết hợp giữa farming casual và giao tiếp cộng đồng. Người chơi sở hữu một nông trại riêng tư để kiếm tiền, sau đó dùng tiền đó để tham gia các hoạt động xã hội ở khu vực công cộng.

### 1.2 Vòng lặp Game chính (Core Loop)

```
[Nông trại] Trồng cây → Thu hoạch → Bán → Có Xu
     ↓
[Công viên / Hồ câu] Tiêu Xu → Mua vật phẩm / Câu cá → Giao lưu
     ↓
[Xã hội] Kết bạn → Flex trang phục / điểm câu → Quay lại farm
```


## 2. Hệ thống Cốt lõi (Global Systems)

### 2.1 Hệ thống Tiền tệ — "Xu"

| Thuộc tính | Giá trị |
|---|---|
| Đơn vị | Xu (🪙) |
| Xu khởi đầu | **1.000 Xu** (cấp khi tạo tài khoản mới, một lần duy nhất) |
| Phạm vi áp dụng | Toàn bộ game, tất cả map |
| Lưu trữ | Server-side (client không được phép tự cộng/trừ) |

**Business Rule:**
- Mọi giao dịch cộng/trừ Xu đều phải xử lý và xác nhận tại **server** trước khi cập nhật UI phía client.
- Client chỉ hiển thị số Xu sau khi nhận xác nhận từ server.
- Không có Xu âm — nếu số dư không đủ, server trả về lỗi `INSUFFICIENT_FUNDS`.

---

### 2.2 Hệ thống Tài khoản & Xác thực

**Luồng Đăng ký:**
1. Người chơi nhập: Tên hiển thị, Username, Password.
2. Server tạo tài khoản, khởi tạo: Xu = 1.000, túi đồ rỗng, vị trí mặc định = Công Viên.
3. Client nhận token phiên (session token) và chuyển đến màn hình chọn nhân vật.

**Luồng Đăng nhập:**
1. Nhập Username + Password.
2. Server xác thực, trả về session token + toàn bộ trạng thái tài khoản (Xu, vật phẩm, trạng thái farm).
3. Client load map cuối cùng người chơi đã ở (mặc định: Công Viên).

---

### 2.3 Hệ thống Multiplayer & Đồng bộ

**Mô hình:** Server Authority — server là nguồn sự thật duy nhất.

| Dữ liệu | Tần suất đồng bộ | Ghi chú |
|---|---|---|
| Vị trí nhân vật (x, y) | Real-time (mỗi input) | Interpolate phía client để mượt |
| Trạng thái hành động (đứng / đi / ngồi / câu) | Khi thay đổi | Broadcast cho tất cả trong zone |
| Số Xu | Sau mỗi giao dịch | Chỉ gửi cho người chơi đó |
| Trạng thái ô đất farm | Khi thay đổi | Chỉ gửi cho chủ farm |

**Zone/Room:** Mỗi map là một zone riêng. Khi người chơi chuyển map, client ngắt kết nối zone cũ và kết nối zone mới. Server chỉ broadcast dữ liệu trong cùng zone.

---

### 2.4 Hệ thống Chat

**Loại chat:** Chat theo khu vực (Zone Chat) — tin nhắn chỉ hiển thị cho người trong cùng map.

**Hiển thị:**
- **Chat box** góc dưới màn hình: lịch sử tin nhắn dạng cuộn, tối đa 50 dòng.
- **Chat bubble** trên đầu nhân vật: hiển thị 3–5 giây rồi tự ẩn.

**Business Rule:**
- Giới hạn độ dài tin nhắn: **100 ký tự**.
- Giới hạn tốc độ gửi: tối đa **3 tin/5 giây** (chống spam).
- Lọc từ ngữ tục tĩu phía server (basic filter).

---

### 2.5 Túi Đồ (Inventory)

| Thuộc tính | Giá trị |
|---|---|
| Số ô tối đa | 20 ô |
| Loại vật phẩm | Hạt giống, Nông sản thu hoạch, Cá, Cần câu, Mồi câu, Quần áo |
| Xếp chồng | Vật phẩm cùng loại có thể xếp chồng, tối đa 99/ô |

---

## 3. Map 1 — Nông Trại (Farm Map)

### 3.1 Tổng quan

- **Loại:** Private instance — mỗi người chơi có một farm riêng.
- **Quyền truy cập:** Chỉ chủ sở hữu (giai đoạn đầu). Bạn bè có thể thêm vào sau.
- **Mục tiêu:** Nguồn thu nhập chính của game.

---

### 3.2 Lưới Ô Đất (Grid System)

- Kích thước lưới: **4×4 = 16 ô đất**.
- Mỗi ô đất có ID riêng: `plot_01` đến `plot_16`.

**Trạng thái của mỗi ô đất:**

| Trạng thái | Mô tả | Hành động có thể thực hiện |
|---|---|---|
| `EMPTY` | Đất trống | Gieo hạt |
| `SEEDED` | Đã gieo, chưa tưới | Tưới nước |
| `GROWING` | Đang phát triển (đang đếm ngược) | Không làm gì / chờ |
| `READY` | Chín, chờ thu hoạch | Thu hoạch |
| `WILTED` | Quá hạn thu hoạch (chưa dùng ở v1) | — |

**Sơ đồ luồng trạng thái:**
```
EMPTY → [Gieo hạt] → SEEDED → [Tưới nước] → GROWING → [Hết timer] → READY → [Thu hoạch] → EMPTY
```

---

### 3.3 Danh sách Hạt Giống

| ID | Tên | Giá mua | Thời gian lớn | Sản phẩm | Giá bán | Lợi nhuận |
|---|---|---|---|---|---|---|
| `seed_carrot` | Cà rốt 🥕 | 50 Xu | 2 phút | Cà rốt | 90 Xu | +40 Xu |
| `seed_tomato` | Cà chua 🍅 | 80 Xu | 5 phút | Cà chua | 160 Xu | +80 Xu |
| `seed_corn` | Bắp 🌽 | 120 Xu | 10 phút | Bắp | 260 Xu | +140 Xu |

> **Ghi chú dev:** Thời gian đếm ngược tính từ lúc server nhận lệnh **tưới nước**, không phải lúc gieo hạt.

---

### 3.4 UX Flow — Trồng Trọt

#### Flow A: Gieo Hạt

```
1. Người chơi click vào ô đất [EMPTY]
2. Server kiểm tra: ô đất có phải EMPTY không?
   → Nếu không: hiển thị tooltip "Ô này đã có cây"
3. Hiển thị UI popup "Chọn Hạt Giống" (danh sách 3 loại, hiển thị giá)
4. Người chơi chọn hạt giống
5. Server kiểm tra: người chơi có đủ Xu không?
   → Nếu không đủ: thông báo "Không đủ Xu" → đóng popup
6. Server xử lý:
   - Trừ Xu
   - Cập nhật ô đất: EMPTY → SEEDED, lưu loại hạt giống
7. Client cập nhật: hiển thị icon hạt giống trên ô đất
```

#### Flow B: Tưới Nước

```
1. Người chơi click vào ô đất [SEEDED]
2. Server xác nhận trạng thái là SEEDED
3. Server xử lý:
   - Cập nhật ô đất: SEEDED → GROWING
   - Bắt đầu timer server-side (dựa theo loại hạt giống)
4. Client cập nhật: hiển thị icon cây đang lớn + countdown timer
5. Khi timer hết: server tự động cập nhật GROWING → READY, push thông báo "Cây đã chín!" cho client
```

#### Flow C: Thu Hoạch & Bán

```
1. Người chơi click vào ô đất [READY]
2. Server xử lý:
   - Thêm nông sản vào túi đồ (inventory)
   - Cập nhật ô đất: READY → EMPTY
3. Client cập nhật: ô đất về trống, túi đồ hiển thị nông sản mới

--- Bán nông sản ---
4. Người chơi mở giao diện "Bán hàng" (nút trên màn hình farm)
5. Hiển thị danh sách nông sản trong túi đồ + giá bán mỗi loại
6. Người chơi chọn bán (tất cả hoặc từng loại)
7. Server xử lý: xóa nông sản khỏi túi đồ, cộng Xu tương ứng
8. Client hiển thị animation +Xu, cập nhật số dư
```

---

### 3.5 Cửa Hàng Nông Trại (Farm Shop)

- Truy cập bằng cách click vào **icon cửa hàng** góc màn hình farm.
- Chỉ bán **hạt giống**.
- Giao diện: danh sách 3 hạt giống, hiển thị ảnh + tên + giá + nút "Mua".

---

## 4. Map 2 — Công Viên Trung Tâm (Central Park)

### 4.1 Tổng quan

- **Loại:** Public Server — tất cả người chơi online đều xuất hiện ở đây.
- **Mục tiêu:** Hub xã hội, giao lưu, và tiêu Xu vào thời trang.
- **Đây là map mặc định** khi đăng nhập lần đầu và khi chuyển map.

---

### 4.2 Bố Cục Bản Đồ

| Khu vực | Mô tả |
|---|---|
| Trung tâm | Đài phun nước, ghế đá, cây xanh (chướng ngại vật tĩnh) |
| Góc Tây Nam | NPC Thời Trang (Fashion Shop) |
| Góc Đông Bắc | Bảng thông báo (Notice Board) |
| Rìa bản đồ | Cổng sang map Nông Trại (riêng) và map Hồ Câu Cá |

---

### 4.3 Di chuyển & Tương tác

**Di chuyển:** Click-to-move hoặc WASD/Arrow keys. Server nhận input, validate, broadcast vị trí mới cho tất cả trong zone.

**Chướng ngại vật:** Cây, ghế đá, đài phun nước — client và server đều có collision map để ngăn đi xuyên qua.

**Chuyển map:**
```
1. Người chơi đi đến vùng cổng (trigger zone)
2. Hiển thị popup xác nhận "Bạn có muốn đến [Tên Map]?"
3. Xác nhận → Server xử lý chuyển zone → Client load map mới
```

---

### 4.4 Tương tác Xã Hội

**Click vào nhân vật khác:**
- Hiển thị mini profile: Tên, ảnh avatar, số ngày chơi.
- Nút hành động: **Kết bạn** / **Nhắn tin riêng** (tính năng nâng cao).

**Chat bubble:** Mỗi tin nhắn gửi trong chat box đồng thời hiện bong bóng thoại trên đầu nhân vật trong 4 giây.

---

### 4.5 NPC Thời Trang (Fashion Shop) — Tùy chọn nâng cao

**Truy cập:** Click vào NPC đứng ở góc công viên.

**Danh mục bán:**

| Loại | Ví dụ | Giá |
|---|---|---|
| Tóc | Tóc ngắn nâu, Tóc dài đen | 200–500 Xu |
| Áo | Áo thun trắng, Áo hoodie | 300–700 Xu |
| Quần | Quần jean, Quần váy | 200–500 Xu |
| Phụ kiện | Kính mát, Nón kết | 150–300 Xu |

**UX Flow:**
```
1. Click NPC → Mở cửa sổ Fashion Shop
2. Chọn danh mục → Xem danh sách vật phẩm
3. Click vào item → Hiển thị preview trên avatar người chơi
4. Bấm "Mua" → Server kiểm tra Xu → Trừ Xu, thêm vào tủ đồ
5. Bấm "Mặc" → Server lưu outfit, broadcast skin mới cho toàn zone
```

---

### 4.6 Bảng Thông Báo (Notice Board)

Click vào bảng → Mở popup tĩnh hiển thị thông tin: sự kiện, hướng dẫn chơi, tip kiếm Xu. Chỉ là UI đọc, không có logic nghiệp vụ phức tạp.

---

## 5. Map 3 — Hồ Câu Cá (Fishing Lake)

### 5.1 Tổng quan

- **Loại:** Public Server — nhiều người chơi cùng câu.
- **Mục tiêu:** Hoạt động kiếm Xu có yếu tố may rủi (RNG), kết hợp giao lưu.
- **Điều kiện:** Người chơi cần có **Cần câu** và **Mồi câu** trong túi đồ trước khi câu.

---

### 5.2 Vật Phẩm Câu Cá

| ID | Tên | Loại | Giá mua | Ghi chú |
|---|---|---|---|---|
| `rod_bamboo` | Cần câu tre | Cần câu | 200 Xu | Loại cơ bản |
| `bait_normal` | Mồi thường | Mồi | 20 Xu/cái | Tiêu hao 1 cái/lượt câu |

> **Ghi chú thiết kế:** Mỗi lần câu tiêu tốn 1 mồi. Cần câu không hỏng ở v1. Mua tại NPC cửa hàng trong map hồ câu.

---

### 5.3 Bảng Drop Rate (Tỉ lệ rơi cá)

*Với tổ hợp: Cần câu tre + Mồi thường*

| Kết quả | Tỉ lệ | Điểm / Xu nhận được |
|---|---|---|
| Câu trượt 🌊 | 30% | 0 Xu |
| Cá nhỏ 🐟 | 45% | 30 Xu |
| Cá vừa 🐠 | 20% | 80 Xu |
| Cá lớn 🐡 | 5% | 200 Xu |

> **Server xử lý RNG:** Kết quả tính toán hoàn toàn phía server. Client không được biết kết quả trước khi server gửi về. Tránh mọi hình thức dự đoán/can thiệp từ client.

---

### 5.4 UX Flow — Câu Cá

#### Bước 1: Chuẩn bị

```
1. Người chơi vào map Hồ Câu Cá
2. Nếu chưa có cần + mồi → Hiển thị gợi ý "Hãy mua cần câu tại cửa hàng"
3. Click NPC Cửa Hàng → Mua cần câu (200 Xu) và mồi (20 Xu/cái)
```

#### Bước 2: Bắt đầu câu

```
1. Người chơi di chuyển lại gần ghế đá ven hồ (trigger zone)
2. Hiển thị nút hành động "Ngồi & Câu"
3. Người chơi bấm nút
4. Server kiểm tra:
   - Có cần câu trong túi đồ? → Nếu không: báo lỗi
   - Có ít nhất 1 mồi? → Nếu không: báo "Hết mồi"
   - Ghế đá có trống không? → Nếu đầy: báo "Chỗ ngồi đã hết"
5. Server xử lý:
   - Trừ 1 mồi khỏi túi đồ
   - Cập nhật trạng thái nhân vật: SITTING_FISHING
   - Broadcast animation ngồi câu cho zone
   - Bắt đầu timer câu (random 10–20 giây)
6. Client hiển thị: nhân vật ngồi, animation quăng câu, đếm ngược
```

#### Bước 3: Kết quả câu

```
7. Khi timer hết → Server tính toán RNG
8. Server broadcast kết quả về client:
   a. Câu trượt: hiển thị "Cá không cắn..." → tự động bắt đầu lượt câu mới (nếu còn mồi)
   b. Câu trúng: hiển thị popup "Bạn câu được [Tên Cá]! +[X] Xu 🎉"
      → Cộng Xu vào tài khoản (server-side)
      → Animation ăn mừng
9. Sau kết quả → Hỏi người chơi: "Câu tiếp?" [Tiếp tục] / [Đứng dậy]
   - Tiếp tục → lặp lại từ bước 5
   - Đứng dậy → Cập nhật trạng thái STANDING, trả ghế về trống
```

---

### 5.5 Giới Hạn & Edge Cases

| Trường hợp | Xử lý |
|---|---|
| Mồi hết trong lúc đang câu | Kết thúc lượt, thông báo "Hết mồi — hãy mua thêm" |
| Người chơi ngắt kết nối khi đang câu | Server tự giải phóng ghế, hoàn lại 1 mồi vào túi đồ |
| Nhiều người click ghế cùng lúc | Server xử lý theo thứ tự nhận request, người chậm hơn nhận thông báo "Chỗ đã có người" |

---

## 6. Luồng Người Chơi Mới (Onboarding)

```
[Màn hình chủ]
    ↓ Đăng ký / Đăng nhập
[Chọn / Tạo nhân vật]
    ↓
[Tutorial ngắn — hiển thị tooltip]
    "Bạn có 1.000 Xu! Hãy đến Nông Trại để bắt đầu kiếm thêm."
    ↓
[Load vào Công Viên Trung Tâm]
    ↓ Người chơi tự khám phá hoặc theo gợi ý
[Nông Trại] → Trồng cây đầu tiên → Thu hoạch → Bán → Cảm giác tiến bộ
    ↓
[Quay lại Công Viên] → Gặp người chơi khác → Chat
    ↓
[Hồ Câu Cá] → Mua cần + mồi → Câu thử → Nhận thưởng RNG
```

---

## 7. Bảng Trạng Thái & Lỗi Cần Xử Lý

### 7.1 Mã Lỗi Server trả về

| Mã lỗi | Ý nghĩa | Hiển thị phía client |
|---|---|---|
| `INSUFFICIENT_FUNDS` | Không đủ Xu | "Bạn không đủ Xu để thực hiện thao tác này." |
| `INVENTORY_FULL` | Túi đồ đầy | "Túi đồ của bạn đã đầy (20/20)." |
| `PLOT_NOT_EMPTY` | Ô đất không trống | "Ô đất này đã được trồng." |
| `PLOT_NOT_READY` | Cây chưa chín | "Cây chưa đến lúc thu hoạch." |
| `NO_BAIT` | Hết mồi câu | "Bạn không có mồi câu. Hãy mua tại cửa hàng." |
| `SEAT_OCCUPIED` | Ghế câu đã có người | "Vị trí này đã có người ngồi." |
| `RATE_LIMIT_CHAT` | Gửi chat quá nhanh | "Bạn đang gửi tin nhắn quá nhanh." |

### 7.2 Các Trạng Thái Nhân Vật

| Trạng thái | Mô tả | Hành động bị khóa |
|---|---|---|
| `STANDING` | Đứng / đi lại bình thường | — |
| `SITTING` | Đang ngồi ghế thường | Di chuyển |
| `SITTING_FISHING` | Đang ngồi câu | Di chuyển, mở shop |
| `IN_SHOP` | Đang mở giao diện shop | Di chuyển |

---

## 8. Task List (Roadmap)

### 8.1 Backend (Server Authority)
- [ ] Thiết kế schema dữ liệu người chơi (Xu, inventory, vị trí, map hiện tại, trạng thái nhân vật)
- [ ] API đăng ký/đăng nhập, trả về session token
- [ ] Xử lý giao dịch Xu (mua/bán), kiểm tra số dư, trả lỗi `INSUFFICIENT_FUNDS`
- [ ] Đồng bộ vị trí và trạng thái nhân vật theo zone
- [ ] Hệ thống chat theo zone + rate limit + filter từ ngữ

### 8.2 Multiplayer & Networking
- [ ] Mô hình zone/room, join/leave map
- [ ] Broadcast dữ liệu vị trí theo tick/input
- [ ] Interpolation phía client
- [ ] Đồng bộ trạng thái hành động (đứng/đi/ngồi/câu)

### 8.3 Farm Gameplay
- [ ] Lưới 4x4 plot với trạng thái `EMPTY/SEEDED/GROWING/READY`
- [ ] Flow gieo hạt, tưới nước, thu hoạch
- [ ] Timer tăng trưởng server-side theo seed
- [ ] Popup chọn hạt giống + kiểm tra Xu
- [ ] UI bán nông sản và cộng Xu

### 8.4 Fishing Gameplay
- [ ] NPC shop bán cần câu/mồi
- [ ] Flow ngồi câu + kiểm tra ghế trống
- [ ] Timer câu 10–20 giây + RNG server-side
- [ ] Trả kết quả và cộng Xu
- [ ] Xử lý edge cases (hết mồi, disconnect, ghế occupied)

### 8.5 Social & UI
- [ ] Chat box + chat bubble
- [ ] Mini profile khi click người chơi khác
- [ ] Notice Board (popup tĩnh)
- [ ] Icon chuyển map + popup xác nhận

### 8.6 QA & Logging
- [ ] Unit test cho giao dịch Xu và inventory
- [ ] Test case cho trạng thái plot và farming flow
- [ ] Log server cho lỗi quan trọng (auth, giao dịch, RNG)
