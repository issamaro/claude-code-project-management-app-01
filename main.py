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
from dotenv import load_dotenv
import os
from anthropic import Anthropic

# Load environment variables
load_dotenv()

# Initialize database
init_db()

# Initialize Anthropic client
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "claude-sonnet-4-5-20250929")
if ANTHROPIC_API_KEY:
    anthropic_client = Anthropic(api_key=ANTHROPIC_API_KEY)
else:
    anthropic_client = None

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


class UpdateColumnRequest(BaseModel):
    title: str
class ColumnPositionUpdate(BaseModel):
    id: int
    position: float


class ReorderColumnsRequest(BaseModel):
    columns: List[ColumnPositionUpdate]


# Routes
@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})


@app.get("/api/columns", response_model=List[ColumnSchema])
async def get_columns(db: Session = Depends(get_db)):
    """Get all columns with their cards."""
    columns = db.query(Column).order_by(Column.position).all()

    # Build result with properly serializable data
    result = []
    for col in columns:
        cards = db.query(Card).filter(Card.column_id == col.id).order_by(Card.position).all()
        result.append({
            "id": col.id,
            "title": col.title,
            "position": col.position,
            "cards": [
                {
                    "id": card.id,
                    "title": card.title,
                    "notes": card.notes,
                    "column_id": card.column_id,
                    "position": card.position,
                    "created_at": card.created_at
                }
                for card in cards
            ]
        })

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

    return {
        "id": new_column.id,
        "title": new_column.title,
        "position": new_column.position,
        "cards": []
    }


@app.put("/api/columns/{column_id}", response_model=ColumnSchema)
async def update_column(
    column_id: int, request: UpdateColumnRequest, db: Session = Depends(get_db)
):
    """Update a column's title."""
    column = db.query(Column).filter(Column.id == column_id).first()
    if not column:
        raise HTTPException(status_code=404, detail="Column not found")

    # Check if the new title is empty
    if not request.title or not request.title.strip():
        raise HTTPException(status_code=400, detail="Column title cannot be empty")

    # Check if another column already has this title
    existing_column = (
        db.query(Column)
        .filter(Column.title == request.title, Column.id != column_id)
        .first()
    )
    if existing_column:
        raise HTTPException(
            status_code=400, detail="A column with this title already exists"
        )

    column.title = request.title.strip()
    db.commit()
    db.refresh(column)

    # Get cards for response
    cards = db.query(Card).filter(Card.column_id == column.id).order_by(Card.position).all()

    return {
        "id": column.id,
        "title": column.title,
        "position": column.position,
        "cards": [
            {
                "id": card.id,
                "title": card.title,
                "notes": card.notes,
                "column_id": card.column_id,
                "position": card.position,
                "created_at": card.created_at,
            }
            for card in cards
        ],
    }


@app.delete("/api/columns/{column_id}")
async def delete_column(column_id: int, db: Session = Depends(get_db)):
    """Delete a column and move its cards to the leftmost column."""
    # Get the column to delete
    column = db.query(Column).filter(Column.id == column_id).first()
    if not column:
        raise HTTPException(status_code=404, detail="Column not found")

    # Check if this is the last column
    total_columns = db.query(Column).count()
    if total_columns <= 1:
        raise HTTPException(status_code=400, detail="Cannot delete the last column")

    # Get the leftmost column (first by position), excluding the column being deleted
    leftmost_column = db.query(Column).filter(Column.id != column_id).order_by(Column.position).first()

    # Move all cards from this column to the leftmost column
    cards = db.query(Card).filter(Card.column_id == column_id).all()
    max_position = db.query(func.max(Card.position)).filter(Card.column_id == leftmost_column.id).scalar()
    next_position = (max_position or 0) + 1.0

    for card in cards:
        card.column_id = leftmost_column.id
        card.position = next_position
        next_position += 1.0

    # Flush changes to database before deleting column
    db.flush()

    # Delete the column
    db.delete(column)
    db.commit()

    return {"message": f"Column deleted. {len(cards)} card(s) moved to {leftmost_column.title}"}


@app.patch("/api/columns/reorder")
async def reorder_columns(request: ReorderColumnsRequest, db: Session = Depends(get_db)):
    """Update the position of multiple columns."""
    try:
        for col_update in request.columns:
            column = db.query(Column).filter(Column.id == col_update.id).first()
            if column:
                column.position = col_update.position

        db.commit()
        return {"message": "Column order updated successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update column order: {str(e)}")


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

    return {
        "id": new_card.id,
        "title": new_card.title,
        "notes": new_card.notes,
        "column_id": new_card.column_id,
        "position": new_card.position,
        "created_at": new_card.created_at
    }


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

    return {
        "id": card.id,
        "title": card.title,
        "notes": card.notes,
        "column_id": card.column_id,
        "position": card.position,
        "created_at": card.created_at
    }


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

    return {
        "id": card.id,
        "title": card.title,
        "notes": card.notes,
        "column_id": card.column_id,
        "position": card.position,
        "created_at": card.created_at
    }


@app.delete("/api/cards/{card_id}")
async def delete_card(card_id: int, db: Session = Depends(get_db)):
    """Delete a card."""
    card = db.query(Card).filter(Card.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")

    db.delete(card)
    db.commit()
    return {"message": "Card deleted successfully"}


@app.post("/api/cards/{card_id}/generate-prompt")
async def generate_prompt(card_id: int, db: Session = Depends(get_db)):
    """Generate an AI prompt based on card title and notes, and append to notes."""
    if not anthropic_client:
        raise HTTPException(
            status_code=503,
            detail="AI feature not available. Please set ANTHROPIC_API_KEY environment variable."
        )

    card = db.query(Card).filter(Card.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")

    try:
        # Create prompt for Claude
        system_message = "You are a helpful assistant that generates concise, actionable implementation prompts for tasks. Generate a friendly, non-technical prompt that helps implement the given task well. Keep it brief (2-3 sentences max)."

        user_message = f"""Generate a concise implementation prompt for this task:

Title: {card.title}
Current notes: {card.notes if card.notes else 'None'}

Please provide a friendly, actionable prompt that can be used to implement this task."""

        # Call Claude API
        message = anthropic_client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=300,
            system=system_message,
            messages=[
                {"role": "user", "content": user_message}
            ]
        )

        # Extract the response
        generated_prompt = message.content[0].text

        # Append to card notes
        separator = "\n\n---\n" if card.notes else ""
        card.notes = f"{card.notes}{separator}💡 AI Prompt:\n{generated_prompt}"

        db.commit()
        db.refresh(card)

        return {
            "id": card.id,
            "title": card.title,
            "notes": card.notes,
            "column_id": card.column_id,
            "position": card.position,
            "created_at": card.created_at
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate prompt: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
