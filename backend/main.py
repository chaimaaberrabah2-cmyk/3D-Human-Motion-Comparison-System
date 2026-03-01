"""Main application entry point."""

import sys
from PySide6.QtWidgets import QApplication
from ui.main_window import MainWindow


def main():
    """Main application function."""
    app = QApplication(sys.argv)
    
    # Set application metadata
    app.setApplicationName("3D Motion Comparison")
    app.setOrganizationName("Ikram PFE")
    app.setApplicationVersion("1.0.0")
    
    # Create and show main window
    window = MainWindow()
    window.show()
    
    # Run application
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
