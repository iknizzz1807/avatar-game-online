package services

import (
	"database/sql"

	"github.com/avatar-game/server/db"
	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/utils"
)

func GetInventory(userID int) ([]models.InventoryResponse, error) {
	rows, err := db.DB.Query(`
		SELECT i.item_id, it.name, it.type, i.quantity
		FROM inventory i
		JOIN items it ON i.item_id = it.id
		WHERE i.user_id = ?
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []models.InventoryResponse
	for rows.Next() {
		var item models.InventoryResponse
		if err := rows.Scan(&item.ItemID, &item.Name, &item.Type, &item.Quantity); err != nil {
			return nil, err
		}
		items = append(items, item)
	}

	if items == nil {
		items = []models.InventoryResponse{}
	}

	return items, nil
}

func GetItemByID(itemID string) (*models.Item, error) {
	var item models.Item
	var growTime sql.NullInt64
	var stackableInt int
	err := db.DB.QueryRow(`
		SELECT id, name, type, buy_price, sell_price, grow_time_seconds, stackable, max_stack
		FROM items WHERE id = ?
	`, itemID).Scan(&item.ID, &item.Name, &item.Type, &item.BuyPrice, &item.SellPrice, &growTime, &stackableInt, &item.MaxStack)

	if err != nil {
		return nil, err
	}

	if growTime.Valid {
		item.GrowTimeSeconds = new(int)
		*item.GrowTimeSeconds = int(growTime.Int64)
	}

	item.Stackable = stackableInt == 1

	return &item, nil
}

func AddItem(userID int, itemID string, quantity int) error {
	var existingQty int
	err := db.DB.QueryRow("SELECT quantity FROM inventory WHERE user_id = ? AND item_id = ?", userID, itemID).Scan(&existingQty)

	if err == sql.ErrNoRows {
		_, err = db.DB.Exec("INSERT INTO inventory (user_id, item_id, quantity) VALUES (?, ?, ?)", userID, itemID, quantity)
		return err
	}

	if err != nil {
		return err
	}

	item, err := GetItemByID(itemID)
	if err != nil {
		return err
	}

	newQty := existingQty + quantity
	if newQty > item.MaxStack {
		newQty = item.MaxStack
	}

	_, err = db.DB.Exec("UPDATE inventory SET quantity = ? WHERE user_id = ? AND item_id = ?", newQty, userID, itemID)
	return err
}

func RemoveItem(userID int, itemID string, quantity int) error {
	var currentQty int
	err := db.DB.QueryRow("SELECT quantity FROM inventory WHERE user_id = ? AND item_id = ?", userID, itemID).Scan(&currentQty)
	if err != nil {
		return err
	}

	if currentQty < quantity {
		return utils.ErrCodeInvalidInput
	}

	if currentQty == quantity {
		_, err = db.DB.Exec("DELETE FROM inventory WHERE user_id = ? AND item_id = ?", userID, itemID)
	} else {
		_, err = db.DB.Exec("UPDATE inventory SET quantity = quantity - ? WHERE user_id = ? AND item_id = ?", quantity, userID, itemID)
	}

	return err
}

func HasItem(userID int, itemID string) (bool, int) {
	var quantity int
	err := db.DB.QueryRow("SELECT quantity FROM inventory WHERE user_id = ? AND item_id = ?", userID, itemID).Scan(&quantity)
	if err != nil {
		return false, 0
	}
	return true, quantity
}

func GetInventoryCount(userID int) (int, error) {
	var count int
	err := db.DB.QueryRow("SELECT COUNT(*) FROM inventory WHERE user_id = ?", userID).Scan(&count)
	return count, err
}

func SellItem(userID int, itemID string, quantity int) (int, error) {
	if quantity <= 0 {
		return 0, utils.ErrCodeInvalidInput
	}

	tx, err := db.DB.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	has, qty, err := hasItemTx(tx, userID, itemID)
	if err != nil {
		return 0, err
	}
	if !has || qty < quantity {
		return 0, utils.ErrCodeInvalidInput
	}

	item, err := getItemByIDTx(tx, itemID)
	if err != nil {
		return 0, err
	}

	if item.SellPrice <= 0 {
		return 0, utils.ErrCodeInvalidInput
	}

	if err := removeItemTx(tx, userID, itemID, quantity); err != nil {
		return 0, err
	}

	totalEarned := item.SellPrice * quantity
	if err := addCoinsTx(tx, userID, totalEarned); err != nil {
		return 0, err
	}

	return totalEarned, tx.Commit()
}
