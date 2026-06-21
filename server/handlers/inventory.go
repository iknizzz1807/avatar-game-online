package handlers

import (
	"github.com/avatar-game/server/middleware"
	"github.com/avatar-game/server/services"
	"github.com/avatar-game/server/utils"
	"github.com/gin-gonic/gin"
)

func GetInventory(c *gin.Context) {
	userID := middleware.GetUserID(c)
	inventory, err := services.GetInventory(userID)
	if err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 500)
		return
	}

	coins, _ := services.GetCoins(userID)
	utils.RespondWithCoins(c, coins, gin.H{"inventory": inventory})
}

func SellItem(c *gin.Context) {
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

	earned, err := services.SellItem(userID, itemID, quantity)
	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	coins, _ := services.GetCoins(userID)
	utils.RespondWithCoins(c, coins, gin.H{"earned": earned})
}
