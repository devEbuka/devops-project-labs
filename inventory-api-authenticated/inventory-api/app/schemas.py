from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, ConfigDict, Field


class ProductCreate(BaseModel):
    sku: str = Field(min_length=1, max_length=64)
    name: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=1000)
    price: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    quantity: int = Field(default=0, ge=0)


class ProductUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=1000)
    price: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=2)


class ProductOut(ProductCreate):
    id: int
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)


class StockAdjust(BaseModel):
    delta: int = Field(description="Non-zero change in stock")
    reason: str | None = Field(default=None, max_length=250)


class StockMovementOut(BaseModel):
    id: int
    product_id: int
    delta: int
    resulting_quantity: int
    reason: str | None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)
