import 'package:material_ui/material_ui.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/features/auth/data/models/auth_session.dart';

/// Circular avatar showing the Google picture when available, otherwise the
/// user's initials. Used on the home and profile screens.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.session, this.size = 44, this.onTap});

  final AuthSession session;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initials = Text(
      session.initials,
      style: TextStyle(color: AppColors.neonBlue, fontSize: size * 0.36, fontWeight: FontWeight.w700),
    );

    final avatarUrl = session.avatarUrl;

    final avatar = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.6), width: 1.4),
        boxShadow: [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.18), blurRadius: 14, spreadRadius: 1)],
      ),
      child: ClipOval(
        child: Container(
          color: AppColors.surface,
          alignment: Alignment.center,
          child: avatarUrl == null
              ? initials
              : Image.network(
                  avatarUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(child: initials),
                ),
        ),
      ),
    );

    if (onTap == null) return avatar;
    return InkWell(borderRadius: BorderRadius.circular(size), onTap: onTap, child: avatar);
  }
}
