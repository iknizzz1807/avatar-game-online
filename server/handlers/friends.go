package handlers

import (
	"strconv"

	"github.com/avatar-game/server/middleware"
	"github.com/avatar-game/server/services"
	"github.com/avatar-game/server/utils"
	"github.com/gin-gonic/gin"
)

func GetFriends(c *gin.Context) {
	friends, err := services.GetFriends(middleware.GetUserID(c))
	if err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	utils.RespondSuccess(c, gin.H{"friends": friends})
}

func GetFriendRequests(c *gin.Context) {
	requests, err := services.GetIncomingFriendRequests(middleware.GetUserID(c))
	if err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	utils.RespondSuccess(c, gin.H{"requests": requests})
}

func SendFriendRequest(c *gin.Context) {
	var data struct {
		TargetUserID int `json:"target_user_id"`
	}
	if err := c.ShouldBindJSON(&data); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	request, err := services.SendFriendRequest(middleware.GetUserID(c), data.TargetUserID)
	respondFriend(c, request, err)
}

func AcceptFriendRequest(c *gin.Context) {
	requestID, ok := friendIDParam(c, "id")
	if !ok {
		return
	}
	request, err := services.AcceptFriendRequest(middleware.GetUserID(c), requestID)
	respondFriend(c, request, err)
}

func DeclineFriendRequest(c *gin.Context) {
	requestID, ok := friendIDParam(c, "id")
	if !ok {
		return
	}
	if err := services.DeclineFriendRequest(middleware.GetUserID(c), requestID); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	utils.RespondSuccess(c, gin.H{"declined": true})
}

func RemoveFriend(c *gin.Context) {
	friendID, ok := friendIDParam(c, "id")
	if !ok {
		return
	}
	if err := services.RemoveFriend(middleware.GetUserID(c), friendID); err != nil {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return
	}
	utils.RespondSuccess(c, gin.H{"removed": true})
}

func friendIDParam(c *gin.Context, name string) (int, bool) {
	id, err := strconv.Atoi(c.Param(name))
	if err != nil || id <= 0 {
		utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		return 0, false
	}
	return id, true
}

func respondFriend(c *gin.Context, request interface{}, err error) {
	if err != nil {
		switch err {
		case utils.ErrCodeUserNotFound:
			utils.RespondError(c, utils.ErrCodeUserNotFound, 404)
		default:
			utils.RespondError(c, utils.ErrCodeInvalidInput, 400)
		}
		return
	}
	utils.RespondSuccess(c, gin.H{"request": request})
}
