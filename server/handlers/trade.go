package handlers

import (
	"strconv"

	"github.com/avatar-game/server/middleware"
	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/services"
	"github.com/avatar-game/server/utils"
	"github.com/gin-gonic/gin"
)

func CreateTradeRequest(c *gin.Context) {
	userID := middleware.GetUserID(c)
	var data struct {
		TargetUserID int `json:"target_user_id"`
	}
	if err := c.ShouldBindJSON(&data); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	session, err := services.CreateTradeRequest(userID, data.TargetUserID)
	respondTrade(c, session, err)
}

func GetActiveTrade(c *gin.Context) {
	session, err := services.GetActiveTrade(middleware.GetUserID(c))
	if err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	utils.RespondSuccess(c, gin.H{"trade": session})
}

func GetTradeSession(c *gin.Context) {
	sessionID, ok := tradeIDParam(c)
	if !ok {
		return
	}
	session, err := services.GetTradeSession(middleware.GetUserID(c), sessionID)
	respondTrade(c, session, err)
}

func AcceptTrade(c *gin.Context) {
	sessionID, ok := tradeIDParam(c)
	if !ok {
		return
	}
	session, err := services.AcceptTrade(middleware.GetUserID(c), sessionID)
	respondTrade(c, session, err)
}

func CancelTrade(c *gin.Context) {
	sessionID, ok := tradeIDParam(c)
	if !ok {
		return
	}
	if err := services.CancelTrade(middleware.GetUserID(c), sessionID); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	utils.RespondSuccess(c, gin.H{"canceled": true})
}

func SetTradeOffer(c *gin.Context) {
	sessionID, ok := tradeIDParam(c)
	if !ok {
		return
	}
	var data struct {
		Items []models.TradeItemRequest `json:"items"`
	}
	if err := c.ShouldBindJSON(&data); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	session, err := services.SetTradeOffer(middleware.GetUserID(c), sessionID, data.Items)
	respondTrade(c, session, err)
}

func SetTradeReady(c *gin.Context) {
	sessionID, ok := tradeIDParam(c)
	if !ok {
		return
	}
	var data struct {
		Ready bool `json:"ready"`
	}
	if err := c.ShouldBindJSON(&data); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	session, err := services.SetTradeReady(middleware.GetUserID(c), sessionID, data.Ready)
	respondTrade(c, session, err)
}

func tradeIDParam(c *gin.Context) (int, bool) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil || id <= 0 {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return 0, false
	}
	return id, true
}

func respondTrade(c *gin.Context, session *models.TradeSessionResponse, err error) {
	if err != nil {
		switch err {
		case utils.ErrCodeUnauthorized:
			utils.RespondError(c, utils.ErrCodeUnauthorized, 401)
		case utils.ErrCodeUserNotFound:
			utils.RespondError(c, utils.ErrCodeUserNotFound, 404)
		case utils.ErrCodeInventoryFull:
			utils.RespondError(c, utils.ErrCodeInventoryFull, 400)
		default:
			utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		}
		return
	}
	utils.RespondSuccess(c, gin.H{"trade": session})
}
