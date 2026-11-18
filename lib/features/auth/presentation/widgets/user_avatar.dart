import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:_50cents/core/config/env.dart';
import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/features/auth/data/models/auth_session.dart';
import 'package:_50cents/features/auth/data/user_repository.dart';

/// Circular avatar used on the home and profile screens.
///
/// The profile picture returned by `GET /user` takes priority over the JWT
/// claim: the backend can hold an avatar that was never embedded in the token.
/// Absolute URLs, API-relative paths and `data:image/...` URIs are supported.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, required this.session, this.size = 44, this.onTap, this.imageUrl});

  final AuthSession session;
  final double size;
  final VoidCallback? onTap;

  /// Explicit image source override. When omitted, the `/user` avatar is used
  /// first and the token claim is only a fallback.
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAvatar = ref.watch(currentUserProvider).asData?.value.avatarUrl;
    final avatarUrl = imageUrl ?? profileAvatar ?? session.avatarUrl;
    final image = _avatarProvider(avatarUrl);

    final initials = Text(
      session.initials,
      style: TextStyle(color: AppColors.neonBlue, fontSize: size * 0.36, fontWeight: FontWeight.w700),
    );

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
          child: image == null
              ? initials
              : Image(
                  image: image,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      width: size * 0.3,
                      height: size * 0.3,
                      child: CircularProgressIndicator(
                        color: AppColors.neonBlue,
                        strokeWidth: 1.5,
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Center(child: initials),
                ),
        ),
      ),
    );

    if (onTap == null) return avatar;
    return InkWell(borderRadius: BorderRadius.circular(size), onTap: onTap, child: avatar);
  }
}

/// Converts the API's avatar string into something Flutter can actually paint.
ImageProvider? _avatarProvider(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) return null;

  // The API documents `avatar` as a URL *or* a data URI.
  if (value.startsWith('data:image/')) {
    final comma = value.indexOf(',');
    if (comma == -1) return null;
    final header = value.substring(0, comma);
    final payload = value.substring(comma + 1);
    try {
      if (header.contains(';base64')) return MemoryImage(base64Decode(payload));
      return MemoryImage(Uint8List.fromList(Uri.decodeComponent(payload).codeUnits));
    } catch (_) {
      return null;
    }
  }

  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.hasScheme) return NetworkImage(value);

  // Relative paths such as `/uploads/avatar.png` need the API host prepended.
  try {
    return NetworkImage(Uri.parse(Env.apiUrl).resolve(value).toString());
  } catch (_) {
    return NetworkImage(value);
  }
}
