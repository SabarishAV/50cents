class RegisterRequest {
  final String name;
  final String? username;
  final String email;
  final String password;
  final String? avatar;

  RegisterRequest({required this.name, this.username, required this.email, required this.password, this.avatar});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (username != null && username!.isNotEmpty) 'username': username,
      'email': email,
      'password': password,
      if (avatar != null && avatar!.isNotEmpty) 'avatar': avatar,
    };
  }
}
