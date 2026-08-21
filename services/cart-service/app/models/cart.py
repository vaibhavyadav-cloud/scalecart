from pydantic import BaseModel, Field


class CartItem(BaseModel):
    product_id: str
    name: str
    price_cents: int = Field(ge=0)
    quantity: int = Field(ge=1)


class Cart(BaseModel):
    user_id: str
    items: list[CartItem] = []

    @property
    def total_cents(self) -> int:
        return sum(item.price_cents * item.quantity for item in self.items)
