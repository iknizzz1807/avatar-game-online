package services

import (
	"github.com/avatar-game/server/db"
	"github.com/avatar-game/server/utils"
)

func AddCoins(userID int, amount int) error {
	if amount <= 0 {
		return nil
	}
	_, err := db.DB.Exec("UPDATE users SET coins = coins + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", amount, userID)
	return err
}

func SubtractCoins(userID int, amount int) error {
	if amount <= 0 {
		return nil
	}

	var currentCoins int
	err := db.DB.QueryRow("SELECT coins FROM users WHERE id = ?", userID).Scan(&currentCoins)
	if err != nil {
		return err
	}

	if currentCoins < amount {
		return utils.ErrCodeInsufficientFunds
	}

	_, err = db.DB.Exec("UPDATE users SET coins = coins - ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", amount, userID)
	return err
}

func GetCoins(userID int) (int, error) {
	var coins int
	err := db.DB.QueryRow("SELECT coins FROM users WHERE id = ?", userID).Scan(&coins)
	return coins, err
}
