# Project Blueprint: QR Barangku

## Overview

This document outlines the plan, design, and features of the "QR Barangku" Flutter application. The goal is to create a mobile app that fully replicates the provided HTML design, ensuring 100% adherence to layout, spacing, colors, and components.

## Key Features

*   **UI Replication:** The app will faithfully render all UI elements from the HTML designs.
*   **Responsive Design:** The app will adapt to different screen sizes.
*   **Placeholder Interactions:** All interactive components will have placeholder interactions.
*   **Theming:** The app will use Material 3 theming with the "Poppins" font and a primary color of `#155BFB`.
*   **Navigation:** The app will use `go_router` for navigation between screens.

## Screens

The application will consist of the following screens:

1.  **Home Screen:**  Displays options to generate or scan a QR code.
2.  **Add Item Screen:** A form to add a new item and generate a QR code for it.
3.  **QR Code Screen:** Displays the generated QR code.
4.  **Scan QR Screen:** A screen with a camera view to scan a QR code.
5.  **Item Details Screen:** Displays the details of a scanned item.

## Plan

1.  **Project Setup:**
    *   Add `google_fonts`, `provider`, and `go_router` to `pubspec.yaml`.
2.  **Theming:**
    *   Create a `ThemeData` object using Material 3 with the primary color `#155BFB` and "Poppins" font.
3.  **Screen Creation:**
    *   Create a separate Dart file for each screen.
    *   Implement the layout and widgets for each screen, matching the HTML design.
4.  **Navigation:**
    *   Configure `go_router` to handle navigation between the screens.
5.  **Interactions:**
    *   Add placeholder `onPressed` handlers for all buttons and interactive elements.
