package main

import (
	"log"

	"github.com/avatar-game/server/config"
	"github.com/avatar-game/server/db"
	"github.com/avatar-game/server/handlers"
	"github.com/avatar-game/server/middleware"
	"github.com/avatar-game/server/services"
	"github.com/avatar-game/server/utils"
	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()

	utils.SetJWTSecret(cfg.JWTSecret)

	if err := db.Initialize(cfg); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	services.StartFarmTicker()

	r := gin.Default()

	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	auth := r.Group("/api/auth")
	{
		auth.POST("/register", handlers.Register)
		auth.POST("/login", handlers.Login)
	}

	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware())
	{
		api.GET("/user/me", handlers.GetMe)
		api.GET("/user/:id/profile", handlers.GetUserProfile)
		api.PUT("/user/map", handlers.ChangeMap)

		api.GET("/inventory", handlers.GetInventory)
		api.POST("/inventory/sell", handlers.SellItem)

		api.GET("/farm/plots", handlers.GetPlots)
		api.POST("/farm/seed", handlers.SeedPlot)
		api.POST("/farm/water", handlers.WaterPlot)
		api.POST("/farm/harvest", handlers.HarvestPlot)

		api.GET("/shop/seeds", handlers.GetSeeds)
		api.GET("/shop/fishing", handlers.GetFishingShop)
		api.POST("/shop/buy", handlers.BuyItem)

		api.GET("/fishing/status", handlers.GetFishingStatus)
		api.POST("/fishing/start", handlers.StartFishing)
		api.POST("/fishing/claim", handlers.ClaimFishing)
		api.POST("/fishing/fail", handlers.FailFishing)
		api.POST("/fishing/stop", handlers.StopFishing)

		api.GET("/trade/active", handlers.GetActiveTrade)
		api.POST("/trade/request", handlers.CreateTradeRequest)
		api.GET("/trade/:id", handlers.GetTradeSession)
		api.POST("/trade/:id/accept", handlers.AcceptTrade)
		api.POST("/trade/:id/cancel", handlers.CancelTrade)
		api.POST("/trade/:id/offer", handlers.SetTradeOffer)
		api.POST("/trade/:id/ready", handlers.SetTradeReady)

		api.GET("/friends", handlers.GetFriends)
		api.GET("/friends/requests", handlers.GetFriendRequests)
		api.POST("/friends/request", handlers.SendFriendRequest)
		api.POST("/friends/:id/accept", handlers.AcceptFriendRequest)
		api.POST("/friends/:id/decline", handlers.DeclineFriendRequest)
		api.DELETE("/friends/:id", handlers.RemoveFriend)
	}

	log.Printf("Server starting on port %s", cfg.Port)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
