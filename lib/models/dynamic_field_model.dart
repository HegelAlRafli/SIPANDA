import 'package:flutter/material.dart';

class DynamicFieldControllers {
  final TextEditingController keyController;
  final TextEditingController valueController;

  DynamicFieldControllers({
    TextEditingController? keyController,
    TextEditingController? valueController,
  }) : 
    keyController = keyController ?? TextEditingController(),
    valueController = valueController ?? TextEditingController();
}
