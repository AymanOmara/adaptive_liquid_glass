// Launch target for the Flutter side of the component-gap comparisons.
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'control_group_demo.dart' as cg;
import 'glass_transition_demo.dart' as gt;
import 'launch.dart';
import 'nav_subtitle_demo.dart' as ns;
import 'reference_twin.dart' as rt;
import 'split_view_demo.dart' as sv;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final args = await LaunchArgs.read();
  final twin = args.twin ?? Platform.environment['CAPTURE'];
  switch (twin) {
    case 'controlgroup':
      return cg.main();
    case 'transition':
      return gt.main();
    case 'split':
      return sv.main();
    case 'sidebarsplit':
    case 'sidebarsplitdark':
      return runApp(rt.ReferenceTwin(scene: twin!));
    default:
      return ns.main();
  }
}
