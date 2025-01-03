import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> fieldWidgetJson = {
    'topic': 'Test/Field',
    'period': 0.100,
    'field_game': 'Crescendo',
    'robot_width': 1.0,
    'robot_length': 1.0,
    'show_other_objects': true,
    'show_trajectories': true,
    'field_rotation': 90.0,
    'robot_color': Colors.red.value,
    'trajectory_color': Colors.white.value,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUpAll(() async {
    await FieldImages.loadFields('assets/fields/');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Field/Robot',
          type: NT4TypeStr.kFloat64Arr,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Field/OtherObject',
          type: NT4TypeStr.kFloat64Arr,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Field/Robot': [5.0, 5.0, 270.0],
        'Test/Field/OtherObject': [1.0, 1.0, 0.0],
      },
    );
  });

  test('Field from json', () {
    NTWidgetModel fieldWidgetModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Field',
      fieldWidgetJson,
    );

    expect(fieldWidgetModel.type, 'Field');
    expect(fieldWidgetModel.runtimeType, FieldWidgetModel);

    if (fieldWidgetModel is! FieldWidgetModel) {
      return;
    }

    expect(fieldWidgetModel.robotWidthMeters, 1.0);
    expect(fieldWidgetModel.robotLengthMeters, 1.0);
    expect(fieldWidgetModel.showOtherObjects, isTrue);
    expect(fieldWidgetModel.showTrajectories, isTrue);
    expect(fieldWidgetModel.fieldRotation, 90.0);
    expect(fieldWidgetModel.robotColor.value, Colors.red.value);
    expect(fieldWidgetModel.trajectoryColor.value, Colors.white.value);
  });

  test('Field from alias json', () {
    NTWidgetModel fieldWidgetModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Field2d',
      fieldWidgetJson,
    );

    expect(fieldWidgetModel.type, 'Field');
    expect(fieldWidgetModel.runtimeType, FieldWidgetModel);

    if (fieldWidgetModel is! FieldWidgetModel) {
      return;
    }

    expect(fieldWidgetModel.robotWidthMeters, 1.0);
    expect(fieldWidgetModel.robotLengthMeters, 1.0);
    expect(fieldWidgetModel.showOtherObjects, isTrue);
    expect(fieldWidgetModel.showTrajectories, isTrue);
    expect(fieldWidgetModel.fieldRotation, 90.0);
    expect(fieldWidgetModel.robotColor.value, Colors.red.value);
    expect(fieldWidgetModel.trajectoryColor.value, Colors.white.value);
  });

  test('Field to json', () {
    FieldWidgetModel fieldWidgetModel = FieldWidgetModel(
      ntConnection: ntConnection,
      preferences: preferences,
      period: 0.100,
      topic: 'Test/Field',
      fieldGame: 'Crescendo',
      showOtherObjects: true,
      showTrajectories: true,
      robotWidthMeters: 1.0,
      robotLengthMeters: 1.0,
      fieldRotation: 90.0,
      robotColor: Colors.red,
      trajectoryColor: Colors.white,
    );

    expect(fieldWidgetModel.toJson(), fieldWidgetJson);
  });

  testWidgets('Field widget test (no trajectory)', (widgetTester) async {
    NTWidgetModel fieldWidgetModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Field',
      fieldWidgetJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: fieldWidgetModel,
            child: const FieldWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsNWidgets(3));
    expect(
        find.byWidgetPredicate((widget) =>
            widget is CustomPaint && widget.painter is TrajectoryPainter),
        findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Field widget test (with trajectory)', (widgetTester) async {
    List<double> fakeTrajectory = [];

    for (int i = 0; i < 16; i++) {
      fakeTrajectory.add(i * 0.25);
      fakeTrajectory.add(i * 0.25);
      fakeTrajectory.add(0.0);
    }

    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Field/Robot',
          type: NT4TypeStr.kFloat64Arr,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Field/OtherObject',
          type: NT4TypeStr.kFloat64Arr,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Field/Trajectory',
          type: NT4TypeStr.kFloat64Arr,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Field/Robot': [5.0, 5.0, 270.0],
        'Test/Field/OtherObject': [1.0, 1.0, 0.0],
        'Test/Field/Trajectory': fakeTrajectory,
      },
    );

    NTWidgetModel fieldWidgetModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Field',
      fieldWidgetJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: fieldWidgetModel,
            child: const FieldWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsNWidgets(4));
    expect(
        find.byWidgetPredicate((widget) =>
            widget is CustomPaint && widget.painter is TrajectoryPainter),
        findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Field widget edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    FieldWidgetModel fieldWidgetModel = FieldWidgetModel(
      ntConnection: ntConnection,
      preferences: preferences,
      period: 0.100,
      topic: 'Test/Field',
      fieldGame: 'Crescendo',
      showOtherObjects: true,
      showTrajectories: true,
      robotWidthMeters: 1.0,
      robotLengthMeters: 1.0,
      fieldRotation: 90.0,
      robotColor: Colors.red,
      trajectoryColor: Colors.white,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Field',
      childModel: fieldWidgetModel,
    );

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetContainerModel>.value(
            key: key,
            value: ntContainerModel,
            child: const DraggableNTWidgetContainer(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    ntContainerModel.showEditProperties(key.currentContext!);

    await widgetTester.pumpAndSettle();

    final game = find.byType(DialogDropdownChooser<String?>);
    final width = find.widgetWithText(DialogTextInput, 'Robot Width (meters)');
    final length =
        find.widgetWithText(DialogTextInput, 'Robot Length (meters)');
    final showNonRobot =
        find.widgetWithText(DialogToggleSwitch, 'Show Non-Robot Objects');
    final showTrajectories =
        find.widgetWithText(DialogToggleSwitch, 'Show Trajectories');
    final rotateLeft = find.ancestor(
      of: find.text('Rotate Left'),
      matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );
    final rotateRight = find.ancestor(
      of: find.text('Rotate Right'),
      matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );
    final robotColor = find.widgetWithText(DialogColorPicker, 'Robot Color');
    final trajectoryColor =
        find.widgetWithText(DialogColorPicker, 'Trajectory Color');

    expect(game, findsOneWidget);
    expect(width, findsOneWidget);
    expect(length, findsOneWidget);
    expect(showNonRobot, findsOneWidget);
    expect(showTrajectories, findsOneWidget);
    expect(rotateLeft, findsOneWidget);
    expect(rotateRight, findsOneWidget);
    expect(robotColor, findsOneWidget);
    expect(trajectoryColor, findsOneWidget);

    await widgetTester.ensureVisible(game);
    await widgetTester.tap(game);
    await widgetTester.pumpAndSettle();

    final chargedUpButton = find.text('Charged Up');
    expect(chargedUpButton, findsOneWidget);

    await widgetTester.tap(chargedUpButton);
    await widgetTester.pumpAndSettle();

    expect(fieldWidgetModel.field.game, 'Charged Up');

    await widgetTester.enterText(width, '0.50');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(fieldWidgetModel.robotWidthMeters, 0.5);

    await widgetTester.enterText(length, '0.50');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(fieldWidgetModel.robotLengthMeters, 0.5);

    await widgetTester.ensureVisible(showNonRobot);
    await widgetTester.tap(
      find.descendant(
        of: showNonRobot,
        matching: find.byType(Switch),
      ),
    );
    await widgetTester.pumpAndSettle();
    expect(fieldWidgetModel.showOtherObjects, false);

    await widgetTester.ensureVisible(showTrajectories);
    await widgetTester.tap(
      find.descendant(
        of: showTrajectories,
        matching: find.byType(Switch),
      ),
    );
    await widgetTester.pumpAndSettle();
    expect(fieldWidgetModel.showTrajectories, false);

    await widgetTester.tap(rotateRight);
    await widgetTester.pumpAndSettle();
    expect(fieldWidgetModel.fieldRotation, 180.0);

    await widgetTester.tap(rotateRight);
    await widgetTester.pumpAndSettle();
    expect(fieldWidgetModel.fieldRotation, -90.0);

    await widgetTester.tap(rotateLeft);
    await widgetTester.pumpAndSettle();
    expect(fieldWidgetModel.fieldRotation, -180.0);

    await widgetTester.tap(rotateLeft);
    await widgetTester.pumpAndSettle();
    expect(fieldWidgetModel.fieldRotation, 90.0);
  });
}
