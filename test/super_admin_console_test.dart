import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/features/superadmin/super_admin_console.dart';

void main() {
  Future<void> pumpConsole(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SuperAdminConsole()));
    // Let the KPI skeleton timers fire.
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('console renders brand, navigation and dashboard KPIs', (
    tester,
  ) async {
    await pumpConsole(tester);

    // Brand appears as a rich text (also present in the agency chart labels,
    // so we only assert the sidebar-specific texts here).
    expect(find.text('CONSOLE PLATEFORME'), findsOneWidget);
    expect(find.text('Super Admin'), findsOneWidget);

    // Navigation items (labels also appear as KPI labels, hence findsWidgets)
    expect(find.text('Sociétés'), findsOneWidget);
    expect(find.text('Agences'), findsWidgets);
    expect(find.text('Utilisateurs'), findsWidgets);

    // Dashboard KPIs
    expect(find.text('Sociétés actives'), findsOneWidget);
    expect(find.text('Disponibilité plateforme'), findsOneWidget);

    // Mock data appears in the activity feed
    expect(find.text('Activité plateforme'), findsOneWidget);
  });

  testWidgets('creates a société through the drawer and shows it in the table', (
    tester,
  ) async {
    await pumpConsole(tester);

    // Navigate to Sociétés
    await tester.tap(find.text('Sociétés'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle société'), findsOneWidget);

    // Open the create drawer
    await tester.tap(find.text('Nouvelle société'));
    await tester.pumpAndSettle();
    expect(find.text('Raison sociale'), findsOneWidget);

    // Fill the form and save
    await tester.enterText(find.byType(TextFormField).at(0), 'Test SARL');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // The new company is visible in the table + toast shown
    expect(find.text('Test SARL'), findsOneWidget);

    // Flush the toast auto-dismiss timer.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('blocks saving a société with an empty required field', (
    tester,
  ) async {
    await pumpConsole(tester);

    await tester.tap(find.text('Sociétés'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle société'));
    await tester.pumpAndSettle();

    // Save without filling the "Raison sociale" field.
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // An error toast is shown and the drawer stays open for a retry.
    expect(
      find.text('Le champ « Raison sociale » est obligatoire.'),
      findsOneWidget,
    );
    expect(find.text('Raison sociale'), findsOneWidget);

    // Flush the toast auto-dismiss timer.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('blocks deleting a société that still has agences', (
    tester,
  ) async {
    await pumpConsole(tester);

    await tester.tap(find.text('Sociétés'));
    await tester.pumpAndSettle();

    // 'Propre237 Douala SARL' has 2 attached agences (seed data): its
    // delete action is blocked with an explanatory toast, no confirm dialog.
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cette société ?'), findsNothing);
    expect(find.textContaining('Impossible de supprimer'), findsOneWidget);
    expect(find.text('Propre237 Douala SARL'), findsWidgets);

    // Flush the toast auto-dismiss timer.
    await tester.pump(const Duration(seconds: 4));
  });

  Future<void> pumpConsoleMobile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SuperAdminConsole()));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('mobile: hamburger drawer navigation and card rows', (
    tester,
  ) async {
    await pumpConsoleMobile(tester);

    // Sidebar is hidden (drawer closed) - nav items are not hit-testable.
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.text('Sociétés').hitTestable(), findsNothing);

    // Open the drawer via the hamburger.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Sociétés').hitTestable(), findsOneWidget);

    // Navigate: drawer closes and the sociétés page shows cards.
    await tester.tap(find.text('Sociétés').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Bonanjo, Douala'), findsWidgets);
    expect(find.text('Nouvelle société'), findsOneWidget);
  });

  testWidgets('mobile: tapping a card opens the edit form', (tester) async {
    await pumpConsoleMobile(tester);

    // Open the drawer and go to the sociétés page (cards layout).
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sociétés').hitTestable());
    await tester.pumpAndSettle();

    // Tapping the first card opens the edit form (parity with desktop rows).
    await tester.tap(find.text('Propre237 Douala SARL').first);
    await tester.pumpAndSettle();
    expect(find.text('Modifier la société'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('mobile: system back closes the drawer before popping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Push the console as a route so the second back actually pops it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SuperAdminConsole()),
                ),
                child: const Text('Ouvrir console'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir console'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    // Open the drawer.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Sociétés').hitTestable(), findsOneWidget);

    // First back: the drawer closes, the console is NOT popped.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Sociétés').hitTestable(), findsNothing);
    expect(find.text('Ouvrir console'), findsNothing);

    // Second back: the console pops back to the previous screen.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir console'), findsOneWidget);
  });

  testWidgets('command palette opens and closes with Escape', (tester) async {
    await pumpConsole(tester);

    await tester.tap(find.text('Rechercher ou agir...'));
    await tester.pumpAndSettle();

    // Group labels are uppercased by the palette UI.
    expect(find.text('NAVIGATION'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.text('Nouvelle société'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('NAVIGATION'), findsNothing);
  });
}
