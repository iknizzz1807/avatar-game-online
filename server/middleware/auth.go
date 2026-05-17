package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/avatar-game/server/utils"
)

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			utils.RespondError(c, utils.ErrCodeUnauthorized, 401)
			c.Abort()
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			utils.RespondError(c, utils.ErrCodeUnauthorized, 401)
			c.Abort()
			return
		}

		tokenString := parts[1]
		claims, err := utils.ValidateToken(tokenString)
		if err != nil {
			utils.RespondError(c, utils.ErrCodeUnauthorized, 401)
			c.Abort()
			return
		}

		c.Set("user_id", claims.UserID)
		c.Next()
	}
}

func GetUserID(c *gin.Context) int {
	userID, exists := c.Get("user_id")
	if !exists {
		return 0
	}
	return userID.(int)
}