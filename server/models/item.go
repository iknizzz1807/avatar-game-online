package models

type Item struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	Type            string `json:"type"` // 'seed', 'harvest', 'fishing_rod', 'bait', 'fish', 'clothing'
	BuyPrice        int    `json:"buy_price"`
	SellPrice       int    `json:"sell_price"`
	GrowTimeSeconds *int   `json:"grow_time_seconds,omitempty"` // NULL for non-seeds
	Stackable       bool   `json:"stackable"`
	MaxStack        int    `json:"max_stack"`
}

const (
	ItemTypeSeed       = "seed"
	ItemTypeHarvest    = "harvest"
	ItemTypeFishingRod = "fishing_rod"
	ItemTypeBait       = "bait"
	ItemTypeFish       = "fish"
	ItemTypeClothing   = "clothing"
)