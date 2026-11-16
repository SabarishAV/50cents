import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get apiUrl {
    final url = dotenv.env['API_URL'];
    if (url == null || url.isEmpty) {
      throw StateError('API_URL is missing in .env');
    }
    return url;
  }

  static String get googleServerClientId {
    final id = dotenv.env['GOOGLE_SERVER_CLIENT_ID'];
    if (id == null || id.isEmpty) {
      throw StateError('GOOGLE_SERVER_CLIENT_ID is missing in .env');
    }
    return id;
  }

  static String get redirectPageUrl {
    final url = dotenv.env['REDIRECT_PAGE_URL'];
    if (url == null || url.isEmpty) {
      throw StateError('REDIRECT_PAGE_URL is missing in .env');
    }
    return url;
  }

  static int get redirectExpiryMinutes {
    final raw = dotenv.env['REDIRECT_EXPIRY_MINUTES'];
    if (raw == null || raw.isEmpty) {
      throw StateError('REDIRECT_EXPIRY_MINUTES is missing in .env');
    }
    final minutes = int.tryParse(raw);
    if (minutes == null || minutes <= 0) {
      throw StateError('REDIRECT_EXPIRY_MINUTES must be a positive integer');
    }
    return minutes;
  }
}
