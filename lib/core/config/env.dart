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
}
