package models

import "time"

type FriendshipStatus string

const (
	FriendshipStatusNone     FriendshipStatus = "none"
	FriendshipStatusPending  FriendshipStatus = "pending"
	FriendshipStatusIncoming FriendshipStatus = "incoming"
	FriendshipStatusFriends  FriendshipStatus = "friends"
)

type FriendResponse struct {
	ID          int       `json:"id"`
	DisplayName string    `json:"display_name"`
	CurrentMap  string    `json:"current_map"`
	FriendsSince time.Time `json:"friends_since"`
}

type FriendRequestResponse struct {
	ID            int       `json:"id"`
	RequesterID   int       `json:"requester_id"`
	RequesterName string    `json:"requester_name"`
	TargetID      int       `json:"target_id"`
	TargetName    string    `json:"target_name"`
	Status        string    `json:"status"`
	CreatedAt     time.Time `json:"created_at"`
}
