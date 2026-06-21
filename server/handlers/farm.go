package handlers

import (
	"github.com/avatar-game/server/middleware"
	"github.com/avatar-game/server/services"
	"github.com/avatar-game/server/utils"
	"github.com/gin-gonic/gin"
)

func GetPlots(c *gin.Context) {
	userID := middleware.GetUserID(c)
	plots, err := services.GetPlots(userID)
	if err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 500)
		return
	}

	coins, _ := services.GetCoins(userID)
	utils.RespondWithCoins(c, coins, gin.H{"plots": plots})
}

type SeedRequest struct {
	PlotIndex int    `json:"plot_index" binding:"required,min=0,max=15"`
	SeedID    string `json:"seed_id" binding:"required"`
}

func SeedPlot(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var data map[string]interface{}
	if err := c.ShouldBindJSON(&data); err != nil {
		c.JSON(400, gin.H{"debug": "error", "message": err.Error()})
		return
	}

	plotIndex, ok := data["plot_index"].(float64)
	if !ok {
		c.JSON(400, gin.H{"debug": "error", "message": "plot_index not found or not number"})
		return
	}

	seedID, ok := data["seed_id"].(string)
	if !ok {
		c.JSON(400, gin.H{"debug": "error", "message": "seed_id not found or not string"})
		return
	}

	err := services.SeedPlot(userID, int(plotIndex), seedID)
	if err != nil {
		c.JSON(400, gin.H{"debug": "service_error", "message": err.Error()})
		return
	}

	coins, _ := services.GetCoins(userID)
	plots, _ := services.GetPlots(userID)
	utils.RespondWithCoins(c, coins, gin.H{"plots": plots})
}

func WaterPlot(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var data map[string]interface{}
	if err := c.ShouldBindJSON(&data); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	plotIndex, ok := data["plot_index"].(float64)
	if !ok {
		c.JSON(400, gin.H{"error": "plot_index required"})
		return
	}

	err := services.WaterPlot(userID, int(plotIndex))
	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	coins, _ := services.GetCoins(userID)
	plots, _ := services.GetPlots(userID)
	utils.RespondWithCoins(c, coins, gin.H{"plots": plots})
}

func HarvestPlot(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var data map[string]interface{}
	if err := c.ShouldBindJSON(&data); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	plotIndex, ok := data["plot_index"].(float64)
	if !ok {
		c.JSON(400, gin.H{"error": "plot_index required"})
		return
	}

	harvestID, err := services.HarvestPlot(userID, int(plotIndex))
	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	coins, _ := services.GetCoins(userID)
	plots, _ := services.GetPlots(userID)
	inventory, _ := services.GetInventory(userID)
	utils.RespondWithCoins(c, coins, gin.H{"plots": plots, "inventory": inventory, "harvest": harvestID})
}
