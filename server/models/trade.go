package models

type TradeStatus string

const (
	TradeStatusPending   TradeStatus = "pending"
	TradeStatusActive    TradeStatus = "active"
	TradeStatusCompleted TradeStatus = "completed"
	TradeStatusCanceled  TradeStatus = "canceled"
)

type TradeItemRequest struct {
	ItemID   string `json:"item_id"`
	Quantity int    `json:"quantity"`
}

type TradeItemResponse struct {
	ItemID   string `json:"item_id"`
	Name     string `json:"name"`
	Type     string `json:"type"`
	Quantity int    `json:"quantity"`
}

type TradeSessionResponse struct {
	ID             int                 `json:"id"`
	RequesterID    int                 `json:"requester_id"`
	RequesterName  string              `json:"requester_name"`
	TargetID       int                 `json:"target_id"`
	TargetName     string              `json:"target_name"`
	Status         TradeStatus         `json:"status"`
	RequesterReady bool                `json:"requester_ready"`
	TargetReady    bool                `json:"target_ready"`
	MyRole         string              `json:"my_role"`
	MyOffer        []TradeItemResponse `json:"my_offer"`
	TheirOffer     []TradeItemResponse `json:"their_offer"`
}
