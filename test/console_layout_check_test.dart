import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waste_pro/main.dart';
import 'package:waste_pro/models/user_model.dart';
import 'package:waste_pro/providers/user_provider.dart';
import 'package:waste_pro/features/superadmin/data/platform_store.dart';
import 'package:waste_pro/features/superadmin/super_admin_console.dart';

class FakeUserProvider extends UserProvider {
  FakeUserProvider({this.fakeUser});

  final UserModel? fakeUser;

  @override
  UserModel? get user => fakeUser;

  @override
  bool get isLoading => false;
}

UserModel _sa() => UserModel(
      phoneNumber: '+237677123456',
      fullName: 'Super Admin',
      role: 'super_admin',
      password: 'x',
    );

void main() {
  Future<void> pumpConsole(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: FakeUserProvider(fakeUser: _sa()),
        child: WasteProApp(consoleStore: PlatformStore()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull,
        reason: 'exception pendant le rendu à $size');
  }

  testWidgets('console desktop : rendu sans débordement', (tester) async {
    await pumpConsole(tester, const Size(1440, 900));
    expect(find.byType(SuperAdminConsole), findsOneWidget);
    // Overview: the KPI cards + charts + activity are all there.
    expect(find.text('Active companies'), findsOneWidget);
    expect(find.text('New companies'), findsOneWidget);
  });

  testWidgets('console desktop : sociétés rendues sans débordement',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/console/societes';
    addTearDown(() {
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: FakeUserProvider(fakeUser: _sa()),
        child: WasteProApp(consoleStore: PlatformStore()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    expect(find.text('New company'), findsWidgets);
  });
}
