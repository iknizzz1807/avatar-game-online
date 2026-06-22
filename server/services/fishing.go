package services

import (
	"math/rand"
	"time"

	"github.com/avatar-game/server/db"
	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/utils"
)

const staleFishingGrace = 5 * time.Minute

type FishingResult struct {
	Type   string `json:"type"`    // 'fail', 'small', 'medium', 'large'
	ItemID string `json:"item_id"` // fish item ID or empty if fail
	Coins  int    `json:"coins"`
}

type FishingStartResult struct {
	FinishAt int64 `json:"finish_at"`
}

func GetFishingStatus(userID int) (models.FishingStatusResponse, error) {
	cleanupStaleFishingSessions()

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
	var finishAt *time.Time
	err = db.DB.QueryRow("SELECT seat_index, finish_at FROM fishing_sessions WHERE user_id = ? AND ended_at IS NULL", userID).Scan(&currentSeat, &finishAt)
	if err == nil {
		status.IsFishing = true
		status.SeatIndex = &currentSeat
		if finishAt != nil {
			unix := finishAt.Unix()
			status.FinishAt = &unix
		}
	}

	return status, nil
}

func StartFishing(userID int, seatIndex int) (FishingStartResult, error) {
	result := FishingStartResult{}
	if seatIndex < 0 || seatIndex >= models.MaxFishingSeats {
		return result, utils.ErrCodeInvalidInput
	}
	cleanupStaleFishingSessions()

	tx, err := db.DB.Begin()
	if err != nil {
		return result, err
	}
	defer tx.Rollback()

	var activeUserSession int
	if err := tx.QueryRow("SELECT COUNT(*) FROM fishing_sessions WHERE user_id = ? AND ended_at IS NULL", userID).Scan(&activeUserSession); err != nil {
		return result, err
	}
	if activeUserSession > 0 {
		return result, utils.ErrCodeInvalidInput
	}

	// Check if seat is occupied
	var occupied int
	err = tx.QueryRow("SELECT COUNT(*) FROM fishing_sessions WHERE seat_index = ? AND ended_at IS NULL", seatIndex).Scan(&occupied)
	if err != nil {
		return result, err
	}
	if occupied > 0 {
		return result, utils.ErrCodeSeatOccupied
	}

	// Check for fishing rod
	hasRod, _, err := hasItemTx(tx, userID, "rod_bamboo")
	if err != nil {
		return result, err
	}
	if !hasRod {
		return result, utils.ErrCodeNoFishingRod
	}

	// Check for bait
	hasBait, baitQty, err := hasItemTx(tx, userID, "bait_normal")
	if err != nil {
		return result, err
	}
	if !hasBait || baitQty < 1 {
		return result, utils.ErrCodeNoBait
	}

	// Remove bait
	if err := removeItemTx(tx, userID, "bait_normal", 1); err != nil {
		return result, err
	}

	// Keep the user_id uniqueness constraint compatible with repeat sessions.
	if _, err := tx.Exec("DELETE FROM fishing_sessions WHERE user_id = ? AND ended_at IS NOT NULL", userID); err != nil {
		return result, err
	}

	finishAt := time.Now().Add(time.Duration(10+rand.Intn(11)) * time.Second)
	_, err = tx.Exec(
		"INSERT INTO fishing_sessions (user_id, seat_index, started_at, finish_at) VALUES (?, ?, ?, ?)",
		userID, seatIndex, time.Now(), finishAt,
	)
	if err != nil {
		return result, err
	}

	result.FinishAt = finishAt.Unix()
	return result, tx.Commit()
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

func ClaimFishing(userID int) (FishingResult, error) {
	result := FishingResult{}
	tx, err := db.DB.Begin()
	if err != nil {
		return result, err
	}
	defer tx.Rollback()

	var sessionID int
	var finishAt time.Time
	err = tx.QueryRow("SELECT id, finish_at FROM fishing_sessions WHERE user_id = ? AND ended_at IS NULL", userID).Scan(&sessionID, &finishAt)
	if err != nil {
		return result, err
	}
	if time.Now().Before(finishAt) {
		return result, utils.ErrCodeInvalidInput
	}

	result = calculateFishingResult()

	// End the fishing session
	if _, err := tx.Exec("UPDATE fishing_sessions SET ended_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ? AND ended_at IS NULL", sessionID, userID); err != nil {
		return result, err
	}

	// Add rewards
	if result.Coins > 0 {
		if err := addCoinsTx(tx, userID, result.Coins); err != nil {
			return result, err
		}
	}

	if result.ItemID != "" {
		if err := addItemTx(tx, userID, result.ItemID, 1); err != nil {
			return result, err
		}
	}

	return result, tx.Commit()
}

func StopFishing(userID int) error {
	tx, err := db.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Get current session
	var sessionID, baitQty int
	err = tx.QueryRow("SELECT id FROM fishing_sessions WHERE user_id = ? AND ended_at IS NULL", userID).Scan(&sessionID)
	if err != nil {
		return err
	}

	// Delete session
	_, err = tx.Exec("UPDATE fishing_sessions SET ended_at = CURRENT_TIMESTAMP WHERE id = ?", sessionID)
	if err != nil {
		return err
	}

	// Return 1 bait
	baitQty = 1
	if err := addItemTx(tx, userID, "bait_normal", baitQty); err != nil {
		return err
	}

	return tx.Commit()
}

func cleanupStaleFishingSessions() {
	_, _ = db.DB.Exec(
		"UPDATE fishing_sessions SET ended_at = CURRENT_TIMESTAMP WHERE ended_at IS NULL AND finish_at < ?",
		time.Now().Add(-staleFishingGrace),
	)
}
