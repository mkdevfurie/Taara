import 'package:flutter_test/flutter_test.dart';
import 'package:taara/services/api_service.dart';

void main() {
  test('TaaraUser se (dé)sérialise et détecte le rôle PRO', () {
    final user = TaaraUser.fromJson({
      'id': 'u1',
      'email': 'pro@taara.app',
      'firstName': 'Yawa',
      'lastName': 'Agbenya',
      'userType': 'PRO',
    });
    expect(user.isPro, isTrue);
    expect(user.fullName, 'Yawa Agbenya');
    expect(TaaraUser.fromJson(user.toJson()).email, 'pro@taara.app');
  });

  test('ApiException expose le message', () {
    expect(const ApiException('Solde insuffisant', statusCode: 400).toString(), 'Solde insuffisant');
  });
}
