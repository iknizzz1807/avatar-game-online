package services

import (
	"time"

	"github.com/avatar-game/server/db"
	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/utils"
)

func GetPlots(userID int) ([]models.PlotResponse, error) {
	rows, err := db.DB.Query(`
		SELECT plot_index, status, seed_id, ready_at
		FROM plots
		WHERE user_id = ?
		ORDER BY plot_index
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var plots []models.PlotResponse
	for rows.Next() {
		var p models.Plot
		if err := rows.Scan(&p.PlotIndex, &p.Status, &p.SeedID, &p.ReadyAt); err != nil {
			return nil, err
		}
		plots = append(plots, p.ToResponse())
	}

	if plots == nil {
		plots = []models.PlotResponse{}
	}

	return plots, nil
}

func SeedPlot(userID int, plotIndex int, seedID string) error {
	if plotIndex < 0 || plotIndex >= 16 {
		return utils.ErrCodeInvalidInput
	}

	item, err := GetItemByID(seedID)
	if err != nil || item.Type != models.ItemTypeSeed {
		return utils.ErrCodeInvalidInput
	}

	var status string
	err = db.DB.QueryRow("SELECT status FROM plots WHERE user_id = ? AND plot_index = ?", userID, plotIndex).Scan(&status)
	if err != nil {
		return err
	}
	if status != models.PlotStatusEmpty {
		return utils.ErrCodePlotNotEmpty
	}

	hasSeed, qty := HasItem(userID, seedID)
	if !hasSeed || qty < 1 {
		return utils.ErrCodeInvalidInput
	}
	if err := RemoveItem(userID, seedID, 1); err != nil {
		return err
	}

	_, err = db.DB.Exec(
		"UPDATE plots SET status = ?, seed_id = ?, ready_at = NULL WHERE user_id = ? AND plot_index = ?",
		models.PlotStatusSeeded, seedID, userID, plotIndex,
	)
	return err
}

func WaterPlot(userID int, plotIndex int) error {
	if plotIndex < 0 || plotIndex >= 16 {
		return utils.ErrCodeInvalidInput
	}

	var status, seedID string
	err := db.DB.QueryRow("SELECT status, seed_id FROM plots WHERE user_id = ? AND plot_index = ?", userID, plotIndex).Scan(&status, &seedID)
	if err != nil {
		return err
	}

	if status != models.PlotStatusSeeded {
		return utils.ErrCodePlotNotSeeded
	}

	item, err := GetItemByID(seedID)
	if err != nil {
		return err
	}

	growTime := 120
	if item.GrowTimeSeconds != nil {
		growTime = *item.GrowTimeSeconds
	}

	readyAt := time.Now().Add(time.Duration(growTime) * time.Second)

	_, err = db.DB.Exec(
		"UPDATE plots SET status = ?, ready_at = ? WHERE user_id = ? AND plot_index = ?",
		models.PlotStatusGrowing, readyAt, userID, plotIndex,
	)

	return err
}

func HarvestPlot(userID int, plotIndex int) (string, error) {
	if plotIndex < 0 || plotIndex >= 16 {
		return "", utils.ErrCodeInvalidInput
	}

	var status, seedID string
	var readyAt *time.Time
	err := db.DB.QueryRow("SELECT status, seed_id, ready_at FROM plots WHERE user_id = ? AND plot_index = ?", userID, plotIndex).Scan(&status, &seedID, &readyAt)
	if err != nil {
		return "", err
	}

	if status != models.PlotStatusReady {
		return "", utils.ErrCodePlotNotReady
	}

	harvestID := ""
	switch seedID {
	case "seed_carrot":
		harvestID = "harvest_carrot"
	case "seed_tomato":
		harvestID = "harvest_tomato"
	case "seed_corn":
		harvestID = "harvest_corn"
	}

	if harvestID == "" {
		return "", utils.ErrCodeInvalidInput
	}

	count, err := GetInventoryCount(userID)
	if err != nil {
		return "", err
	}

	hasItem, _ := HasItem(userID, harvestID)
	if count >= 20 && !hasItem {
		return "", utils.ErrCodeInventoryFull
	}

	if err := AddItem(userID, harvestID, 1); err != nil {
		return "", err
	}

	_, err = db.DB.Exec(
		"UPDATE plots SET status = ?, seed_id = NULL, ready_at = NULL WHERE user_id = ? AND plot_index = ?",
		models.PlotStatusEmpty, userID, plotIndex,
	)

	return harvestID, err
}

func StartFarmTicker() {
	ticker := time.NewTicker(5 * time.Second)
	go func() {
		for range ticker.C {
			checkAndUpdateReadyPlots()
		}
	}()
}

func checkAndUpdateReadyPlots() {
	now := time.Now()
	result, err := db.DB.Exec(
		"UPDATE plots SET status = 'READY' WHERE status = 'GROWING' AND ready_at <= ?",
		now,
	)
	if err != nil {
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected > 0 {
	}
}
