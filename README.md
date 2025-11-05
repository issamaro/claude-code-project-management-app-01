# Project Management Kanban Board

A beautiful, responsive kanban board application built with FastAPI and PicoCSS. Create tasks, organize them into columns, and drag cards between columns with smooth animations.

## Features

- **Drag & Drop**: Smoothly drag cards between columns with visual feedback
- **Task Management**: Create, edit, and delete tasks with titles and notes
- **Custom Columns**: Add new columns to organize your workflow
- **Beautiful UI**: Built with PicoCSS with a modern purple theme
- **Responsive Design**: Works great on desktop, tablet, and mobile
- **No Authentication**: Simple and straightforward - no login required
- **Persistent Storage**: All tasks are saved to SQLite database

## Setup Instructions

### Prerequisites
- Python 3.8+
- pip

### Installation

1. **Create and activate virtual environment:**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. **Install dependencies:**
```bash
pip install -r requirements.txt
```

3. **Run the application:**
```bash
python main.py
```

The application will be available at `http://localhost:8000`

## Usage

### Adding Tasks
1. Click the **"+ Add Task"** button in any column
2. Enter the task title and optional notes
3. Click **"Add Task"** to create it

### Editing Tasks
1. Click the **"Edit"** button on any card
2. Modify the title or notes
3. Click **"Update Task"** to save changes

### Deleting Tasks
1. Click the **"Delete"** button on any card
2. Confirm the deletion

### Moving Tasks
1. Click and drag any card to another column
2. The card will automatically update its position

### Adding Columns
1. Click the **"+ Add Column"** button in the header
2. Enter the column title
3. Click **"Add Column"** to create it

## Project Structure

```
vscode/
├── main.py                 # FastAPI application and routes
├── database.py             # SQLAlchemy models and database setup
├── requirements.txt        # Python dependencies
├── kanban.db              # SQLite database (auto-created)
├── static/
│   ├── css/
│   │   └── custom.css     # Custom PicoCSS theme and animations
│   └── js/
│       └── kanban.js      # Drag-drop functionality and API calls
└── templates/
    └── index.html         # Main kanban board template
```

## Technology Stack

- **Backend**: FastAPI with SQLAlchemy ORM
- **Frontend**: Jinja2 templates, PicoCSS, vanilla JavaScript
- **Database**: SQLite
- **Styling**: PicoCSS (minimalist CSS framework)

## API Endpoints

- `GET /` - Render kanban board page
- `GET /api/columns` - Get all columns with cards
- `POST /api/columns` - Create new column
- `POST /api/cards` - Create new card
- `PUT /api/cards/{id}` - Update card
- `PATCH /api/cards/{id}/move` - Move card between columns
- `DELETE /api/cards/{id}` - Delete card

## Customization

### Change the Theme Color

Edit `static/css/custom.css` and modify the CSS variables:

```css
:root {
    --pico-primary: #6c5ce7;  /* Change this to your color */
    --pico-primary-hover: #5f3dc4;
    --pico-primary-focus: rgba(108, 92, 231, 0.125);
}
```

### Add Default Columns

Edit `database.py` in the `init_db()` function to customize the default columns.

## Troubleshooting

### Port Already in Use
If port 8000 is already in use, you can change it in `main.py`:
```python
uvicorn.run(app, host="0.0.0.0", port=8001)  # Change port to 8001
```

### Database Issues
To reset the database, delete the `kanban.db` file and restart the application.

## License

This project is open source and available for use.
