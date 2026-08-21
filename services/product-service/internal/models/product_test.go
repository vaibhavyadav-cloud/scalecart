package models

import "testing"

func TestProductDefaults(t *testing.T) {
	p := Product{SKU: "SKU-1", PriceCents: 1999, Currency: "USD", StockQty: 10}
	if p.PriceCents <= 0 {
		t.Errorf("expected positive price, got %d", p.PriceCents)
	}
	if p.StockQty < 0 {
		t.Errorf("stock quantity must not be negative, got %d", p.StockQty)
	}
}
