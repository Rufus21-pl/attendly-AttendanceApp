import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Amber card in the drawer header that leads to the year rollover.
class NewYearBanner extends StatefulWidget {
  final VoidCallback onTap;

  const NewYearBanner({super.key, required this.onTap});

  @override
  State<NewYearBanner> createState() => _NewYearBannerState();
}

class _NewYearBannerState extends State<NewYearBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final isTablet = responsive.isTablet;
    final radius = BorderRadius.circular(isTablet ? 18 : 14);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade600, Colors.orange.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 14 : 10),
            child: Row(
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.1).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(isTablet ? 8 : 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.celebration, color: Colors.white, size: isTablet ? 28 : 22),
                  ),
                ),
                SizedBox(width: isTablet ? 14 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.newYearAvailable,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 18 : 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localizations.newYearBannerHint,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: isTablet ? 15 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white, size: isTablet ? 28 : 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact banner for the tablet rail: the pulsing icon only.
class NewYearRailBadge extends StatefulWidget {
  final VoidCallback onTap;
  final double iconSize;

  const NewYearRailBadge({super.key, required this.onTap, required this.iconSize});

  @override
  State<NewYearRailBadge> createState() => _NewYearRailBadgeState();
}

class _NewYearRailBadgeState extends State<NewYearRailBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).newYearAvailable,
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.08).animate(
          CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
        ),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.amber.shade600, Colors.orange.shade700]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.celebration, color: Colors.white, size: widget.iconSize * 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
