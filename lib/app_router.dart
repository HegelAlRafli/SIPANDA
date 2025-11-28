import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/screens/add_item_screen.dart';
import 'package:myapp/screens/edit_item_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/item_details_screen.dart';
import 'package:myapp/screens/item_list_screen.dart';
import 'package:myapp/screens/qr_code_screen.dart';
import 'package:myapp/screens/scan_qr_screen.dart';

// --- ROUTING LOGIC ---
final GoRouter router = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Error: ${state.error?.message}'),
    ),
  ),
  routes: <RouteBase>[
    GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'add_item',
            builder: (BuildContext context, GoRouterState state) {
              return const AddItemScreen();
            },
          ),
          GoRoute(
            path: 'qr_code',
            name: 'qr_code',
            builder: (BuildContext context, GoRouterState state) {
              final qrData = state.extra as String?;
              if (qrData == null) {
                // Redirect or show error if data is missing
                return const Scaffold(
                    body: Center(child: Text("Error: QR Data is missing.")));
              }
              // CORRECTED: Pass the data to the 'itemId' parameter
              return QrCodeScreen(itemId: qrData);
            },
          ),
          GoRoute(
            path: 'scan_qr',
            builder: (BuildContext context, GoRouterState state) {
              return const ScanQRScreen();
            },
          ),
          GoRoute(
              path: 'item_details/:itemId',
              name: 'item_details',
              builder: (BuildContext context, GoRouterState state) {
                final itemId = state.pathParameters['itemId'];
                if (itemId == null) {
                  return const Scaffold(
                      body:
                          Center(child: Text("Error: Item ID is missing.")));
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
                          body: Center(
                              child: Text("Error: Item ID is missing.")));
                    }
                    return EditItemScreen(itemId: itemId);
                  },
                ),
              ]),
          GoRoute(
            path: 'item_list',
            builder: (BuildContext context, GoRouterState state) {
              return const ItemListScreen();
            },
          ),
        ]),
  ],
);
