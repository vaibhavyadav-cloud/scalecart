import json
from fastapi import APIRouter, Depends, HTTPException
from redis import Redis
from app.redis_client import get_redis
from app.models.cart import Cart, CartItem

router = APIRouter(prefix="/cart")

# Carts expire after 7 days of inactivity - matches the CronJob in
# k8s/base/cronjob-cart-cleanup.yaml, which is a belt-and-suspenders sweep
# for any keys that somehow bypass the TTL (e.g. set via a buggy client).
CART_TTL_SECONDS = 7 * 24 * 60 * 60


def _key(user_id: str) -> str:
    return f"cart:{user_id}"


@router.get("/{user_id}")
def get_cart(user_id: str, r: Redis = Depends(get_redis)) -> Cart:
    raw = r.get(_key(user_id))
    if not raw:
        return Cart(user_id=user_id, items=[])
    return Cart(user_id=user_id, items=json.loads(raw))


@router.post("/{user_id}/items")
def add_item(user_id: str, item: CartItem, r: Redis = Depends(get_redis)) -> Cart:
    key = _key(user_id)
    raw = r.get(key)
    items = [CartItem(**i) for i in json.loads(raw)] if raw else []

    for existing in items:
        if existing.product_id == item.product_id:
            existing.quantity += item.quantity
            break
    else:
        items.append(item)

    cart = Cart(user_id=user_id, items=items)
    r.set(key, json.dumps([i.model_dump() for i in items]), ex=CART_TTL_SECONDS)
    return cart


@router.delete("/{user_id}/items/{product_id}")
def remove_item(user_id: str, product_id: str, r: Redis = Depends(get_redis)) -> Cart:
    key = _key(user_id)
    raw = r.get(key)
    if not raw:
        raise HTTPException(status_code=404, detail="cart_not_found")

    items = [CartItem(**i) for i in json.loads(raw) if i["product_id"] != product_id]
    r.set(key, json.dumps([i.model_dump() for i in items]), ex=CART_TTL_SECONDS)
    return Cart(user_id=user_id, items=items)


@router.delete("/{user_id}")
def clear_cart(user_id: str, r: Redis = Depends(get_redis)):
    r.delete(_key(user_id))
    return {"status": "cleared"}
