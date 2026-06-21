package handlers

import (
	"strconv"

	"github.com/avatar-game/server/middleware"
	"github.com/avatar-game/server/services"
	"github.com/avatar-game/server/utils"
	"github.com/gin-gonic/gin"
)

type RegisterRequest struct {
	Username    string `json:"username" binding:"required,min=3,max=20"`
	Password    string `json:"password" binding:"required,min=6"`
	DisplayName string `json:"display_name" binding:"required,min=1,max=50"`
}

type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}

	token, user, err := services.Register(services.RegisterInput{
		Username:    req.Username,
		Password:    req.Password,
		DisplayName: req.DisplayName,
	})

	if err != nil {
		if err == utils.ErrCodeUsernameExists {
			utils.RespondError(c, utils.ErrCodeUsernameExists, 400)
			return
		}
		utils.RespondError(c, utils.ErrCodeInvalidInput, 500)
		return
	}

	c.JSON(200, gin.H{
		"token": token,
		"user": gin.H{
			"id":           user.ID,
			"username":     user.Username,
			"display_name": user.DisplayName,
			"coins":        user.Coins,
			"current_map":  user.CurrentMap,
		},
	})
}

func Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}

	token, user, err := services.Login(services.LoginInput{
		Username: req.Username,
		Password: req.Password,
	})

	if err != nil {
		if err == utils.ErrCodeUserNotFound || err == utils.ErrCodeWrongPassword {
			utils.RespondError(c, utils.ErrCodeWrongPassword, 401)
			return
		}
		utils.RespondError(c, utils.ErrCodeInvalidInput, 500)
		return
	}

	c.JSON(200, gin.H{
		"token": token,
		"user": gin.H{
			"id":           user.ID,
			"username":     user.Username,
			"display_name": user.DisplayName,
			"coins":        user.Coins,
			"current_map":  user.CurrentMap,
		},
	})
}

func GetMe(c *gin.Context) {
	userID := middleware.GetUserID(c)
	user, err := services.GetUserByID(userID)
	if err != nil {
		utils.RespondError(c, utils.ErrCodeUserNotFound, 404)
		return
	}

	inventory, _ := services.GetInventory(userID)
	plots, _ := services.GetPlots(userID)

	c.JSON(200, gin.H{
		"id":           user.ID,
		"username":     user.Username,
		"display_name": user.DisplayName,
		"coins":        user.Coins,
		"current_map":  user.CurrentMap,
		"inventory":    inventory,
		"plots":        plots,
	})
}

type ChangeMapRequest struct {
	Map string `json:"map" binding:"required"`
}

func ChangeMap(c *gin.Context) {
	userID := middleware.GetUserID(c)
	var req ChangeMapRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}

	validMaps := map[string]bool{
		"farm":         true,
		"central_park": true,
		"fishing_lake": true,
		"game":         true,
		"park":         true,
		"fish_pond":    true,
		"town":         true,
		"cave":         true,
	}

	if !validMaps[req.Map] {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}

	if err := services.UpdateUserMap(userID, req.Map); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 500)
		return
	}

	coins, _ := services.GetCoins(userID)
	utils.RespondWithCoins(c, coins, gin.H{"current_map": req.Map})
}

func GetUserProfile(c *gin.Context) {
	profileID, err := strconv.Atoi(c.Param("id"))
	if err != nil || profileID <= 0 {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}

	user, err := services.GetUserByID(profileID)
	if err != nil {
		utils.RespondError(c, utils.ErrCodeUserNotFound, 404)
		return
	}

	utils.RespondSuccess(c, gin.H{
		"id":           user.ID,
		"display_name": user.DisplayName,
		"coins":        user.Coins,
		"current_map":  user.CurrentMap,
		"created_at":   user.CreatedAt,
	})
}
