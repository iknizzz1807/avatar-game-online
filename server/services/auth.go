package services

import (
	"database/sql"

	"github.com/avatar-game/server/db"
	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/utils"
	"golang.org/x/crypto/bcrypt"
)

type RegisterInput struct {
	Username    string `json:"username" binding:"required,min=3,max=20"`
	Password    string `json:"password" binding:"required,min=6"`
	DisplayName string `json:"display_name" binding:"required,min=1,max=50"`
}

type LoginInput struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func Register(input RegisterInput) (string, *models.User, error) {
	var exists int
	err := db.DB.QueryRow("SELECT COUNT(*) FROM users WHERE username = ?", input.Username).Scan(&exists)
	if err != nil {
		return "", nil, err
	}
	if exists > 0 {
		return "", nil, utils.ErrCodeUsernameExists
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return "", nil, err
	}

	result, err := db.DB.Exec(
		"INSERT INTO users (username, password_hash, display_name, coins, current_map) VALUES (?, ?, ?, 1000, 'central_park')",
		input.Username, string(hash), input.DisplayName,
	)
	if err != nil {
		return "", nil, err
	}

	userID, _ := result.LastInsertId()
	user, err := GetUserByID(int(userID))
	if err != nil {
		return "", nil, err
	}

	// Create 16 empty plots for the new user
	for i := 0; i < 16; i++ {
		_, err := db.DB.Exec(
			"INSERT INTO plots (user_id, plot_index, status) VALUES (?, ?, 'EMPTY')",
			user.ID, i,
		)
		if err != nil {
			return "", nil, err
		}
	}

	token, err := utils.GenerateToken(user.ID)
	if err != nil {
		return "", nil, err
	}

	return token, user, nil
}

func Login(input LoginInput) (string, *models.User, error) {
	var user models.User
	err := db.DB.QueryRow(
		"SELECT id, username, password_hash, display_name, coins, current_map, created_at, updated_at FROM users WHERE username = ?",
		input.Username,
	).Scan(&user.ID, &user.Username, &user.PasswordHash, &user.DisplayName, &user.Coins, &user.CurrentMap, &user.CreatedAt, &user.UpdatedAt)

	if err == sql.ErrNoRows {
		return "", nil, utils.ErrCodeUserNotFound
	}
	if err != nil {
		return "", nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password)); err != nil {
		return "", nil, utils.ErrCodeWrongPassword
	}

	token, err := utils.GenerateToken(user.ID)
	if err != nil {
		return "", nil, err
	}

	return token, &user, nil
}

func GetUserByID(userID int) (*models.User, error) {
	var user models.User
	err := db.DB.QueryRow(
		"SELECT id, username, password_hash, display_name, coins, current_map, created_at, updated_at FROM users WHERE id = ?",
		userID,
	).Scan(&user.ID, &user.Username, &user.PasswordHash, &user.DisplayName, &user.Coins, &user.CurrentMap, &user.CreatedAt, &user.UpdatedAt)

	if err != nil {
		return nil, err
	}
	return &user, nil
}

func GetUserByIDWithInventoryAndPlots(userID int) (*models.User, error) {
	user, err := GetUserByID(userID)
	if err != nil {
		return nil, err
	}
	return user, nil
}

func UpdateUserMap(userID int, mapName string) error {
	_, err := db.DB.Exec("UPDATE users SET current_map = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", mapName, userID)
	return err
}

func EnsureUserInMap(userID int, allowedMaps ...string) error {
	user, err := GetUserByID(userID)
	if err != nil {
		return err
	}
	for _, allowed := range allowedMaps {
		if user.CurrentMap == allowed {
			return nil
		}
	}
	return utils.ErrCodeInvalidInput
}
