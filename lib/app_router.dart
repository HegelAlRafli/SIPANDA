
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/scaffold_with_nav_bar.dart';
import 'package:myapp/screens/add_item_screen.dart';
import 'package:myapp/screens/edit_item_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/item_details_screen.dart';
import 'package:myapp/screens/item_list_screen.dart';
import 'package:myapp/screens/qr_code_screen.dart';
import 'package:myapp/screens/scan_qr_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Error: ${state.error?.message}'),
    ),
  ),
  routes: <RouteBase>[
    // Main navigation routes
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (BuildContext context, GoRouterState state) {
                return const HomeScreen();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/item_list',
              builder: (BuildContext context, GoRouterState state) {
                return const ItemListScreen();
              },
            ),
          ],
        ),
      ],
    ),
    // Top-level routes that can be accessed from anywhere
    GoRoute(
      path: '/add_item',
      parentNavigatorKey: _rootNavigatorKey, // Important!
      builder: (BuildContext context, GoRouterState state) {
        return const AddItemScreen();
      },
    ),
    GoRoute(
      path: '/scan_qr',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (BuildContext context, GoRouterState state) {
        return const ScanQRScreen();
      },
    ),
    GoRoute(
      path: '/item_details/:itemId',
      name: 'item_details',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (BuildContext context, GoRouterState state) {
        final itemId = state.pathParameters['itemId'];
        if (itemId == null) {
          return const Scaffold(
              body: Center(child: Text("Error: Item ID is missing.")));
        }
        return ItemDetailsScreen(itemId: itemId);
      },
      routes: [
         GoRoute(
            path: 'edit',
            name: 'edit_item',
            builder: (BuildContext context, GoRouterState state) {
              final itemId = state.pathParameters['itemId'];
              if (itemId == null) {
                return const Scaffold(
                    body: Center(child: Text("Error: Item ID is missing.")));
              }
              return EditItemScreen(itemId: itemId);
            },
          ),
      ]
    ),
     GoRoute(
      path: '/qr_code',
      name: 'qr_code',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (BuildContext context, GoRouterState state) {
        final qrData = state.extra as String?;
        if (qrData == null) {
          return const Scaffold(
              body: Center(child: Text("Error: QR Data is missing.")));
        }
        return QrCodeScreen(itemId: qrData);
      },
    ),
  ],
);
