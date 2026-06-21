package services

import (
	"math/rand"
	"time"

	"github.com/avatar-game/server/db"
	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/utils"
)

type FishingResult struct {
	Type   string `json:"type"`    // 'fail', 'small', 'medium', 'large'
	ItemID string `json:"item_id"` // fish item ID or empty if fail
	Coins  int    `json:"coins"`
}

func GetFishingStatus(userID int) (models.FishingStatusResponse, error) {
	status := models.FishingStatusResponse{
		IsFishing: false,
		Seats:     make([]bool, models.MaxFishingSeats),
	}

	// Get occupied seats
	rows, err := db.DB.Query("SELECT seat_index FROM fishing_sessions WHERE ended_at IS NULL")
	if err != nil {
		return status, err
	}
	defer rows.Close()

	for rows.Next() {
		var seatIndex int
		if err := rows.Scan(&seatIndex); err != nil {
			continue
		}
		if seatIndex >= 0 && seatIndex < models.MaxFishingSeats {
			status.Seats[seatIndex] = true
		}
	}

	// Check if current user is fishing
	var currentSeat int
	err = db.DB.QueryRow("SELECT seat_index FROM fishing_sessions WHERE user_id = ? AND ended_at IS NULL", userID).Scan(&currentSeat)
	if err == nil {
		status.IsFishing = true
		status.SeatIndex = &currentSeat
	}

	return status, nil
}

func StartFishing(userID int, seatIndex int) error {
	if seatIndex < 0 || seatIndex >= models.MaxFishingSeats {
		return utils.ErrCodeInvalidInput
	}

	var activeUserSession int
	if err := db.DB.QueryRow("SELECT COUNT(*) FROM fishing_sessions WHERE user_id = ? AND ended_at IS NULL", userID).Scan(&activeUserSession); err != nil {
		return err
	}
	if activeUserSession > 0 {
		return utils.ErrCodeInvalidInput
	}

	// Check if seat is occupied
	var occupied int
	err := db.DB.QueryRow("SELECT COUNT(*) FROM fishing_sessions WHERE seat_index = ? AND ended_at IS NULL", seatIndex).Scan(&occupied)
	if err != nil {
		return err
	}
	if occupied > 0 {
		return utils.ErrCodeSeatOccupied
	}

	// Check for fishing rod
	hasRod, _ := HasItem(userID, "rod_bamboo")
	if !hasRod {
		return utils.ErrCodeNoFishingRod
	}

	// Check for bait
	hasBait, baitQty := HasItem(userID, "bait_normal")
	if !hasBait || baitQty < 1 {
		return utils.ErrCodeNoBait
	}

	// Remove bait
	if err := RemoveItem(userID, "bait_normal", 1); err != nil {
		return err
	}

	// Keep the user_id uniqueness constraint compatible with repeat sessions.
	if _, err := db.DB.Exec("DELETE FROM fishing_sessions WHERE user_id = ? AND ended_at IS NOT NULL", userID); err != nil {
		return err
	}

	// Create fishing session
	result, err := db.DB.Exec(
		"INSERT INTO fishing_sessions (user_id, seat_index, started_at) VALUES (?, ?, ?)",
		userID, seatIndex, time.Now(),
	)
	if err != nil {
		return err
	}
	sessionID, _ := result.LastInsertId()

	// Start async fishing timer
	go runFishingSession(userID, int(sessionID))

	return nil
}

func runFishingSession(userID int, sessionID int) {
	// Random time between 10-20 seconds
	randomDuration := time.Duration(10+rand.Intn(11)) * time.Second
	time.Sleep(randomDuration)

	// Calculate result
	result := calculateFishingResult()
	processFishingResult(userID, sessionID, result)
}

func calculateFishingResult() FishingResult {
	randNum := rand.Float64()

	if randNum < 0.30 {
		return FishingResult{Type: "fail", ItemID: "", Coins: 0}
	} else if randNum < 0.75 {
		return FishingResult{Type: "small", ItemID: "fish_small", Coins: 30}
	} else if randNum < 0.95 {
		return FishingResult{Type: "medium", ItemID: "fish_medium", Coins: 80}
	} else {
		return FishingResult{Type: "large", ItemID: "fish_large", Coins: 200}
	}
}

func processFishingResult(userID int, sessionID int, result FishingResult) {
	var active int
	err := db.DB.QueryRow("SELECT COUNT(*) FROM fishing_sessions WHERE id = ? AND user_id = ? AND ended_at IS NULL", sessionID, userID).Scan(&active)
	if err != nil || active == 0 {
		return
	}

	// End the fishing session
	db.DB.Exec("UPDATE fishing_sessions SET ended_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ? AND ended_at IS NULL", sessionID, userID)

	// Add rewards
	if result.Coins > 0 {
		AddCoins(userID, result.Coins)
	}

	if result.ItemID != "" {
		AddItem(userID, result.ItemID, 1)
	}
}

func StopFishing(userID int) error {
	// Get current session
	var sessionID, baitQty int
	err := db.DB.QueryRow("SELECT id FROM fishing_sessions WHERE user_id = ? AND ended_at IS NULL", userID).Scan(&sessionID)
	if err != nil {
		return err
	}

	// Delete session
	_, err = db.DB.Exec("UPDATE fishing_sessions SET ended_at = CURRENT_TIMESTAMP WHERE id = ?", sessionID)
	if err != nil {
		return err
	}

	// Return 1 bait
	baitQty = 1
	AddItem(userID, "bait_normal", baitQty)

	return nil
}
