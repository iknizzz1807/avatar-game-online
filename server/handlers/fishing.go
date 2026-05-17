package handlers

import (
	"github.com/gin-gonic/gin"
	"github.com/avatar-game/server/services"
	"github.com/avatar-game/server/utils"
	"github.com/avatar-game/server/middleware"
)

func GetFishingStatus(c *gin.Context) {
	userID := middleware.GetUserID(c)
	status, err := services.GetFishingStatus(userID)
	if err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 500)
		return
	}

	coins, _ := services.GetCoins(userID)
	utils.RespondWithCoins(c, coins, gin.H{"fishing_status": status})
}

func StartFishing(c *gin.Context) {
	userID := middleware.GetUserID(c)
	
	var data map[string]interface{}
	if err := c.ShouldBindJSON(&data); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}
	
	seatIndex, ok := data["seat_index"].(float64)
	if !ok {
		c.JSON(400, gin.H{"error": "seat_index required"})
		return
	}
	
	err := services.StartFishing(userID, int(seatIndex))
	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	coins, _ := services.GetCoins(userID)
	status, _ := services.GetFishingStatus(userID)
	inventory, _ := services.GetInventory(userID)
	utils.RespondWithCoins(c, coins, gin.H{
		"fishing_status": status,
		"inventory":      inventory,
		"message":        "Đang câu cá...",
	})
}

func StopFishing(c *gin.Context) {
	userID := middleware.GetUserID(c)

	if err := services.StopFishing(userID); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 500)
		return
	}

	coins, _ := services.GetCoins(userID)
	status, _ := services.GetFishingStatus(userID)
	inventory, _ := services.GetInventory(userID)
	utils.RespondWithCoins(c, coins, gin.H{
		"fishing_status": status,
		"inventory":      inventory,
		"message":        "Đã dừng câu cá",
	})
}