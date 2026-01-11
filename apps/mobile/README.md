# MaaS Mobile App 📱

Aplikacja mobilna Flutter dla platformy Mobility as a Service (MaaS).

## 🚀 Funkcjonalności

- **Mapa interaktywna** - Fullscreen mapa OpenStreetMap z flutter_map
- **Planowanie tras** - Multimodalne trasy łączące transport publiczny i mikromobilność
- **Widok pojazdów** - Markery hulajnóg, rowerów i innych pojazdów
- **Szczegóły trasy** - Timeline z przesiadkami i instrukcjami
- **Nawigacja aktywna** - Turn-by-turn nawigacja z postępem podróży
- **Ustawienia** - Preferencje użytkownika i konfiguracja dostawców

## 🛠️ Technologie

- **Framework:** Flutter 3.x
- **State Management:** flutter_bloc (BLoC pattern)
- **Dependency Injection:** get_it + injectable
- **Mapy:** flutter_map (OpenStreetMap)
- **Networking:** dio + retrofit
- **Architektura:** Clean Architecture

## 📁 Struktura projektu

```
lib/
├── core/
│   ├── di/              # Dependency Injection
│   ├── theme/           # Motywy i kolory
│   └── router/          # Nawigacja
├── features/
│   ├── home/            # Główny ekran z mapą
│   ├── routing/         # Planowanie tras
│   ├── map/             # Funkcje mapy i pojazdy
│   ├── navigation/      # Nawigacja aktywna
│   └── settings/        # Ustawienia
├── exports.dart         # Barrel file
└── main.dart            # Entry point
```

## 🚀 Uruchomienie

### Wymagania
- Flutter SDK >= 3.2.0
- Dart SDK >= 3.2.0
- Android Studio / VS Code
- Emulator Android lub urządzenie fizyczne

### Instalacja

```bash
# Przejdź do katalogu aplikacji
cd apps/mobile

# Pobierz zależności
flutter pub get

# Uruchom aplikację
flutter run
```

### Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (wymaga macOS)
flutter build ios --release
```

## 🔌 Integracja z backendem

Aplikacja łączy się z backendem NestJS przez API:

- **Base URL:** `http://10.0.2.2:3000/api/v1` (emulator Android)
- **Routing:** `POST /routing/plan`
- **Vehicles:** `GET /map/vehicles`

Zmień `baseUrl` w `lib/core/di/injection.config.dart` dla produkcji.

## 🎨 Design

- Material Design 3
- Kolorystyka segmentów:
  - 🚶 Pieszo: Szary (#757575)
  - 🚌 Autobus: Niebieski (#2196F3)
  - 🚋 Tramwaj: Czerwony (#F44336)
  - 🚇 Metro: Fioletowy (#9C27B0)
  - 🛴 Hulajnoga: Zielony (#4CAF50)
  - 🚲 Rower: Pomarańczowy (#FF9800)

## 📱 Screenshots

*TODO: Dodaj screenshots aplikacji*

## 🔮 Roadmap Fazy 3

- [x] Podstawowa struktura projektu
- [x] Clean Architecture
- [x] HomeScreen z mapą
- [x] Wyszukiwarka miejsc
- [x] RouteSelectionSheet
- [x] TripCard widget
- [x] Route polylines (multikolorowe)
- [x] Vehicle markers
- [x] RouteDetailsScreen
- [x] ActiveNavigationScreen
- [x] SettingsScreen
- [ ] Integracja geolokalizacji
- [ ] Powiadomienia push
- [ ] Tryb offline
- [ ] Animacje i polish UI

## 📄 License

MIT © MaaS Platform
