// ============================================================================
// MaaS Platform - Settings Screen
// User preferences and app configuration
// ============================================================================

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // User preferences
  bool _preferEco = false;
  bool _avoidStairs = false;
  bool _preferAccessible = false;
  double _maxWalkDistance = 1000;
  int _maxTransfers = 3;
  
  // Provider preferences
  final Map<String, bool> _enabledProviders = {
    'Bolt': true,
    'Lime': true,
    'Tier': true,
    'Veturilo': true,
  };

  // Notifications
  bool _enableNotifications = true;
  bool _departureReminders = true;
  bool _delayAlerts = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Route preferences section
          _buildSectionHeader(theme, 'Preferencje tras', Icons.route),
          
          SwitchListTile(
            title: const Text('Preferuj ekologiczne trasy'),
            subtitle: const Text('Wybieraj trasy z niższą emisją CO₂'),
            value: _preferEco,
            onChanged: (value) => setState(() => _preferEco = value),
            secondary: const Icon(Icons.eco, color: Colors.green),
          ),
          
          SwitchListTile(
            title: const Text('Unikaj schodów'),
            subtitle: const Text('Wybieraj trasy bez schodów'),
            value: _avoidStairs,
            onChanged: (value) => setState(() => _avoidStairs = value),
            secondary: const Icon(Icons.stairs, color: Colors.orange),
          ),
          
          SwitchListTile(
            title: const Text('Dostępność'),
            subtitle: const Text('Tylko pojazdy przystosowane dla osób niepełnosprawnych'),
            value: _preferAccessible,
            onChanged: (value) => setState(() => _preferAccessible = value),
            secondary: const Icon(Icons.accessible, color: Colors.blue),
          ),

          const Divider(),

          // Walking preferences
          _buildSectionHeader(theme, 'Preferencje pieszych', Icons.directions_walk),
          
          ListTile(
            title: const Text('Maksymalna odległość pieszo'),
            subtitle: Text('${_maxWalkDistance.toInt()} m'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _maxWalkDistance,
                min: 200,
                max: 2000,
                divisions: 18,
                label: '${_maxWalkDistance.toInt()} m',
                onChanged: (value) {
                  setState(() => _maxWalkDistance = value);
                },
              ),
            ),
          ),

          ListTile(
            title: const Text('Maksymalna liczba przesiadek'),
            subtitle: Text('$_maxTransfers'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _maxTransfers.toDouble(),
                min: 0,
                max: 5,
                divisions: 5,
                label: '$_maxTransfers',
                onChanged: (value) {
                  setState(() => _maxTransfers = value.toInt());
                },
              ),
            ),
          ),

          const Divider(),

          // Provider preferences
          _buildSectionHeader(theme, 'Dostawcy usług', Icons.business),
          
          ..._enabledProviders.entries.map((entry) {
            return SwitchListTile(
              title: Text(entry.key),
              subtitle: Text(_getProviderDescription(entry.key)),
              value: entry.value,
              onChanged: (value) {
                setState(() => _enabledProviders[entry.key] = value);
              },
              secondary: _getProviderIcon(entry.key),
            );
          }),

          const Divider(),

          // Notification settings
          _buildSectionHeader(theme, 'Powiadomienia', Icons.notifications),
          
          SwitchListTile(
            title: const Text('Włącz powiadomienia'),
            value: _enableNotifications,
            onChanged: (value) => setState(() => _enableNotifications = value),
            secondary: const Icon(Icons.notifications_active),
          ),
          
          SwitchListTile(
            title: const Text('Przypomnienia o odjeździe'),
            subtitle: const Text('Powiadom 5 min przed odjazdem'),
            value: _departureReminders,
            onChanged: _enableNotifications
                ? (value) => setState(() => _departureReminders = value)
                : null,
            secondary: const Icon(Icons.alarm),
          ),
          
          SwitchListTile(
            title: const Text('Alerty o opóźnieniach'),
            subtitle: const Text('Powiadom o zmianach w rozkładzie'),
            value: _delayAlerts,
            onChanged: _enableNotifications
                ? (value) => setState(() => _delayAlerts = value)
                : null,
            secondary: const Icon(Icons.warning),
          ),

          const Divider(),

          // Account section
          _buildSectionHeader(theme, 'Konto', Icons.person),
          
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historia podróży'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to trip history
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('Metody płatności'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to payment methods
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Faktury i paragony'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to invoices
            },
          ),

          const Divider(),

          // About section
          _buildSectionHeader(theme, 'Informacje', Icons.info),
          
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Pomoc i FAQ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to help
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Regulamin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Show terms
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Polityka prywatności'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Show privacy policy
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Wersja aplikacji'),
            subtitle: const Text('1.0.0 (build 1)'),
          ),

          const SizedBox(height: 32),

          // Logout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(),
              icon: const Icon(Icons.logout),
              label: const Text('Wyloguj się'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getProviderIcon(String provider) {
    switch (provider) {
      case 'Bolt':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF34D186),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.electric_scooter, color: Colors.white, size: 20),
        );
      case 'Lime':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00DE00),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.electric_scooter, color: Colors.white, size: 20),
        );
      case 'Tier':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1A2B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.electric_scooter, color: Colors.white, size: 20),
        );
      case 'Veturilo':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE31E24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.pedal_bike, color: Colors.white, size: 20),
        );
      default:
        return const Icon(Icons.directions);
    }
  }

  String _getProviderDescription(String provider) {
    switch (provider) {
      case 'Bolt':
        return 'Hulajnogi elektryczne';
      case 'Lime':
        return 'Hulajnogi i rowery elektryczne';
      case 'Tier':
        return 'Hulajnogi elektryczne';
      case 'Veturilo':
        return 'Rowery miejskie Warszawy';
      default:
        return 'Usługa mobilności';
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wylogować się?'),
        content: const Text(
          'Czy na pewno chcesz się wylogować? '
          'Twoje preferencje zostaną zapisane.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Handle logout
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Wyloguj'),
          ),
        ],
      ),
    );
  }
}
