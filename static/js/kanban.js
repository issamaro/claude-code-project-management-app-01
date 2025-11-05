// State management
let columns = [];
let currentCardId = null;
let draggedCard = null;

// Elements
const kanbanBoard = document.getElementById('kanbanBoard');
const cardModal = document.getElementById('cardModal');
const columnModal = document.getElementById('columnModal');
const addColumnBtn = document.getElementById('addColumnBtn');
const cardForm = document.getElementById('cardForm');
const columnForm = document.getElementById('columnForm');
const cardTitle = document.getElementById('cardTitle');
const cardNotes = document.getElementById('cardNotes');

// Theme management
const THEME_KEY = 'kanban-theme';
const themeToggle = document.getElementById('themeToggle');
const themeIcon = document.getElementById('themeIcon');

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    initializeTheme();
    loadColumns();
    setupEventListeners();
});

// Theme functions
function initializeTheme() {
    // Get saved theme or default to light
    const savedTheme = localStorage.getItem(THEME_KEY) || 'light';
    setTheme(savedTheme);
}

function setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem(THEME_KEY, theme);
    updateThemeIcon(theme);
}

function updateThemeIcon(theme) {
    themeIcon.textContent = theme === 'dark' ? '☀️' : '🌙';
}

function toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    setTheme(newTheme);
}

// Event listeners
function setupEventListeners() {
    themeToggle.addEventListener('click', toggleTheme);

    addColumnBtn.addEventListener('click', () => {
        currentCardId = null;
        columnModal.showModal();
    });

    cardForm.addEventListener('submit', (e) => {
        e.preventDefault();
        if (currentCardId) {
            updateCard();
        } else {
            addCard();
        }
    });

    columnForm.addEventListener('submit', (e) => {
        e.preventDefault();
        addColumn();
    });

    // Close modals
    document.querySelectorAll('dialog button[rel="prev"]').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.target.closest('dialog').close();
        });
    });
}

// Load columns from API
async function loadColumns() {
    try {
        const response = await fetch('/api/columns');
        if (!response.ok) throw new Error('Failed to load columns');
        columns = await response.json();
        renderBoard();
    } catch (error) {
        showError('Failed to load kanban board: ' + error.message);
    }
}

// Render the kanban board
function renderBoard() {
    kanbanBoard.innerHTML = '';
    columns.forEach(column => {
        const columnEl = createColumnElement(column);
        kanbanBoard.appendChild(columnEl);
    });
}

// Create a column element
function createColumnElement(column) {
    const columnDiv = document.createElement('article');
    columnDiv.className = 'kanban-column';
    columnDiv.dataset.columnId = column.id;

    const header = document.createElement('div');
    header.className = 'column-header';
    header.innerHTML = `
        <h2>${escapeHtml(column.title)}</h2>
        <span class="card-count">${column.cards.length}</span>
    `;

    const cardsContainer = document.createElement('div');
    cardsContainer.className = 'cards-container';
    cardsContainer.dataset.columnId = column.id;

    if (column.cards.length === 0) {
        cardsContainer.classList.add('empty');
        cardsContainer.innerHTML = '<p>No tasks yet</p>';
    } else {
        column.cards.forEach(card => {
            const cardEl = createCardElement(card);
            cardsContainer.appendChild(cardEl);
        });
    }

    // Drag and drop events for cards container
    cardsContainer.addEventListener('dragover', (e) => {
        e.preventDefault();
        cardsContainer.classList.add('drop-active');
    });

    cardsContainer.addEventListener('dragleave', (e) => {
        if (e.target === cardsContainer) {
            cardsContainer.classList.remove('drop-active');
        }
    });

    cardsContainer.addEventListener('drop', (e) => {
        e.preventDefault();
        cardsContainer.classList.remove('drop-active');
        if (draggedCard) {
            moveCard(draggedCard.id, column.id);
        }
    });

    const addCardBtn = document.createElement('button');
    addCardBtn.className = 'add-card-btn';
    addCardBtn.innerHTML = '+ Add Task';
    addCardBtn.addEventListener('click', () => {
        currentCardId = null;
        cardTitle.value = '';
        cardNotes.value = '';
        document.getElementById('modalTitle').textContent = 'Add Task';
        document.getElementById('submitCardBtn').textContent = 'Add Task';
        // Store the current column ID for new card
        cardForm.dataset.columnId = column.id;
        cardModal.showModal();
    });

    columnDiv.appendChild(header);
    columnDiv.appendChild(cardsContainer);
    columnDiv.appendChild(addCardBtn);

    return columnDiv;
}

// Create a card element
function createCardElement(card) {
    const cardDiv = document.createElement('article');
    cardDiv.className = 'card';
    cardDiv.draggable = true;
    cardDiv.dataset.cardId = card.id;

    const title = document.createElement('p');
    title.className = 'card-title';
    title.textContent = card.title;

    const notesDiv = document.createElement('p');
    notesDiv.className = 'card-notes';
    notesDiv.textContent = card.notes || 'No notes';

    const footer = document.createElement('div');
    footer.className = 'card-footer';

    const editBtn = document.createElement('button');
    editBtn.className = 'card-btn-edit';
    editBtn.textContent = 'Edit';
    editBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        openEditCardModal(card);
    });

    const deleteBtn = document.createElement('button');
    deleteBtn.className = 'card-btn-delete';
    deleteBtn.textContent = 'Delete';
    deleteBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        deleteCard(card.id);
    });

    footer.appendChild(editBtn);
    footer.appendChild(deleteBtn);

    cardDiv.appendChild(title);
    if (card.notes) cardDiv.appendChild(notesDiv);
    cardDiv.appendChild(footer);

    // Drag events
    cardDiv.addEventListener('dragstart', (e) => {
        draggedCard = card;
        cardDiv.classList.add('dragging');
        e.dataTransfer.effectAllowed = 'move';
    });

    cardDiv.addEventListener('dragend', (e) => {
        cardDiv.classList.remove('dragging');
        document.querySelectorAll('.cards-container').forEach(c => {
            c.classList.remove('drop-active');
        });
    });

    return cardDiv;
}

// Add a new card
async function addCard() {
    const title = cardTitle.value.trim();
    const notes = cardNotes.value.trim();
    const columnId = parseInt(cardForm.dataset.columnId);

    if (!title) {
        showError('Please enter a task title');
        return;
    }

    try {
        const response = await fetch('/api/cards', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                title,
                notes,
                column_id: columnId
            })
        });

        if (!response.ok) throw new Error('Failed to create card');

        cardModal.close();
        cardForm.reset();
        await loadColumns();
        showSuccess('Task added successfully');
    } catch (error) {
        showError('Failed to add task: ' + error.message);
    }
}

// Open edit card modal
function openEditCardModal(card) {
    currentCardId = card.id;
    cardTitle.value = card.title;
    cardNotes.value = card.notes;
    document.getElementById('modalTitle').textContent = 'Edit Task';
    document.getElementById('submitCardBtn').textContent = 'Update Task';
    cardForm.dataset.columnId = card.column_id;
    cardModal.showModal();
}

// Update a card
async function updateCard() {
    const title = cardTitle.value.trim();
    const notes = cardNotes.value.trim();

    if (!title) {
        showError('Please enter a task title');
        return;
    }

    try {
        const response = await fetch(`/api/cards/${currentCardId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                title,
                notes
            })
        });

        if (!response.ok) throw new Error('Failed to update card');

        cardModal.close();
        cardForm.reset();
        currentCardId = null;
        await loadColumns();
        showSuccess('Task updated successfully');
    } catch (error) {
        showError('Failed to update task: ' + error.message);
    }
}

// Move a card to a different column
async function moveCard(cardId, columnId) {
    // Find the card to get its position in the new column
    const column = columns.find(c => c.id === columnId);
    if (!column) return;

    const position = column.cards.length + 1;

    try {
        const response = await fetch(`/api/cards/${cardId}/move?column_id=${columnId}&position=${position}`, {
            method: 'PATCH'
        });

        if (!response.ok) throw new Error('Failed to move card');

        draggedCard = null;
        await loadColumns();
    } catch (error) {
        showError('Failed to move card: ' + error.message);
    }
}

// Delete a card
async function deleteCard(cardId) {
    if (!confirm('Are you sure you want to delete this task?')) return;

    try {
        const response = await fetch(`/api/cards/${cardId}`, {
            method: 'DELETE'
        });

        if (!response.ok) throw new Error('Failed to delete card');

        await loadColumns();
        showSuccess('Task deleted successfully');
    } catch (error) {
        showError('Failed to delete task: ' + error.message);
    }
}

// Add a new column
async function addColumn() {
    const title = document.getElementById('columnTitle').value.trim();

    if (!title) {
        showError('Please enter a column title');
        return;
    }

    try {
        const response = await fetch('/api/columns', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ title })
        });

        if (!response.ok) throw new Error('Failed to create column');

        columnModal.close();
        columnForm.reset();
        await loadColumns();
        showSuccess('Column added successfully');
    } catch (error) {
        showError('Failed to add column: ' + error.message);
    }
}

// Utility functions
function showError(message) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-message';
    errorDiv.textContent = message;
    document.body.insertBefore(errorDiv, document.body.firstChild);
    setTimeout(() => errorDiv.remove(), 4000);
}

function showSuccess(message) {
    const successDiv = document.createElement('div');
    successDiv.className = 'success-message';
    successDiv.textContent = message;
    document.body.insertBefore(successDiv, document.body.firstChild);
    setTimeout(() => successDiv.remove(), 3000);
}

function escapeHtml(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, m => map[m]);
}
