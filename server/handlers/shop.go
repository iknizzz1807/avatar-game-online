package handlers

import (
	"github.com/gin-gonic/gin"
	"github.com/avatar-game/server/services"
	"github.com/avatar-game/server/utils"
	"github.com/avatar-game/server/middleware"
)

func GetSeeds(c *gin.Context) {
	seeds, err := services.GetSeeds()
	if err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 500)
		return
	}

	coins, _ := services.GetCoins(middleware.GetUserID(c))
	utils.RespondWithCoins(c, coins, gin.H{"seeds": seeds})
}

func GetFishingShop(c *gin.Context) {
	items, err := services.GetFishingShopItems()
	if err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 500)
		return
	}

	coins, _ := services.GetCoins(middleware.GetUserID(c))
	utils.RespondWithCoins(c, coins, gin.H{"items": items})
}

func BuyItem(c *gin.Context) {
	userID := middleware.GetUserID(c)
	
	var data map[string]interface{}
	if err := c.ShouldBindJSON(&data); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}
	
	itemID, ok := data["item_id"].(string)
	if !ok {
		c.JSON(400, gin.H{"error": "item_id required"})
		return
	}
	
	quantity := 1
	if q, ok := data["quantity"].(float64); ok {
		quantity = int(q)
	}
	
	err := services.BuyItem(userID, itemID, quantity)
	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	coins, _ := services.GetCoins(userID)
	inventory, _ := services.GetInventory(userID)
	utils.RespondWithCoins(c, coins, gin.H{"inventory": inventory})
}