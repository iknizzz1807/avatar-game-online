package services

import (
	"database/sql"

	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/utils"
)

func getItemByIDTx(tx *sql.Tx, itemID string) (*models.Item, error) {
	var item models.Item
	var growTime sql.NullInt64
	var stackableInt int
	err := tx.QueryRow(`
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

func addCoinsTx(tx *sql.Tx, userID int, amount int) error {
	if amount <= 0 {
		return nil
	}
	_, err := tx.Exec("UPDATE users SET coins = coins + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", amount, userID)
	return err
}

func subtractCoinsTx(tx *sql.Tx, userID int, amount int) error {
	if amount <= 0 {
		return nil
	}
	var currentCoins int
	if err := tx.QueryRow("SELECT coins FROM users WHERE id = ?", userID).Scan(&currentCoins); err != nil {
		return err
	}
	if currentCoins < amount {
		return utils.ErrCodeInsufficientFunds
	}
	_, err := tx.Exec("UPDATE users SET coins = coins - ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", amount, userID)
	return err
}

func inventoryCountTx(tx *sql.Tx, userID int) (int, error) {
	var count int
	err := tx.QueryRow("SELECT COUNT(*) FROM inventory WHERE user_id = ?", userID).Scan(&count)
	return count, err
}

func hasItemTx(tx *sql.Tx, userID int, itemID string) (bool, int, error) {
	var quantity int
	err := tx.QueryRow("SELECT quantity FROM inventory WHERE user_id = ? AND item_id = ?", userID, itemID).Scan(&quantity)
	if err == sql.ErrNoRows {
		return false, 0, nil
	}
	if err != nil {
		return false, 0, err
	}
	return true, quantity, nil
}

func addItemTx(tx *sql.Tx, userID int, itemID string, quantity int) error {
	if quantity <= 0 {
		return utils.ErrCodeInvalidInput
	}
	item, err := getItemByIDTx(tx, itemID)
	if err != nil {
		return err
	}
	if quantity > item.MaxStack {
		return utils.ErrCodeInventoryFull
	}

	var existingQty int
	err = tx.QueryRow("SELECT quantity FROM inventory WHERE user_id = ? AND item_id = ?", userID, itemID).Scan(&existingQty)
	if err == sql.ErrNoRows {
		_, err = tx.Exec("INSERT INTO inventory (user_id, item_id, quantity) VALUES (?, ?, ?)", userID, itemID, quantity)
		return err
	}
	if err != nil {
		return err
	}

	newQty := existingQty + quantity
	if newQty > item.MaxStack {
		return utils.ErrCodeInventoryFull
	}
	_, err = tx.Exec("UPDATE inventory SET quantity = ? WHERE user_id = ? AND item_id = ?", newQty, userID, itemID)
	return err
}

func removeItemTx(tx *sql.Tx, userID int, itemID string, quantity int) error {
	var currentQty int
	err := tx.QueryRow("SELECT quantity FROM inventory WHERE user_id = ? AND item_id = ?", userID, itemID).Scan(&currentQty)
	if err != nil {
		return err
	}
	if currentQty < quantity {
		return utils.ErrCodeInvalidInput
	}
	if currentQty == quantity {
		_, err = tx.Exec("DELETE FROM inventory WHERE user_id = ? AND item_id = ?", userID, itemID)
	} else {
		_, err = tx.Exec("UPDATE inventory SET quantity = quantity - ? WHERE user_id = ? AND item_id = ?", quantity, userID, itemID)
	}
	return err
}
