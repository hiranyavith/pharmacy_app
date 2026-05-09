# Pharmacy MVP System
### Flutter Windows + MySQL

---

## Prerequisites

| Tool | Download |
|------|----------|
| Flutter SDK (stable) | https://flutter.dev/docs/get-started/install/windows |
| MySQL 8.x or XAMPP | https://www.apachefriends.org/ |
| VS Code + Flutter extension | https://code.visualstudio.com |

---

## Setup Steps

### 1. Enable Flutter Windows Desktop
```bash
flutter config --enable-windows-desktop
flutter doctor   # everything should be green
```

### 2. Set up MySQL Database
Open MySQL (via XAMPP phpMyAdmin or MySQL Workbench) and run:
```
database_setup.sql
```
This creates `pharmacy_db` with all tables and seed data.

### 3. Configure DB Connection
Edit `lib/db/db_helper.dart` if needed:
```dart
static const String _host     = '127.0.0.1';
static const int    _port     = 3306;
static const String _user     = 'root';
static const String _password = '';       // ← set your MySQL root password here
static const String _db       = 'pharmacy_db';
```

### 4. Install Flutter packages
```bash
flutter pub get
```

### 5. Run the app
```bash
flutter run -d windows
```

### 6. Build EXE for distribution
```bash
flutter build windows --release
# Output: build\windows\x64\runner\Release\pharmacy_app.exe
```

---

## Default Login
- **Username:** `admin`  
- **Password:** `admin123`

---

## Project Structure
```
lib/
├── main.dart                    # App entry point
├── db/
│   └── db_helper.dart           # MySQL singleton
├── models/
│   ├── medicine.dart
│   └── bill.dart
├── services/
│   ├── auth_service.dart        # Login/logout
│   ├── medicine_service.dart    # CRUD + search + low stock + expiry
│   └── billing_service.dart     # Cart → bill + stock reduction
├── screens/
│   ├── login_screen.dart
│   ├── dashboard_screen.dart    # Sidebar navigation + summary cards
│   ├── medicine_screen.dart     # Add / Edit / Delete / Search
│   ├── pos_screen.dart          # Cart + billing + print
│   ├── bill_history_screen.dart # Search by invoice / date
│   └── expiry_screen.dart       # Expiring ≤30 days + low stock tabs
└── utils/
    ├── app_theme.dart           # Colors, theme, snackbars
    └── pdf_generator.dart       # A5 PDF bill printing
```

---

## Features
- ✅ Admin login (username + password)
- ✅ Medicine CRUD (add / edit / delete / search)
- ✅ POS with cart, discount, total calculation
- ✅ Automatic stock reduction after sale
- ✅ PDF bill generation + print dialog
- ✅ Bill history with invoice search + date filter
- ✅ Expiry alert (medicines expiring within 30 days)
- ✅ Low stock warning (≤ 10 units)
- ✅ Dashboard with summary statistics

---

## Troubleshooting

**MySQL connection error:**
- Make sure MySQL is running (XAMPP → Start Apache + MySQL)
- Check host/port/user/password in `db_helper.dart`
- Run `database_setup.sql` first

**`flutter run -d windows` not found:**
- Run `flutter config --enable-windows-desktop`
- Run `flutter upgrade` to get latest stable

**Print dialog not opening:**
- The `printing` package requires Windows Print Spooler service running
- Works with any installed printer or "Microsoft Print to PDF"
