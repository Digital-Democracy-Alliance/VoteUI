import 'package:voting_app/core/services/auth_service.dart';
import 'package:voting_app/core/viewmodels/base_model.dart';
import 'package:voting_app/locator.dart';

class ThemeModel extends BaseModel {
  bool isDarkMode = false;
  String user;
  String get getUser => user;
  bool get loggedIn => user == null ? false : true;
  
  final AuthenticationService _authenticationService =
      locator<AuthenticationService>();

  void updateTheme(bool isDarkMode) {
    this.isDarkMode = isDarkMode;
    print(isDarkMode);
    notifyListeners();
  }

  Future<String> setUser() async {
    var isUser = await _authenticationService.getUser();
    user = isUser;
    print(user);
    return user;
  }


}
