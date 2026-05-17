package models

type InventoryItem struct {
	ID        int    `json:"id"`
	UserID    int    `json:"user_id"`
	ItemID    string `json:"item_id"`
	Quantity  int    `json:"quantity"`
	Item      *Item  `json:"item,omitempty"`
}

type InventoryResponse struct {
	ItemID   string `json:"item_id"`
	Name     string `json:"name"`
	Type     string `json:"type"`
	Quantity int    `json:"quantity"`
}