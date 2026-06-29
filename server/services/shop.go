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
		{ItemID: "seed_beetroot", Name: "Beetroot", Type: models.ItemTypeSeed, BuyPrice: 50},
		{ItemID: "seed_cabbage", Name: "Cabbage", Type: models.ItemTypeSeed, BuyPrice: 60},
		{ItemID: "seed_carrot", Name: "Carrot", Type: models.ItemTypeSeed, BuyPrice: 70},
		{ItemID: "seed_cauliflower", Name: "Cauliflower", Type: models.ItemTypeSeed, BuyPrice: 80},
		{ItemID: "seed_kale", Name: "Kale", Type: models.ItemTypeSeed, BuyPrice: 90},
		{ItemID: "seed_parsnip", Name: "Parsnip", Type: models.ItemTypeSeed, BuyPrice: 100},
		{ItemID: "seed_potato", Name: "Potato", Type: models.ItemTypeSeed, BuyPrice: 110},
		{ItemID: "seed_pumpkin", Name: "Pumpkin", Type: models.ItemTypeSeed, BuyPrice: 120},
		{ItemID: "seed_radish", Name: "Radish", Type: models.ItemTypeSeed, BuyPrice: 130},
		{ItemID: "seed_sunflower", Name: "Sunflower", Type: models.ItemTypeSeed, BuyPrice: 140},
		{ItemID: "seed_wheat", Name: "Wheat", Type: models.ItemTypeSeed, BuyPrice: 150},
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
