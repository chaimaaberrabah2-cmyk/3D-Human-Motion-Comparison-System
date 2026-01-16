"""Exercise selector widget for browsing and selecting exercises."""

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QListWidget,
    QComboBox, QLineEdit, QLabel, QPushButton, QGroupBox,
    QListWidgetItem
)
from PySide6.QtCore import Qt, Signal
from database.db_config import SessionLocal
from database.models import Exercise, Subject, ExerciseData


class ExerciseSelectorWidget(QWidget):
    """Widget for selecting exercises and subjects."""
    
    # Signal emitted when an exercise is selected
    exercise_selected = Signal(int, int)  # (exercise_data_id, num_frames)
    
    def __init__(self):
        super().__init__()
        self.db_session = SessionLocal()
        self.init_ui()
        self.load_data()
    
    def init_ui(self):
        """Initialize the user interface."""
        layout = QVBoxLayout()
        
        # Subject selector
        subject_group = QGroupBox("Subject")
        subject_layout = QVBoxLayout()
        self.subject_combo = QComboBox()
        self.subject_combo.currentIndexChanged.connect(self.on_subject_changed)
        subject_layout.addWidget(self.subject_combo)
        subject_group.setLayout(subject_layout)
        layout.addWidget(subject_group)
        
        # Exercise filter
        filter_group = QGroupBox("Filter")
        filter_layout = QVBoxLayout()
        
        # Category filter
        category_layout = QHBoxLayout()
        category_layout.addWidget(QLabel("Category:"))
        self.category_combo = QComboBox()
        self.category_combo.addItem("All Categories", None)
        self.category_combo.addItem("Warmup", "warmup")
        self.category_combo.addItem("Strength", "strength")
        self.category_combo.addItem("Cardio", "cardio")
        self.category_combo.addItem("General", "general")
        self.category_combo.currentIndexChanged.connect(self.filter_exercises)
        category_layout.addWidget(self.category_combo)
        filter_layout.addLayout(category_layout)
        
        # Search box
        search_layout = QHBoxLayout()
        search_layout.addWidget(QLabel("Search:"))
        self.search_box = QLineEdit()
        self.search_box.setPlaceholderText("Type to search exercises...")
        self.search_box.textChanged.connect(self.filter_exercises)
        search_layout.addWidget(self.search_box)
        filter_layout.addLayout(search_layout)
        
        filter_group.setLayout(filter_layout)
        layout.addWidget(filter_group)
        
        # Exercise list
        exercise_group = QGroupBox("Exercises")
        exercise_layout = QVBoxLayout()
        self.exercise_list = QListWidget()
        self.exercise_list.itemClicked.connect(self.on_exercise_clicked)
        exercise_layout.addWidget(self.exercise_list)
        exercise_group.setLayout(exercise_layout)
        layout.addWidget(exercise_group)
        
        # Load button
        self.load_button = QPushButton("Load Exercise")
        self.load_button.setEnabled(False)
        self.load_button.clicked.connect(self.on_load_clicked)
        layout.addWidget(self.load_button)
        
        # Info label
        self.info_label = QLabel("")
        self.info_label.setWordWrap(True)
        layout.addWidget(self.info_label)
        
        self.setLayout(layout)
        self.selected_exercise_data = None
    
    def load_data(self):
        """Load subjects and exercises from database."""
        try:
            # Load subjects
            subjects = self.db_session.query(Subject).order_by(Subject.subject_code).all()
            for subject in subjects:
                self.subject_combo.addItem(subject.subject_code, subject.id)
            
            # Load all exercises
            self.all_exercises = self.db_session.query(Exercise).order_by(Exercise.exercise_name).all()
            self.filter_exercises()
            
        except Exception as e:
            self.info_label.setText(f"Error loading data: {str(e)}")
    
    def on_subject_changed(self, index):
        """Handle subject selection change."""
        self.filter_exercises()
    
    def filter_exercises(self):
        """Filter exercises based on category and search text."""
        self.exercise_list.clear()
        
        category = self.category_combo.currentData()
        search_text = self.search_box.text().lower()
        
        for exercise in self.all_exercises:
            # Filter by category
            if category and exercise.category != category:
                continue
            
            # Filter by search text
            if search_text and search_text not in exercise.exercise_name.lower():
                continue
            
            # Add to list
            item = QListWidgetItem(f"{exercise.exercise_name} ({exercise.category})")
            item.setData(Qt.UserRole, exercise.id)
            self.exercise_list.addItem(item)
    
    def on_exercise_clicked(self, item):
        """Handle exercise selection."""
        exercise_id = item.data(Qt.UserRole)
        subject_id = self.subject_combo.currentData()
        
        if not subject_id:
            return
        
        # Query exercise data
        try:
            exercise_data = self.db_session.query(ExerciseData).filter_by(
                subject_id=subject_id,
                exercise_id=exercise_id
            ).first()
            
            if exercise_data:
                self.selected_exercise_data = exercise_data
                self.load_button.setEnabled(True)
                
                # Show info
                exercise = self.db_session.query(Exercise).get(exercise_id)
                subject = self.db_session.query(Subject).get(subject_id)
                self.info_label.setText(
                    f"Selected: {exercise.exercise_name}\n"
                    f"Subject: {subject.subject_code}\n"
                    f"Frames: {exercise_data.num_frames}\n"
                    f"Duration: {exercise_data.duration_seconds:.2f}s"
                )
            else:
                self.info_label.setText("No data available for this combination")
                self.load_button.setEnabled(False)
                
        except Exception as e:
            self.info_label.setText(f"Error: {str(e)}")
            self.load_button.setEnabled(False)
    
    def on_load_clicked(self):
        """Handle load button click."""
        if self.selected_exercise_data:
            self.exercise_selected.emit(
                self.selected_exercise_data.id,
                self.selected_exercise_data.num_frames
            )
    
    def closeEvent(self, event):
        """Clean up database session on close."""
        self.db_session.close()
        super().closeEvent(event)
