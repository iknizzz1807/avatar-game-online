package services

import (
	"github.com/avatar-game/server/db"
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
	if item.BuyPrice <= 0 || (item.Type != models.ItemTypeSeed && item.Type != models.ItemTypeFishingRod && item.Type != models.ItemTypeBait) {
		return utils.ErrCodeInvalidInput
	}

	tx, err := db.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	totalPrice := item.BuyPrice * quantity
	if err := subtractCoinsTx(tx, userID, totalPrice); err != nil {
		return err
	}

	count, err := inventoryCountTx(tx, userID)
	if err != nil {
		return err
	}

	hasItem, _, err := hasItemTx(tx, userID, itemID)
	if err != nil {
		return err
	}
	if count >= 20 && !hasItem {
		return utils.ErrCodeInventoryFull
	}

	if err := addItemTx(tx, userID, itemID, quantity); err != nil {
		return err
	}

	return tx.Commit()
}
