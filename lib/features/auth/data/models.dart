/// Active country (phone prefix and format).
class Country {
  const Country({
    required this.id,
    required this.name,
    required this.iso2,
    required this.dialCode,
    required this.flag,
    this.phoneMinLength,
    this.phoneMaxLength,
    this.phoneExample,
  });

  factory Country.fromJson(Map<String, dynamic> json) => Country(
    id: json['id'] as int,
    name: json['name'] as String,
    iso2: json['iso2'] as String,
    dialCode: json['dial_code'] as String,
    flag: (json['flag'] as String?) ?? '',
    phoneMinLength: json['phone_min_length'] as int?,
    phoneMaxLength: json['phone_max_length'] as int?,
    phoneExample: json['phone_example'] as String?,
  );

  final int id;
  final String name;
  final String iso2;
  final String dialCode;
  final String flag;
  final int? phoneMinLength;
  final int? phoneMaxLength;
  final String? phoneExample;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iso2': iso2,
    'dial_code': dialCode,
    'flag': flag,
    'phone_min_length': phoneMinLength,
    'phone_max_length': phoneMaxLength,
    'phone_example': phoneExample,
  };
}

/// The signed-in account (GET /auth/me).
class User {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    required this.phoneVerified,
    required this.mustChangePassword,
    required this.isJudge,
    this.avatarUrl,
    this.email,
    this.country,
    this.locationLabel,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    phone: (json['phone'] as String?) ?? '',
    phoneVerified: json['phone_verified'] == true,
    mustChangePassword: json['must_change_password'] == true,
    isJudge: json['is_judge'] == true,
    avatarUrl: json['avatar_url'] as String?,
    email: json['email'] as String?,
    country: json['country'] is Map<String, dynamic> ? Country.fromJson(json['country'] as Map<String, dynamic>) : null,
    locationLabel: json['location'] is Map<String, dynamic>
        ? (json['location'] as Map<String, dynamic>)['label'] as String?
        : null,
  );

  final int id;
  final String name;
  final String phone;
  final bool phoneVerified;
  final bool mustChangePassword;
  final bool isJudge;
  final String? avatarUrl;
  final String? email;
  final Country? country;
  final String? locationLabel;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'phone_verified': phoneVerified,
    'must_change_password': mustChangePassword,
    'is_judge': isJudge,
    'avatar_url': avatarUrl,
    'email': email,
    'country': country?.toJson(),
    'location': locationLabel == null ? null : {'label': locationLabel},
  };
}
