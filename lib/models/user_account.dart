class UserAccount {
  final String userId;
  final String pwd;
  final String userName;

  UserAccount({
    required this.userId,
    required this.pwd,
    required this.userName,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'pwd': pwd,
      'userName': userName,
    };
  }

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    return UserAccount(
      userId: map['userId'] as String,
      pwd: map['pwd'] as String,
      userName: map['userName'] as String,
    );
  }
} 