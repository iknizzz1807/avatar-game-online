package utils

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type ErrorCode string

func (e ErrorCode) Error() string {
	return string(e)
}

const (
	ErrCodeInsufficientFunds  ErrorCode = "INSUFFICIENT_FUNDS"
	ErrCodeInventoryFull      ErrorCode = "INVENTORY_FULL"
	ErrCodePlotNotEmpty      ErrorCode = "PLOT_NOT_EMPTY"
	ErrCodePlotNotSeeded     ErrorCode = "PLOT_NOT_SEEDED"
	ErrCodePlotNotReady      ErrorCode = "PLOT_NOT_READY"
	ErrCodeNoFishingRod      ErrorCode = "NO_FISHING_ROD"
	ErrCodeNoBait            ErrorCode = "NO_BAIT"
	ErrCodeSeatOccupied      ErrorCode = "SEAT_OCCUPIED"
	ErrCodeInvalidInput      ErrorCode = "INVALID_INPUT"
	ErrCodeUnauthorized      ErrorCode = "UNAUTHORIZED"
	ErrCodeUserNotFound      ErrorCode = "USER_NOT_FOUND"
	ErrCodeUsernameExists    ErrorCode = "USERNAME_EXISTS"
	ErrCodeWrongPassword     ErrorCode = "WRONG_PASSWORD"
)

var errorMessages = map[ErrorCode]string{
	ErrCodeInsufficientFunds: "Bạn không đủ Xu để thực hiện thao tác này.",
	ErrCodeInventoryFull:     "Túi đồ của bạn đã đầy (20/20).",
	ErrCodePlotNotEmpty:      "Ô đất này đã được trồng.",
	ErrCodePlotNotSeeded:     "Ô này chưa gieo hạt.",
	ErrCodePlotNotReady:      "Cây chưa đến lúc thu hoạch.",
	ErrCodeNoFishingRod:      "Bạn cần có cần câu.",
	ErrCodeNoBait:            "Bạn không có mồi câu.",
	ErrCodeSeatOccupied:      "Vị trí này đã có người ngồi.",
	ErrCodeInvalidInput:      "Dữ liệu không hợp lệ.",
	ErrCodeUnauthorized:      "Bạn chưa đăng nhập.",
	ErrCodeUserNotFound:      "Tài khoản không tồn tại.",
	ErrCodeUsernameExists:     "Tên đăng nhập đã được sử dụng.",
	ErrCodeWrongPassword:     "Mật khẩu không đúng.",
}

type ErrorResponse struct {
	Error   ErrorCode `json:"error"`
	Message string    `json:"message"`
}

func RespondError(c *gin.Context, code ErrorCode, status int) {
	c.JSON(status, ErrorResponse{
		Error:   code,
		Message: errorMessages[code],
	})
}

func RespondSuccess(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, gin.H{"success": true, "data": data})
}

func RespondWithCoins(c *gin.Context, coins int, data interface{}) {
	c.JSON(http.StatusOK, gin.H{"success": true, "coins": coins, "data": data})
}