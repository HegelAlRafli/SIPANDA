# Project Blueprint: Aplikasi Manajemen Inventaris

This document outlines the architecture, features, and design of the "Aplikasi Manajemen Inventaris" Flutter application.

## 1. Overview

An application to manage inventory items using QR codes. Users can add items with details and an image, generate a unique QR code for each item, and scan the QR codes to view or update item details.

## 2. Core Features & Style

### Implemented Features:
- **Firebase Integration:** Core setup with Firestore for database.
- **Theme:**
    - Light and Dark mode support using `provider`.
    - Custom color scheme seeded from `Color(0xFF4A43EC)`.
    - Typography using `google_fonts` with "Poppins" font.
    - Centralized `ThemeData` for consistent component styling.
- **Routing:**
    - Declarative navigation using `go_router`.
    - Routes defined for Home, Add Item, Item List, Item Details, Edit Item, Scan QR, and QR Code display.
- **Home Screen (`/`):**
    - Displays main navigation cards for "Buat Kode QR Baru" and "Pindai Kode QR".
    - Bottom navigation bar for Home, Item List, and Profile.
- **Add Item (`/add_item`):**
    - Form to input item name, description, and quantity.
    - Image uploading functionality to a third-party service (imgbb.com) to get a URL.
    - Saves item data (including the image URL) to Firestore.
    - Generates and navigates to the QR code screen upon successful submission.
- **Item List (`/item_list`):**
    - Fetches and displays a list of all items from Firestore.
    - Each item is a clickable card that navigates to its details screen.
- **Item Details (`/item_details/:itemId`):**
    - Fetches and displays the full details of a specific item from Firestore, including the image.
    - Provides buttons to "Edit" or "Hapus" (Delete) the item.
    - Delete function removes the item document from Firestore.
- **Edit Item (`/item_details/:itemId/edit`):**
    - Pre-fills a form with the existing data of an item.
    - Allows users to update the name, description, quantity, and image.
    - Saves the updated data back to the corresponding Firestore document.
- **Scan QR Code (`/scan_qr`):**
    - Placeholder screen for QR code scanning functionality.
- **Display QR Code (`/qr_code`):**
    - Displays the generated QR code for a specific item.

### Design & Style:
- **UI Components:** Utilizes custom `HomeCard` widgets for a consistent look on the home screen.
- **Layout:** Responsive layout using `Column`, `Padding`, and `SizedBox`.
- **Aesthetics:** Clean, modern design with a clear visual hierarchy.

## 3. Current Task: Fixing Image Upload and Display

### Plan:
1.  **Acknowledge the Problem:** The current implementation uses `imgbb.com` for image hosting, which is causing issues (likely due to CORS or platform restrictions) in the local `web-preview` environment, but works on a deployed or manually accessed web page. This indicates a limitation of the local development server, not a fundamental code error.
2.  **Propose a Robust Solution:** Instead of relying on a third-party image hosting service with potential cross-origin issues, we will pivot to a more integrated and reliable solution: **Firebase Storage for Cloud**.
3.  **Update `add_item_screen.dart`:**
    - Modify the image upload logic.
    - Instead of sending the image to `imgbb.com`, upload the image file directly to a Firebase Storage bucket.
    - After uploading, get the secure `downloadURL` for the image from Firebase Storage.
    - Save this `downloadURL` to the Firestore document along with other item data.
4.  **Update `item_details_screen.dart` and `edit_item_screen.dart`:**
    - No significant changes are needed here. These screens already display an image from a URL. Since they will now receive a Firebase Storage `downloadURL` instead of an `imgbb.com` URL, the `Image.network()` widget will work seamlessly.
5.  **Update `delete_item` logic:**
    - Enhance the delete function. When an item is deleted from Firestore, also delete its corresponding image from the Firebase Storage bucket to prevent orphaned files and save storage space.
6.  **Verify and Test:** After implementing the changes, test the full "add-edit-delete" lifecycle to ensure image uploads, displays, and deletions work correctly within the local `web-preview`.
