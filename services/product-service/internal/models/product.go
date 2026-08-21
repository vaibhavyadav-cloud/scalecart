package models

// Product is stored in MongoDB rather than Postgres on purpose: catalog
// documents are read-heavy, have a variable/nested shape per category
// (electronics have "warranty_months", clothing has "size" arrays, etc.),
// and don't need cross-row transactions - a document model fits better
// than forcing every product variant into a rigid relational schema.
// See docs/03-databases-per-service.md.
type Product struct {
	ID          string   `bson:"_id,omitempty" json:"id"`
	SKU         string   `bson:"sku" json:"sku"`
	Name        string   `bson:"name" json:"name"`
	Description string   `bson:"description" json:"description"`
	PriceCents  int64    `bson:"price_cents" json:"priceCents"`
	Currency    string   `bson:"currency" json:"currency"`
	Category    string   `bson:"category" json:"category"`
	Tags        []string `bson:"tags" json:"tags"`
	StockQty    int      `bson:"stock_qty" json:"stockQty"`
}
