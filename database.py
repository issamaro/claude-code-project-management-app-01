from sqlalchemy import create_engine, Integer, String, Text, Float, DateTime, ForeignKey, Column as SAColumn
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
import os

# Database configuration
DATABASE_URL = "sqlite:///./kanban.db"

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


class Column(Base):
    __tablename__ = "columns"

    id = SAColumn(Integer, primary_key=True, index=True)
    title = SAColumn(String, index=True)
    position = SAColumn(Float, default=0.0)

    cards = relationship("Card", back_populates="column", cascade="all, delete-orphan")


class Card(Base):
    __tablename__ = "cards"

    id = SAColumn(Integer, primary_key=True, index=True)
    title = SAColumn(String, index=True)
    notes = SAColumn(Text, default="")
    column_id = SAColumn(Integer, ForeignKey("columns.id"), index=True)
    position = SAColumn(Float, default=0.0)
    created_at = SAColumn(DateTime, default=datetime.utcnow)

    column = relationship("Column", back_populates="cards")


def init_db():
    """Initialize the database and create default columns."""
    Base.metadata.create_all(bind=engine)

    # Check if columns already exist
    session = SessionLocal()
    try:
        existing_columns = session.query(Column).count()
        if existing_columns == 0:
            # Create default columns
            default_columns = [
                Column(title="TODO", position=0.0),
                Column(title="In Progress", position=1.0),
                Column(title="Completed", position=2.0),
            ]
            session.add_all(default_columns)
            session.commit()
    finally:
        session.close()


def get_db():
    """Dependency to get database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
