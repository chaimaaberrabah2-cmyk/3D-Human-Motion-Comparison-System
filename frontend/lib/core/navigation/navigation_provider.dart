import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  
  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void setIndexByRoute(String route) {
    if (route == '/') setIndex(0);
    else if (route == '/history') setIndex(1);
    else if (route == '/settings') setIndex(2);
    else if (route == '/new_analysis') setIndex(3);
  }
}
