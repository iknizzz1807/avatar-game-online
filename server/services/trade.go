package services

import (
	"database/sql"

	"github.com/avatar-game/server/db"
	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/utils"
)

func CreateTradeRequest(requesterID int, targetID int) (*models.TradeSessionResponse, error) {
	if requesterID <= 0 || targetID <= 0 || requesterID == targetID {
		return nil, utils.ErrCodeInvalidInput
	}
	if _, err := GetUserByID(targetID); err != nil {
		return nil, utils.ErrCodeUserNotFound
	}

	var existingID int
	err := db.DB.QueryRow(`
		SELECT id FROM trade_sessions
		WHERE status IN ('pending', 'active')
		AND ((requester_id = ? AND target_id = ?) OR (requester_id = ? AND target_id = ?))
		ORDER BY id DESC LIMIT 1
	`, requesterID, targetID, targetID, requesterID).Scan(&existingID)
	if err == nil {
		return GetTradeSession(requesterID, existingID)
	}
	if err != sql.ErrNoRows {
		return nil, err
	}

	var busyID int
	err = db.DB.QueryRow(`
		SELECT id FROM trade_sessions
		WHERE status IN ('pending', 'active')
		AND (requester_id = ? OR target_id = ? OR requester_id = ? OR target_id = ?)
		ORDER BY id DESC LIMIT 1
	`, requesterID, requesterID, targetID, targetID).Scan(&busyID)
	if err == nil {
		return nil, utils.ErrCodeInvalidInput
	}
	if err != sql.ErrNoRows {
		return nil, err
	}

	result, err := db.DB.Exec(`
		INSERT INTO trade_sessions (requester_id, target_id, status)
		VALUES (?, ?, ?)
	`, requesterID, targetID, models.TradeStatusPending)
	if err != nil {
		return nil, err
	}
	id, _ := result.LastInsertId()
	return GetTradeSession(requesterID, int(id))
}

func GetActiveTrade(userID int) (*models.TradeSessionResponse, error) {
	var id int
	err := db.DB.QueryRow(`
		SELECT id FROM trade_sessions
		WHERE status IN ('pending', 'active') AND (requester_id = ? OR target_id = ?)
		ORDER BY id DESC LIMIT 1
	`, userID, userID).Scan(&id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return GetTradeSession(userID, id)
}

func GetTradeSession(viewerID int, sessionID int) (*models.TradeSessionResponse, error) {
	var session models.TradeSessionResponse
	var requesterReady int
	var targetReady int
	err := db.DB.QueryRow(`
		SELECT ts.id, ts.requester_id, ru.display_name, ts.target_id, tu.display_name,
			ts.status, ts.requester_ready, ts.target_ready
		FROM trade_sessions ts
		JOIN users ru ON ru.id = ts.requester_id
		JOIN users tu ON tu.id = ts.target_id
		WHERE ts.id = ?
	`, sessionID).Scan(
		&session.ID,
		&session.RequesterID,
		&session.RequesterName,
		&session.TargetID,
		&session.TargetName,
		&session.Status,
		&requesterReady,
		&targetReady,
	)
	if err != nil {
		return nil, err
	}
	if viewerID != session.RequesterID && viewerID != session.TargetID {
		return nil, utils.ErrCodeUnauthorized
	}

	session.RequesterReady = requesterReady == 1
	session.TargetReady = targetReady == 1
	session.MyRole = "target"
	myID := session.TargetID
	theirID := session.RequesterID
	if viewerID == session.RequesterID {
		session.MyRole = "requester"
		myID = session.RequesterID
		theirID = session.TargetID
	}

	myOffer, err := getTradeItems(session.ID, myID)
	if err != nil {
		return nil, err
	}
	theirOffer, err := getTradeItems(session.ID, theirID)
	if err != nil {
		return nil, err
	}
	session.MyOffer = myOffer
	session.TheirOffer = theirOffer
	return &session, nil
}

func AcceptTrade(userID int, sessionID int) (*models.TradeSessionResponse, error) {
	tx, err := db.DB.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var targetID int
	var status string
	if err := tx.QueryRow("SELECT target_id, status FROM trade_sessions WHERE id = ?", sessionID).Scan(&targetID, &status); err != nil {
		return nil, err
	}
	if targetID != userID || status != string(models.TradeStatusPending) {
		return nil, utils.ErrCodeInvalidInput
	}
	if _, err := tx.Exec(`
		UPDATE trade_sessions
		SET status = ?, requester_ready = 0, target_ready = 0, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`, models.TradeStatusActive, sessionID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return GetTradeSession(userID, sessionID)
}

func CancelTrade(userID int, sessionID int) error {
	result, err := db.DB.Exec(`
		UPDATE trade_sessions
		SET status = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND status IN ('pending', 'active') AND (requester_id = ? OR target_id = ?)
	`, models.TradeStatusCanceled, sessionID, userID, userID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return utils.ErrCodeInvalidInput
	}
	return nil
}

func SetTradeOffer(userID int, sessionID int, items []models.TradeItemRequest) (*models.TradeSessionResponse, error) {
	tx, err := db.DB.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if err := ensureActiveParticipantTx(tx, userID, sessionID); err != nil {
		return nil, err
	}

	merged := map[string]int{}
	for _, item := range items {
		if item.ItemID == "" || item.Quantity <= 0 {
			return nil, utils.ErrCodeInvalidInput
		}
		merged[item.ItemID] += item.Quantity
	}
	for itemID, quantity := range merged {
		has, owned, err := hasItemTx(tx, userID, itemID)
		if err != nil {
			return nil, err
		}
		if !has || owned < quantity {
			return nil, utils.ErrCodeInvalidInput
		}
	}

	if _, err := tx.Exec("DELETE FROM trade_items WHERE session_id = ? AND user_id = ?", sessionID, userID); err != nil {
		return nil, err
	}
	for itemID, quantity := range merged {
		if _, err := tx.Exec(`
			INSERT INTO trade_items (session_id, user_id, item_id, quantity)
			VALUES (?, ?, ?, ?)
		`, sessionID, userID, itemID, quantity); err != nil {
			return nil, err
		}
	}
	if _, err := tx.Exec(`
		UPDATE trade_sessions
		SET requester_ready = 0, target_ready = 0, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`, sessionID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return GetTradeSession(userID, sessionID)
}

func SetTradeReady(userID int, sessionID int, ready bool) (*models.TradeSessionResponse, error) {
	tx, err := db.DB.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var requesterID int
	var targetID int
	var status string
	var requesterReady int
	var targetReady int
	if err := tx.QueryRow(`
		SELECT requester_id, target_id, status, requester_ready, target_ready
		FROM trade_sessions WHERE id = ?
	`, sessionID).Scan(&requesterID, &targetID, &status, &requesterReady, &targetReady); err != nil {
		return nil, err
	}
	if status != string(models.TradeStatusActive) || (userID != requesterID && userID != targetID) {
		return nil, utils.ErrCodeInvalidInput
	}

	readyValue := 0
	if ready {
		readyValue = 1
	}
	column := "target_ready"
	if userID == requesterID {
		column = "requester_ready"
	}
	if _, err := tx.Exec("UPDATE trade_sessions SET "+column+" = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", readyValue, sessionID); err != nil {
		return nil, err
	}

	if userID == requesterID {
		requesterReady = readyValue
	} else {
		targetReady = readyValue
	}
	if requesterReady == 1 && targetReady == 1 {
		if err := completeTradeTx(tx, sessionID, requesterID, targetID); err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return GetTradeSession(userID, sessionID)
}

func getTradeItems(sessionID int, userID int) ([]models.TradeItemResponse, error) {
	rows, err := db.DB.Query(`
		SELECT ti.item_id, it.name, it.type, ti.quantity
		FROM trade_items ti
		JOIN items it ON it.id = ti.item_id
		WHERE ti.session_id = ? AND ti.user_id = ?
		ORDER BY ti.id
	`, sessionID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []models.TradeItemResponse{}
	for rows.Next() {
		var item models.TradeItemResponse
		if err := rows.Scan(&item.ItemID, &item.Name, &item.Type, &item.Quantity); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func ensureActiveParticipantTx(tx *sql.Tx, userID int, sessionID int) error {
	var status string
	var requesterID int
	var targetID int
	if err := tx.QueryRow(`
		SELECT status, requester_id, target_id FROM trade_sessions WHERE id = ?
	`, sessionID).Scan(&status, &requesterID, &targetID); err != nil {
		return err
	}
	if status != string(models.TradeStatusActive) || (userID != requesterID && userID != targetID) {
		return utils.ErrCodeInvalidInput
	}
	return nil
}

func completeTradeTx(tx *sql.Tx, sessionID int, requesterID int, targetID int) error {
	requesterItems, err := getTradeItemsTx(tx, sessionID, requesterID)
	if err != nil {
		return err
	}
	targetItems, err := getTradeItemsTx(tx, sessionID, targetID)
	if err != nil {
		return err
	}

	for _, item := range requesterItems {
		has, owned, err := hasItemTx(tx, requesterID, item.ItemID)
		if err != nil {
			return err
		}
		if !has || owned < item.Quantity {
			return utils.ErrCodeInvalidInput
		}
	}
	for _, item := range targetItems {
		has, owned, err := hasItemTx(tx, targetID, item.ItemID)
		if err != nil {
			return err
		}
		if !has || owned < item.Quantity {
			return utils.ErrCodeInvalidInput
		}
	}

	for _, item := range requesterItems {
		if err := removeItemTx(tx, requesterID, item.ItemID, item.Quantity); err != nil {
			return err
		}
	}
	for _, item := range targetItems {
		if err := removeItemTx(tx, targetID, item.ItemID, item.Quantity); err != nil {
			return err
		}
	}
	for _, item := range requesterItems {
		if err := addItemTx(tx, targetID, item.ItemID, item.Quantity); err != nil {
			return err
		}
	}
	for _, item := range targetItems {
		if err := addItemTx(tx, requesterID, item.ItemID, item.Quantity); err != nil {
			return err
		}
	}

	_, err = tx.Exec(`
		UPDATE trade_sessions
		SET status = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`, models.TradeStatusCompleted, sessionID)
	return err
}

func getTradeItemsTx(tx *sql.Tx, sessionID int, userID int) ([]models.TradeItemRequest, error) {
	rows, err := tx.Query(`
		SELECT item_id, quantity FROM trade_items
		WHERE session_id = ? AND user_id = ?
	`, sessionID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []models.TradeItemRequest{}
	for rows.Next() {
		var item models.TradeItemRequest
		if err := rows.Scan(&item.ItemID, &item.Quantity); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}
