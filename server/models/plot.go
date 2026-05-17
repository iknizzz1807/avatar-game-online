package models

import "time"

type Plot struct {
	ID         int        `json:"id"`
	UserID     int        `json:"user_id"`
	PlotIndex  int        `json:"plot_index"`
	Status     string     `json:"status"` // 'EMPTY', 'SEEDED', 'GROWING', 'READY'
	SeedID     *string    `json:"seed_id,omitempty"`
	ReadyAt   *time.Time `json:"ready_at,omitempty"`
}

const (
	PlotStatusEmpty   = "EMPTY"
	PlotStatusSeeded  = "SEEDED"
	PlotStatusGrowing = "GROWING"
	PlotStatusReady   = "READY"
)

type PlotResponse struct {
	PlotIndex int      `json:"plot_index"`
	Status    string   `json:"status"`
	SeedID    *string  `json:"seed_id,omitempty"`
	ReadyAt   *int64   `json:"ready_at,omitempty"`
}

func (p *Plot) ToResponse() PlotResponse {
	resp := PlotResponse{
		PlotIndex: p.PlotIndex,
		Status:    p.Status,
		SeedID:    p.SeedID,
	}
	if p.ReadyAt != nil {
		unix := p.ReadyAt.Unix()
		resp.ReadyAt = &unix
	}
	return resp
}