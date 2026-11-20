import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../model/profile_model.dart';
import 'profile_hero_card.dart';
import 'profile_info_card.dart';
import 'profile_info_row.dart';

/// Everything below the AppBar, scrollable (and pull-to-refresh friendly).
///
/// ```
/// PHONE (< 720)                 TABLET (≥ 720, max 900 wide)
/// ┌──────────────┐              ┌──────────────────────────────┐
/// │  HeroCard    │              │           HeroCard           │
/// │  CONTACT     │              │  CONTACT        │  PERSONAL  │
/// │  PERSONAL    │              │                 │            │
/// └──────────────┘              └──────────────────────────────┘
/// ```
class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.profile,
    this.avatarBusy = false,
  });

  final ProfileModel profile;

  /// Step 4.2: avatar upload running.
  final bool avatarBusy;

  static const double _wideBreakpoint = 720;
  static const double _maxWidth = 900;

  /// "2024-01-15" → "15 Jan 2024". null → null (the row shows "—").
  static String? _date(DateTime? date) =>
      date == null ? null : DateFormat('d MMM yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    final employee = profile.employee;

    final contact = ProfileInfoCard(
      title: 'Contact',
      rows: [
        ProfileInfoRow(
          icon: Icons.mail_outline_rounded,
          label: 'Email',
          value: profile.email,
        ),
        ProfileInfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: profile.phone,
        ),
        if (employee != null) ...[
          ProfileInfoRow(
            icon: Icons.badge_outlined,
            label: 'Employee ID',
            value: employee.employeeNo,
          ),
          ProfileInfoRow(
            icon: Icons.event_outlined,
            label: 'Hire date',
            value: _date(employee.hireDate),
          ),
        ],
      ],
    );

    // No linked employee (404) → no personal info to show.
    final personal = employee == null
        ? null
        : ProfileInfoCard(
            title: 'Personal',
            rows: [
              ProfileInfoRow(
                icon: Icons.cake_outlined,
                label: 'Birthday',
                value: _date(employee.dateOfBirth),
              ),
              ProfileInfoRow(
                icon: Icons.home_outlined,
                label: 'Address',
                value: employee.address,
              ),
              ProfileInfoRow(
                icon: Icons.contact_emergency_outlined,
                label: 'Emergency contact',
                value: employee.emergencyContact,
              ),
              ProfileInfoRow(
                icon: Icons.phone_in_talk_outlined,
                label: 'Emergency phone',
                value: employee.emergencyPhone,
              ),
            ],
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        return ListView(
          // always scrollable → pull-to-refresh works even on a tall screen
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfileHeroCard(profile: profile, avatarBusy: avatarBusy),
                    const SizedBox(height: AppSpacing.lg),
                    if (wide && personal != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: contact),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: personal),
                        ],
                      )
                    else ...[
                      contact,
                      if (personal != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        personal,
                      ],
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
