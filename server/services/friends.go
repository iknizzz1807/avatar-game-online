package services

import (
	"database/sql"

	"github.com/avatar-game/server/db"
	"github.com/avatar-game/server/models"
	"github.com/avatar-game/server/utils"
)

func SendFriendRequest(requesterID int, targetID int) (*models.FriendRequestResponse, error) {
	if requesterID <= 0 || targetID <= 0 || requesterID == targetID {
		return nil, utils.ErrCodeInvalidInput
	}
	if _, err := GetUserByID(targetID); err != nil {
		return nil, utils.ErrCodeUserNotFound
	}

	existing, err := findFriendship(requesterID, targetID)
	if err == nil {
		if existing.Status == "accepted" {
			return existing, nil
		}
		if existing.RequesterID == targetID && existing.TargetID == requesterID {
			return AcceptFriendRequest(requesterID, existing.ID)
		}
		return existing, nil
	}
	if err != sql.ErrNoRows {
		return nil, err
	}

	result, err := db.DB.Exec(`
		INSERT INTO friendships (requester_id, target_id, status)
		VALUES (?, ?, 'pending')
	`, requesterID, targetID)
	if err != nil {
		return nil, err
	}
	id, _ := result.LastInsertId()
	return getFriendRequestByID(int(id))
}

func AcceptFriendRequest(userID int, requestID int) (*models.FriendRequestResponse, error) {
	result, err := db.DB.Exec(`
		UPDATE friendships
		SET status = 'accepted', updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND target_id = ? AND status = 'pending'
	`, requestID, userID)
	if err != nil {
		return nil, err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return nil, utils.ErrCodeInvalidInput
	}
	return getFriendRequestByID(requestID)
}

func DeclineFriendRequest(userID int, requestID int) error {
	result, err := db.DB.Exec(`
		DELETE FROM friendships
		WHERE id = ? AND target_id = ? AND status = 'pending'
	`, requestID, userID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return utils.ErrCodeInvalidInput
	}
	return nil
}

func RemoveFriend(userID int, friendID int) error {
	result, err := db.DB.Exec(`
		DELETE FROM friendships
		WHERE status = 'accepted'
		AND ((requester_id = ? AND target_id = ?) OR (requester_id = ? AND target_id = ?))
	`, userID, friendID, friendID, userID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return utils.ErrCodeInvalidInput
	}
	return nil
}

func GetFriends(userID int) ([]models.FriendResponse, error) {
	rows, err := db.DB.Query(`
		SELECT u.id, u.display_name, u.current_map, f.updated_at
		FROM friendships f
		JOIN users u ON u.id = CASE WHEN f.requester_id = ? THEN f.target_id ELSE f.requester_id END
		WHERE f.status = 'accepted' AND (f.requester_id = ? OR f.target_id = ?)
		ORDER BY u.display_name
	`, userID, userID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	friends := []models.FriendResponse{}
	for rows.Next() {
		var friend models.FriendResponse
		if err := rows.Scan(&friend.ID, &friend.DisplayName, &friend.CurrentMap, &friend.FriendsSince); err != nil {
			return nil, err
		}
		friends = append(friends, friend)
	}
	return friends, rows.Err()
}

func GetIncomingFriendRequests(userID int) ([]models.FriendRequestResponse, error) {
	rows, err := db.DB.Query(`
		SELECT f.id, f.requester_id, ru.display_name, f.target_id, tu.display_name, f.status, f.created_at
		FROM friendships f
		JOIN users ru ON ru.id = f.requester_id
		JOIN users tu ON tu.id = f.target_id
		WHERE f.target_id = ? AND f.status = 'pending'
		ORDER BY f.created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	requests := []models.FriendRequestResponse{}
	for rows.Next() {
		var req models.FriendRequestResponse
		if err := rows.Scan(&req.ID, &req.RequesterID, &req.RequesterName, &req.TargetID, &req.TargetName, &req.Status, &req.CreatedAt); err != nil {
			return nil, err
		}
		requests = append(requests, req)
	}
	return requests, rows.Err()
}

func GetFriendshipStatus(viewerID int, otherID int) (models.FriendshipStatus, error) {
	if viewerID <= 0 || otherID <= 0 || viewerID == otherID {
		return models.FriendshipStatusNone, nil
	}
	friendship, err := findFriendship(viewerID, otherID)
	if err == sql.ErrNoRows {
		return models.FriendshipStatusNone, nil
	}
	if err != nil {
		return models.FriendshipStatusNone, err
	}
	if friendship.Status == "accepted" {
		return models.FriendshipStatusFriends, nil
	}
	if friendship.RequesterID == viewerID {
		return models.FriendshipStatusPending, nil
	}
	return models.FriendshipStatusIncoming, nil
}

func findFriendship(userA int, userB int) (*models.FriendRequestResponse, error) {
	var id int
	err := db.DB.QueryRow(`
		SELECT id FROM friendships
		WHERE (requester_id = ? AND target_id = ?) OR (requester_id = ? AND target_id = ?)
		ORDER BY id DESC LIMIT 1
	`, userA, userB, userB, userA).Scan(&id)
	if err != nil {
		return nil, err
	}
	return getFriendRequestByID(id)
}

func getFriendRequestByID(id int) (*models.FriendRequestResponse, error) {
	var req models.FriendRequestResponse
	err := db.DB.QueryRow(`
		SELECT f.id, f.requester_id, ru.display_name, f.target_id, tu.display_name, f.status, f.created_at
		FROM friendships f
		JOIN users ru ON ru.id = f.requester_id
		JOIN users tu ON tu.id = f.target_id
		WHERE f.id = ?
	`, id).Scan(&req.ID, &req.RequesterID, &req.RequesterName, &req.TargetID, &req.TargetName, &req.Status, &req.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &req, nil
}
