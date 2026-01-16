"""Main application window for 3D Human Motion Comparison System."""

from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QTabWidget, QStatusBar, QMenuBar, QMenu, QLabel
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QAction
import sys
import os


class MainWindow(QMainWindow):
    """Main application window with tabs for different views."""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("3D Human Motion Comparison System")
        self.setGeometry(100, 100, 1400, 900)
        
        # Load stylesheet
        self.load_stylesheet()
        
        # Create menu bar
        self.create_menu_bar()
        
        # Create central widget with tabs
        self.create_tabs()
        
        # Create status bar
        self.create_status_bar()
        
    def load_stylesheet(self):
        """Load Qt stylesheet from file."""
        style_path = os.path.join(os.path.dirname(__file__), 'styles.qss')
        if os.path.exists(style_path):
            with open(style_path, 'r') as f:
                self.setStyleSheet(f.read())
    
    def create_menu_bar(self):
        """Create application menu bar."""
        menubar = self.menuBar()
        
        # File menu
        file_menu = menubar.addMenu("&File")
        
        open_action = QAction("&Open Videos", self)
        open_action.setShortcut("Ctrl+O")
        file_menu.addAction(open_action)
        
        file_menu.addSeparator()
        
        exit_action = QAction("E&xit", self)
        exit_action.setShortcut("Ctrl+Q")
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)
        
        # View menu
        view_menu = menubar.addMenu("&View")
        
        viewer_action = QAction("&Exercise Viewer", self)
        viewer_action.setShortcut("Ctrl+1")
        viewer_action.triggered.connect(lambda: self.tabs.setCurrentIndex(0))
        view_menu.addAction(viewer_action)
        
        compare_action = QAction("&Comparison", self)
        compare_action.setShortcut("Ctrl+2")
        compare_action.triggered.connect(lambda: self.tabs.setCurrentIndex(1))
        view_menu.addAction(compare_action)
        
        # Help menu
        help_menu = menubar.addMenu("&Help")
        
        about_action = QAction("&About", self)
        about_action.triggered.connect(self.show_about)
        help_menu.addAction(about_action)
    
    def create_tabs(self):
        """Create tab widget with different views."""
        self.tabs = QTabWidget()
        self.tabs.setDocumentMode(True)
        
        # Tab 1: Exercise Viewer
        viewer_tab = QWidget()
        viewer_layout = QVBoxLayout()
        viewer_layout.addWidget(QLabel("Exercise Viewer - Coming Soon"))
        viewer_tab.setLayout(viewer_layout)
        self.tabs.addTab(viewer_tab, "📊 Exercise Viewer")
        
        # Tab 2: Comparison
        comparison_tab = QWidget()
        comparison_layout = QVBoxLayout()
        comparison_layout.addWidget(QLabel("Comparison View - Coming Soon"))
        comparison_tab.setLayout(comparison_layout)
        self.tabs.addTab(comparison_tab, "🔍 Comparison")
        
        # Tab 3: Upload
        upload_tab = QWidget()
        upload_layout = QVBoxLayout()
        upload_layout.addWidget(QLabel("Upload Videos - Coming Soon"))
        upload_tab.setLayout(upload_layout)
        self.tabs.addTab(upload_tab, "📤 Upload")
        
        self.setCentralWidget(self.tabs)
    
    def create_status_bar(self):
        """Create status bar."""
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("Ready")
    
    def show_about(self):
        """Show about dialog."""
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.about(
            self,
            "About 3D Motion Comparison",
            "3D Human Motion Comparison System\n\n"
            "Version 1.0\n"
            "Built with PySide6 and Plotly\n\n"
            "© 2026 Ikram - M2 PFE Project"
        )
    
    def update_status(self, message):
        """Update status bar message."""
        self.status_bar.showMessage(message)
