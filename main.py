from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import func
from pydantic import BaseModel
from database import Column, Card, init_db, get_db
from datetime import datetime
from typing import List, Optional

# Initialize database
init_db()

# Create FastAPI app
app = FastAPI(docs_url=None, redoc_url=None)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup templates
templates = Jinja2Templates(directory="templates")


# Pydantic models for request/response
class CardSchema(BaseModel):
    id: int
    title: str
    notes: str
    column_id: int
    position: float
    created_at: datetime

    class Config:
        from_attributes = True


class ColumnSchema(BaseModel):
    id: int
    title: str
    position: float
    cards: List[CardSchema] = []

    class Config:
        from_attributes = True


class CreateCardRequest(BaseModel):
    title: str
    column_id: int
    notes: Optional[str] = ""


class UpdateCardRequest(BaseModel):
    title: Optional[str] = None
    notes: Optional[str] = None
    column_id: Optional[int] = None
    position: Optional[float] = None


class CreateColumnRequest(BaseModel):
    title: str


# Routes
@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})


@app.get("/api/columns", response_model=List[ColumnSchema])
async def get_columns(db: Session = Depends(get_db)):
    """Get all columns with their cards."""
    columns = db.query(Column).order_by(Column.position).all()

    # Add cards to each column
    result = []
    for col in columns:
        cards = db.query(Card).filter(Card.column_id == col.id).order_by(Card.position).all()
        col.cards = cards
        result.append(col)

    return result


@app.post("/api/columns", response_model=ColumnSchema)
async def create_column(request: CreateColumnRequest, db: Session = Depends(get_db)):
    """Create a new column."""
    # Get the highest position
    max_position = db.query(func.max(Column.position)).scalar()
    new_position = (max_position or 0) + 1.0

    new_column = Column(title=request.title, position=new_position)
    db.add(new_column)
    db.commit()
    db.refresh(new_column)
    new_column.cards = []
    return new_column


@app.post("/api/cards", response_model=CardSchema)
async def create_card(request: CreateCardRequest, db: Session = Depends(get_db)):
    """Create a new card in a column."""
    # Verify column exists
    column = db.query(Column).filter(Column.id == request.column_id).first()
    if not column:
        raise HTTPException(status_code=404, detail="Column not found")

    # Get the highest position in the column
    max_position = db.query(func.max(Card.position)).filter(Card.column_id == request.column_id).scalar()
    new_position = (max_position or 0) + 1.0

    new_card = Card(
        title=request.title,
        notes=request.notes or "",
        column_id=request.column_id,
        position=new_position,
    )
    db.add(new_card)
    db.commit()
    db.refresh(new_card)
    return new_card


@app.put("/api/cards/{card_id}", response_model=CardSchema)
async def update_card(
    card_id: int, request: UpdateCardRequest, db: Session = Depends(get_db)
):
    """Update a card's title or notes."""
    card = db.query(Card).filter(Card.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")

    if request.title is not None:
        card.title = request.title
    if request.notes is not None:
        card.notes = request.notes
    if request.column_id is not None:
        # Verify column exists
        column = db.query(Column).filter(Column.id == request.column_id).first()
        if not column:
            raise HTTPException(status_code=404, detail="Column not found")
        card.column_id = request.column_id
    if request.position is not None:
        card.position = request.position

    db.commit()
    db.refresh(card)
    return card


@app.patch("/api/cards/{card_id}/move")
async def move_card(
    card_id: int,
    column_id: int,
    position: float,
    db: Session = Depends(get_db),
):
    """Move a card to a different column and/or position."""
    card = db.query(Card).filter(Card.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")

    # Verify column exists
    column = db.query(Column).filter(Column.id == column_id).first()
    if not column:
        raise HTTPException(status_code=404, detail="Column not found")

    card.column_id = column_id
    card.position = position

    db.commit()
    db.refresh(card)
    return card


@app.delete("/api/cards/{card_id}")
async def delete_card(card_id: int, db: Session = Depends(get_db)):
    """Delete a card."""
    card = db.query(Card).filter(Card.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")

    db.delete(card)
    db.commit()
    return {"message": "Card deleted successfully"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
