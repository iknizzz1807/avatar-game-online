# Go Server Implementation Plan - FarmWorld Online

## Overview

This document details the implementation plan for the Go server that handles:
- **Authentication** (register, login, session management)
- **Currency (Xu)** management - server-authoritative
- **Inventory** system (20 slots, stacking)
- **Farm** system (4x4 plots, seed/water/harvest logic)
- **Fishing** system (rod, bait, RNG-based results)
- **Item** definitions (static data)

The Go server communicates with:
- **Godot Client**: HTTP API for game state changes
- **Godot Dedicated Server**: WebSocket for real-time multiplayer sync (separate from this Go server)

---

## 1. Project Structure

```
server/
├── main.go                 # Entry point, HTTP server setup
├── go.mod                  # Module definition
├── go.sum                  # Dependencies
├── config/
│   └── config.go           # Configuration (port, DB path, JWT secret)
├── db/
│   ├── db.go              # SQLite connection and migrations
│   └── seed.go            # Seed static item data
├── models/
│   ├── user.go            # User model
│   ├── inventory.go       # Inventory item model
│   ├── plot.go            # Farm plot model
│   ├── item.go            # Static item definitions
│   └── fishing.go         # Fishing session model
├── services/
│   ├── auth.go            # Authentication logic
│   ├── currency.go        # Xu management
│   ├── inventory.go       # Inventory operations
│   ├── farm.go            # Farm logic
│   ├── fishing.go         # Fishing logic
│   └── shop.go            # Shop operations
├── handlers/
│   ├── auth.go            # Auth HTTP handlers
│   ├── game.go            # Game state handlers
│   ├── farm.go            # Farm handlers
│   ├── fishing.go         # Fishing handlers
│   └── inventory.go       # Inventory handlers
├── middleware/
│   └── auth.go            # JWT verification middleware
├── utils/
│   ├── jwt.go             # JWT token utilities
│   └── errors.go          # Error codes and messages
└── tests/
    └── (unit tests)
```

---

## 2. Database Schema

### 2.1 Tables

```sql
-- Users table
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    coins INTEGER DEFAULT 1000 DEFAULT 1000,
    current_map TEXT DEFAULT 'central_park',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Items (static reference data)
CREATE TABLE items (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,           -- 'seed', 'harvest', 'fishing_rod', 'bait', 'clothing'
    buy_price INTEGER NOT NULL,
    sell_price INTEGER NOT NULL,
    grow_time_seconds INTEGER,    -- NULL for non-seeds
    stackable INTEGER DEFAULT 1,
    max_stack INTEGER DEFAULT 99
);

-- User inventory
CREATE TABLE inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    item_id TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id),
    UNIQUE(user_id, item_id)
);

-- Farm plots (4x4 = 16 per user)
CREATE TABLE plots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    plot_index INTEGER NOT NULL,  -- 0-15
    status TEXT NOT NULL,         -- 'EMPTY', 'SEEDED', 'GROWING', 'READY'
    seed_id TEXT,                -- NULL if EMPTY
    ready_at DATETIME,           -- NULL until watered
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, plot_index)
);

-- Active fishing sessions
CREATE TABLE fishing_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    seat_index INTEGER NOT NULL,  -- 0-4 (5 fishing spots)
    started_at DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### 2.2 Static Items (Seeded Data)

```go
// Seeds
{ID: "seed_carrot", Name: "Cà rốt", Type: "seed", BuyPrice: 50, SellPrice: 90, GrowTime: 120}
{ID: "seed_tomato", Name: "Cà chua", Type: "seed", BuyPrice: 80, SellPrice: 160, GrowTime: 300}
{ID: "seed_corn", Name: "Bắp", Type: "seed", BuyPrice: 120, SellPrice: 260, GrowTime: 600}

// Harvests (auto-generated, not seeded)
{ID: "harvest_carrot", Name: "Cà rốt", Type: "harvest", BuyPrice: 0, SellPrice: 90}
{ID: "harvest_tomato", Name: "Cà chua", Type: "harvest", BuyPrice: 0, SellPrice: 160}
{ID: "harvest_corn", Name: "Bắp", Type: "harvest", BuyPrice: 0, SellPrice: 260}

// Fishing items
{ID: "rod_bamboo", Name: "Cần câu tre", Type: "fishing_rod", BuyPrice: 200, SellPrice: 100}
{ID: "bait_normal", Name: "Mồi câu", Type: "bait", BuyPrice: 20, SellPrice: 5}

// Fish (earned from fishing)
{ID: "fish_small", Name: "Cá nhỏ", Type: "fish", BuyPrice: 0, SellPrice: 30}
{ID: "fish_medium", Name: "Cá vừa", Type: "fish", BuyPrice: 0, SellPrice: 80}
{ID: "fish_large", Name: "Cá lớn", Type: "fish", BuyPrice: 0, SellPrice: 200}
```

---

## 3. API Endpoints

All endpoints (except register/login) require `Authorization: Bearer <token>` header.

### 3.1 Authentication

| Method | Endpoint | Body | Response |
|--------|----------|------|----------|
| POST | `/api/auth/register` | `{"username": "...", "password": "...", "display_name": "..."}` | `{"token": "...", "user": {...}}` |
| POST | `/api/auth/login` | `{"username": "...", "password": "..."}` | `{"token": "...", "user": {...}}` |

### 3.2 User State

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/user/me` | Get current user state (coins, inventory, plots) |
| PUT | `/api/user/map` | `{"map": "farm/central_park/fishing_lake"}` - change map |

### 3.3 Inventory

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| GET | `/api/inventory` | - | Get all inventory items |
| POST | `/api/inventory/sell` | `{"item_id": "...", "quantity": 1}` | Sell items for coins |

### 3.4 Farm

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| GET | `/api/farm/plots` | - | Get all 16 plots |
| POST | `/api/farm/seed` | `{"plot_index": 0, "seed_id": "seed_carrot"}` | Plant seed (requires coins) |
| POST | `/api/farm/water` | `{"plot_index": 0}` | Water seeded plot |
| POST | `/api/farm/harvest` | `{"plot_index": 0}` | Harvest ready plot |

### 3.5 Shop

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| GET | `/api/shop/seeds` | - | Get available seeds to buy |
| POST | `/api/shop/buy` | `{"item_id": "...", "quantity": 1}` | Buy item |

### 3.6 Fishing

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| GET | `/api/fishing/status` | - | Get fishing status (seats, if fishing) |
| POST | `/api/fishing/start` | `{"seat_index": 0}` | Start fishing at seat |
| POST | `/api/fishing/stop` | - | Stop fishing |

---

## 4. Game Logic Details

### 4.1 Authentication Flow

1. **Register**: Validate input → Check username not exists → Hash password (bcrypt) → Create user with 1000 coins → Generate JWT → Return token + user data
2. **Login**: Validate input → Find user → Compare bcrypt password → Generate JWT → Return token + full user data (coins, inventory, plots)
3. **JWT**: Contains `user_id`, expires in 24 hours. Stored in header for all requests.

### 4.2 Currency System

- All coin changes happen server-side
- Before any purchase: check `user.coins >= price`
- On success: `user.coins -= price` (or `+=` for selling)
- Return new balance to client in response
- NEVER allow negative balance

### 4.3 Inventory System

- **Add item**: Check if item exists in inventory → increment quantity (up to max_stack=99) OR add new row
- **Remove item**: Decrement quantity → delete row if 0
- **Max slots**: 20 (enforced - reject if all 20 slots full and item not stackable)
- **Selling**: Remove item → add `sell_price * quantity` to coins

### 4.4 Farm System

**Plot States**: EMPTY → SEEDED → GROWING → READY → EMPTY

**Seed Flow**:
1. Client sends `seed` request with `plot_index`, `seed_id`
2. Server validates: plot is EMPTY, seed_id valid, user has enough coins
3. Server: deduct coins → set plot status to SEEDED → save seed_id

**Water Flow**:
1. Client sends `water` request with `plot_index`
2. Server validates: plot is SEEDED
3. Server: get `grow_time_seconds` from seed item → calculate `ready_at = now + grow_time` → set status to GROWING

**Harvest Flow**:
1. Client sends `harvest` request with `plot_index`
2. Server validates: plot is READY, inventory not full
3. Server: create harvest item (e.g., harvest_carrot from seed_carrot) → add to inventory → set plot to EMPTY

**Background Timer**:
- Server runs a goroutine every 5 seconds to check plots where `ready_at <= now` and status is GROWING
- Auto-update those plots to READY status

### 4.5 Fishing System

**Seats**: 5 fishing spots (index 0-4)

**Start Fishing**:
1. Client sends `start` with `seat_index`
2. Server validates: seat not occupied, user has fishing rod, user has at least 1 bait
3. Server: create fishing session → deduct 1 bait

**Fishing Timer** (server-side):
1. After starting, server starts timer: random 10-20 seconds
2. On timer end: calculate RNG based on drop rates:
   - 30%: fail (0 coins)
   - 45%: small fish (30 coins)
   - 20%: medium fish (80 coins)
   - 5%: large fish (200 coins)
3. Add fish item to inventory (if slot available) OR add coins directly
4. Delete fishing session

**Stop Fishing**:
- Client can stop anytime → delete session, free seat

**Disconnection**:
- If user disconnects while fishing → delete session, free seat, return 1 bait to inventory

---

## 5. Error Codes

| Code | Message (Vietnamese) | When |
|------|---------------------|------|
| `INSUFFICIENT_FUNDS` | "Bạn không đủ Xu để thực hiện thao tác này." | Coin balance < price |
| `INVENTORY_FULL` | "Túi đồ của bạn đã đầy (20/20)." | No empty inventory slots |
| `PLOT_NOT_EMPTY` | "Ô đất này đã được trồng." | Plot not EMPTY on seed |
| `PLOT_NOT_SEEDED` | "Ô này chưa gieo hạt." | Plot not SEEDED on water |
| `PLOT_NOT_READY` | "Cây chưa đến lúc thu hoạch." | Plot not READY on harvest |
| `NO_FISHING_ROD` | "Bạn cần có cần câu." | No rod in inventory |
| `NO_BAIT` | "Bạn không có mồi câu." | No bait in inventory |
| `SEAT_OCCUPIED` | "Vị trí này đã có người ngồi." | Seat already taken |
| `RATE_LIMIT_CHAT` | "Bạn đang gửi tin nhắn quá nhanh." | >3 messages per 5 seconds |

---

## 6. Implementation Order

1. **Setup**: `go.mod`, config, basic HTTP server
2. **Database**: SQLite connection, migrations, seed data
3. **Models**: User, Item, Inventory, Plot, FishingSession
4. **Auth**: Register, Login, JWT middleware
5. **Currency**: Coin operations in services
6. **Inventory**: Add/remove items
7. **Farm**: Plot operations + background timer
8. **Shop**: Buy seeds
9. **Fishing**: Start/stop + timer + RNG
10. **HTTP Handlers**: Wire everything together

---

## 7. Configuration

```go
// config/config.go
type Config struct {
    Port        string // default "8080"
    DBPath      string // default "game.db"
    JWTSecret   string // minimum 32 characters
    ServerPort  string // for WebSocket (if needed)
}
```

---

## 8. Dependencies

```
github.com/gin-gonic/gin        # HTTP framework
github.com/golang-jwt/jwt/v5    # JWT tokens
github.com/go-sql-driver/mysql  # or github.com/mattn/go-sqlite3
golang.org/x/crypto/bcrypt      # Password hashing
```

---

## 9. Important Notes for Future Developers

1. **Server Authority**: All game logic (coins, farm growth, fishing RNG) MUST happen server-side. Client is only for display and input.

2. **JWT Secret**: Use a strong secret in production, store in environment variable.

3. **Database**: Currently using SQLite for simplicity. Can migrate to MySQL/PostgreSQL for production.

4. **Concurrency**: Farm background timer runs in separate goroutine. Use database transactions for fishing operations (remove bait + create session).

5. **Testing**: Write unit tests for:
   - Coin transactions (buy/sell)
   - Inventory stacking
   - Farm state transitions
   - Fishing RNG distribution

6. **API Versioning**: Currently using `/api/v1/` prefix implicitly. Consider explicit versioning.

7. **Client Integration**: This Go server exposes HTTP API. Godot client calls these endpoints for game state. Real-time position sync goes through separate Godot server (not covered in this plan).

---

*Plan created for FarmWorld Online Go Server implementation.*
*This document should be updated as implementation progresses.*