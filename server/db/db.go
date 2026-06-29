package db

import (
	"database/sql"
	"log"

	"github.com/avatar-game/server/config"
	"github.com/avatar-game/server/models"
	_ "modernc.org/sqlite"
)

var DB *sql.DB

func Initialize(cfg *config.Config) error {
	var err error
	DB, err = sql.Open("sqlite", cfg.DBPath)
	if err != nil {
		return err
	}
	DB.SetMaxOpenConns(1)

	if err = DB.Ping(); err != nil {
		return err
	}

	log.Println("Database connected:", cfg.DBPath)

	if err = migrate(); err != nil {
		return err
	}

	if err = seedItems(); err != nil {
		return err
	}

	return nil
}

func migrate() error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT UNIQUE NOT NULL,
			password_hash TEXT NOT NULL,
			display_name TEXT NOT NULL,
			coins INTEGER DEFAULT 1000,
			current_map TEXT DEFAULT 'farm',
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE TABLE IF NOT EXISTS items (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			type TEXT NOT NULL,
			buy_price INTEGER NOT NULL,
			sell_price INTEGER NOT NULL,
			grow_time_seconds INTEGER,
			stackable INTEGER DEFAULT 1,
			max_stack INTEGER DEFAULT 99
		)`,
		`CREATE TABLE IF NOT EXISTS inventory (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id INTEGER NOT NULL,
			item_id TEXT NOT NULL,
			quantity INTEGER NOT NULL DEFAULT 1,
			FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
			FOREIGN KEY (item_id) REFERENCES items(id),
			UNIQUE(user_id, item_id)
		)`,
		`CREATE TABLE IF NOT EXISTS plots (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id INTEGER NOT NULL,
			plot_index INTEGER NOT NULL,
			status TEXT NOT NULL,
			seed_id TEXT,
			ready_at DATETIME,
			FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
			UNIQUE(user_id, plot_index)
		)`,
		`CREATE TABLE IF NOT EXISTS fishing_sessions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id INTEGER NOT NULL,
			seat_index INTEGER NOT NULL,
			started_at DATETIME NOT NULL,
			finish_at DATETIME,
			ended_at DATETIME,
			FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
			UNIQUE(user_id)
		)`,
		`CREATE TABLE IF NOT EXISTS trade_sessions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			requester_id INTEGER NOT NULL,
			target_id INTEGER NOT NULL,
			status TEXT NOT NULL DEFAULT 'pending',
			requester_ready INTEGER NOT NULL DEFAULT 0,
			target_ready INTEGER NOT NULL DEFAULT 0,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE,
			FOREIGN KEY (target_id) REFERENCES users(id) ON DELETE CASCADE
		)`,
		`CREATE TABLE IF NOT EXISTS trade_items (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			session_id INTEGER NOT NULL,
			user_id INTEGER NOT NULL,
			item_id TEXT NOT NULL,
			quantity INTEGER NOT NULL,
			FOREIGN KEY (session_id) REFERENCES trade_sessions(id) ON DELETE CASCADE,
			FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
			FOREIGN KEY (item_id) REFERENCES items(id),
			UNIQUE(session_id, user_id, item_id)
		)`,
		`CREATE TABLE IF NOT EXISTS friendships (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			requester_id INTEGER NOT NULL,
			target_id INTEGER NOT NULL,
			status TEXT NOT NULL DEFAULT 'pending',
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE,
			FOREIGN KEY (target_id) REFERENCES users(id) ON DELETE CASCADE,
			UNIQUE(requester_id, target_id)
		)`,
	}

	for _, q := range queries {
		if _, err := DB.Exec(q); err != nil {
			return err
		}
	}

	if _, err := DB.Exec(`ALTER TABLE fishing_sessions ADD COLUMN finish_at DATETIME`); err != nil {
		// SQLite returns duplicate column errors after the first migration; ignore them.
		log.Println("Fishing finish_at migration skipped:", err)
	}

	log.Println("Database migrations completed")
	return nil
}

func seedItems() error {
	items := []models.Item{
		// Seeds
		{ID: "seed_beetroot", Name: "Beetroot", Type: models.ItemTypeSeed, BuyPrice: 50, SellPrice: 0, GrowTimeSeconds: intPtr(120), Stackable: true, MaxStack: 99},
		{ID: "seed_cabbage", Name: "Cabbage", Type: models.ItemTypeSeed, BuyPrice: 60, SellPrice: 0, GrowTimeSeconds: intPtr(180), Stackable: true, MaxStack: 99},
		{ID: "seed_carrot", Name: "Carrot", Type: models.ItemTypeSeed, BuyPrice: 70, SellPrice: 0, GrowTimeSeconds: intPtr(240), Stackable: true, MaxStack: 99},
		{ID: "seed_cauliflower", Name: "Cauliflower", Type: models.ItemTypeSeed, BuyPrice: 80, SellPrice: 0, GrowTimeSeconds: intPtr(300), Stackable: true, MaxStack: 99},
		{ID: "seed_kale", Name: "Kale", Type: models.ItemTypeSeed, BuyPrice: 90, SellPrice: 0, GrowTimeSeconds: intPtr(360), Stackable: true, MaxStack: 99},
		{ID: "seed_parsnip", Name: "Parsnip", Type: models.ItemTypeSeed, BuyPrice: 100, SellPrice: 0, GrowTimeSeconds: intPtr(420), Stackable: true, MaxStack: 99},
		{ID: "seed_potato", Name: "Potato", Type: models.ItemTypeSeed, BuyPrice: 110, SellPrice: 0, GrowTimeSeconds: intPtr(480), Stackable: true, MaxStack: 99},
		{ID: "seed_pumpkin", Name: "Pumpkin", Type: models.ItemTypeSeed, BuyPrice: 120, SellPrice: 0, GrowTimeSeconds: intPtr(540), Stackable: true, MaxStack: 99},
		{ID: "seed_radish", Name: "Radish", Type: models.ItemTypeSeed, BuyPrice: 130, SellPrice: 0, GrowTimeSeconds: intPtr(600), Stackable: true, MaxStack: 99},
		{ID: "seed_sunflower", Name: "Sunflower", Type: models.ItemTypeSeed, BuyPrice: 140, SellPrice: 0, GrowTimeSeconds: intPtr(660), Stackable: true, MaxStack: 99},
		{ID: "seed_wheat", Name: "Wheat", Type: models.ItemTypeSeed, BuyPrice: 150, SellPrice: 0, GrowTimeSeconds: intPtr(720), Stackable: true, MaxStack: 99},
		// Harvests
		{ID: "harvest_beetroot", Name: "Beetroot", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 100, Stackable: true, MaxStack: 99},
		{ID: "harvest_cabbage", Name: "Cabbage", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 120, Stackable: true, MaxStack: 99},
		{ID: "harvest_carrot", Name: "Carrot", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 140, Stackable: true, MaxStack: 99},
		{ID: "harvest_cauliflower", Name: "Cauliflower", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 160, Stackable: true, MaxStack: 99},
		{ID: "harvest_kale", Name: "Kale", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 180, Stackable: true, MaxStack: 99},
		{ID: "harvest_parsnip", Name: "Parsnip", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 200, Stackable: true, MaxStack: 99},
		{ID: "harvest_potato", Name: "Potato", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 220, Stackable: true, MaxStack: 99},
		{ID: "harvest_pumpkin", Name: "Pumpkin", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 240, Stackable: true, MaxStack: 99},
		{ID: "harvest_radish", Name: "Radish", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 260, Stackable: true, MaxStack: 99},
		{ID: "harvest_sunflower", Name: "Sunflower", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 280, Stackable: true, MaxStack: 99},
		{ID: "harvest_wheat", Name: "Wheat", Type: models.ItemTypeHarvest, BuyPrice: 0, SellPrice: 300, Stackable: true, MaxStack: 99},
		// Fishing items
		{ID: "rod_bamboo", Name: "Cần câu tre", Type: models.ItemTypeFishingRod, BuyPrice: 200, SellPrice: 100, Stackable: false, MaxStack: 1},
		{ID: "bait_normal", Name: "Mồi câu", Type: models.ItemTypeBait, BuyPrice: 20, SellPrice: 5, Stackable: true, MaxStack: 99},
		// Fish
		{ID: "fish_small", Name: "Cá nhỏ", Type: models.ItemTypeFish, BuyPrice: 0, SellPrice: 30, Stackable: true, MaxStack: 99},
		{ID: "fish_medium", Name: "Cá vừa", Type: models.ItemTypeFish, BuyPrice: 0, SellPrice: 80, Stackable: true, MaxStack: 99},
		{ID: "fish_large", Name: "Cá lớn", Type: models.ItemTypeFish, BuyPrice: 0, SellPrice: 200, Stackable: true, MaxStack: 99},
	}

	for _, item := range items {
		_, err := DB.Exec(`INSERT OR IGNORE INTO items (id, name, type, buy_price, sell_price, grow_time_seconds, stackable, max_stack) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			item.ID, item.Name, item.Type, item.BuyPrice, item.SellPrice, item.GrowTimeSeconds, boolToInt(item.Stackable), item.MaxStack)
		if err != nil {
			return err
		}
	}

	log.Println("Item seed data completed")
	return nil
}

func intPtr(i int) *int {
	return &i
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
