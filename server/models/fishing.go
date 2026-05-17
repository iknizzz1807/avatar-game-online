package models

import "time"

type FishingSession struct {
	ID         int       `json:"id"`
	UserID     int       `json:"user_id"`
	SeatIndex  int       `json:"seat_index"`
	StartedAt  time.Time `json:"started_at"`
	EndedAt    *time.Time `json:"ended_at,omitempty"`
}

type FishingStatusResponse struct {
	IsFishing   bool     `json:"is_fishing"`
	SeatIndex   *int     `json:"seat_index,omitempty"`
	Seats       []bool   `json:"seats"` // true if occupied
}

const MaxFishingSeats = 5