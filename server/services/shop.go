package services

import (
	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/utils"
)

type ShopItem struct {
	ItemID   string `json:"item_id"`
	Name     string `json:"name"`
	Type     string `json:"type"`
	BuyPrice int    `json:"buy_price"`
}

func GetSeeds() ([]ShopItem, error) {
	items := []ShopItem{
		{ItemID: "seed_carrot", Name: "Cà rốt", Type: models.ItemTypeSeed, BuyPrice: 50},
		{ItemID: "seed_tomato", Name: "Cà chua", Type: models.ItemTypeSeed, BuyPrice: 80},
		{ItemID: "seed_corn", Name: "Bắp", Type: models.ItemTypeSeed, BuyPrice: 120},
	}
	return items, nil
}

func GetFishingShopItems() ([]ShopItem, error) {
	items := []ShopItem{
		{ItemID: "rod_bamboo", Name: "Cần câu tre", Type: models.ItemTypeFishingRod, BuyPrice: 200},
		{ItemID: "bait_normal", Name: "Mồi câu", Type: models.ItemTypeBait, BuyPrice: 20},
	}
	return items, nil
}

func BuyItem(userID int, itemID string, quantity int) error {
	if quantity <= 0 {
		return utils.ErrCodeInvalidInput
	}

	item, err := GetItemByID(itemID)
	if err != nil {
		return utils.ErrCodeInvalidInput
	}

	totalPrice := item.BuyPrice * quantity
	if err := SubtractCoins(userID, totalPrice); err != nil {
		return err
	}

	// Check inventory space
	count, err := GetInventoryCount(userID)
	if err != nil {
		return err
	}

	hasItem, _ := HasItem(userID, itemID)
	if count >= 20 && !hasItem {
		// Refund coins
		AddCoins(userID, totalPrice)
		return utils.ErrCodeInventoryFull
	}

	if err := AddItem(userID, itemID, quantity); err != nil {
		// Refund on error
		AddCoins(userID, totalPrice)
		return err
	}

	return nil
}