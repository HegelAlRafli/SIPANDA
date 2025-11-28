# Project Blueprint: Aplikasi Manajemen Inventaris

This document outlines the architecture, features, and design of the "Aplikasi Manajemen Inventaris" Flutter application.

## 1. Overview

An application to manage inventory items using QR codes. Users can add items with details, an image, and a list of responsible holders. The app generates a unique QR code for each item, which can be downloaded as an image. Users can also scan these codes to view or update item details.

## 2. Core Features & Style

### Implemented Features:
- **Firebase Integration:** Core setup with Firestore for the database.
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
    - Form to input item name and category.
    - **Dynamic Fields:** Users can add custom key-value pairs for additional details.
    - **Image Upload:** Main item image can be uploaded to get a URL.
    - **Item Holders (Pemegang Barang):** Users can dynamically add holders with names and photos.
    - Saves all data to a single Firestore document.
    - Navigates to the QR code screen upon submission.
- **Item List (`/item_list`):**
    - Fetches and displays a list of all items from Firestore.
- **Item Details (`/item_details/:itemId`):**
    - Displays the full details of a specific item, including the main image and a list of item holders.
    - Provides buttons to "Edit" or "Hapus" (Delete) the item.
- **Edit Item (`/item_details/:itemId/edit`):**
    - Pre-fills a form with all existing data for an item.
    - Allows users to add, edit, or delete all item attributes, including dynamic fields and item holders.
- **Scan QR Code (`/scan_qr`):**
    - Placeholder screen for QR code scanning functionality.
- **Display QR Code (`/qr_code`):**
    - Displays the generated QR code for a specific item ID.
    - **Download QR Code:** Allows the user to capture the QR code widget as a PNG image and save it to their device using the `file_saver` package.

### Design & Style:
- **UI Components:** Utilizes custom `HomeCard` widgets and consistent, modern `Card` and `ListTile` layouts.
- **Layout:** Responsive and dynamic forms using `ListView` and dynamic widgets.
- **Aesthetics:** Clean, modern design with a clear visual hierarchy, rounded corners, and defined component sections.
