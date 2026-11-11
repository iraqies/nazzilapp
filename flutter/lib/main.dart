import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'state/nazzil_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final controller = NazzilController();
  // The launch screen stays until the saved settings are read, so the first frame is
  // already in the user's language, theme and colour.
  await controller.settingsRead;
  runApp(NazzilApp(controller: controller));
}
