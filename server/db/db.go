package db

import (
	"database/sql"
	"log"

	_ "github.com/mattn/go-sqlite3"
	"github.com/avatar-game/server/config"
	"github.com/avatar-game/server/models"
)

var DB *sql.DB

func Initialize(cfg *config.Config) error {
	var err error
	DB, err = sql.Open("sqlite3", cfg.DBPath)
	if err != nil {
		return err
	}

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
			current_map TEXT DEFAULT 'central_park',
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
			ended_at DATETIME,
			FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
			UNIQUE(user_id)
		)`,
	}

	for _, q := range queries {
		if _, err := DB.Exec(q); err != nil {
			return err
		}
	}

	log.Println("Database migrations completed")
	return nil
}

func seedItems() error {
	items := []models.Item{
		// Seeds
		{ID: "seed_carrot", Name: "Cà rốt", Type: models.ItemTypeSeed, BuyPrice: 50, SellPrice: 90, GrowTimeSeconds: intPtr(120), Stackable: true, MaxStack: 99},
		{ID: "seed_tomato", Name: "Cà chua", Type: models.ItemTypeSeed, BuyPrice: 80, SellPrice: 160, GrowTimeSeconds: intPtr(300), Stackable: true, MaxStack: 99},
		{ID: "seed_corn", Name: "Bắp", Type: models.ItemTypeSeed, BuyPrice: 120, SellPrice: 260, GrowTimeSeconds: intPtr(600), Stackable: true, MaxStack: 99},
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