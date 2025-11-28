import 'package:flutter/material.dart';

class DynamicFieldControllers {
  final TextEditingController keyController;
  final TextEditingController valueController;

  DynamicFieldControllers()
      : keyController = TextEditingController(),
        valueController = TextEditingController();

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}
