import sys

with open('lib/screens/login_screen.dart', 'r') as f:
    content = f.read()

# Replace variables
content = content.replace('_phoneController', '_emailController')
content = content.replace('_phoneFocusNode', '_emailFocusNode')
content = content.replace('_isPhoneFocused', '_isEmailFocused')

# Replace hint texts
content = content.replace("hintText: 'Рақами телефонро ворид кунед',", "hintText: 'Почтаи электрониро ворид кунед',")
content = content.replace("keyboardType: TextInputType.phone,", "keyboardType: TextInputType.emailAddress,")

# Replace icons
content = content.replace("Icons.phone_outlined", "Icons.email_outlined")

# Replace error messages
content = content.replace("return 'Илтимос, рақами телефонро ворид кунед';", "return 'Илтимос, почтаи электрониро ворид кунед';")

with open('lib/screens/login_screen.dart', 'w') as f:
    f.write(content)

print("Login Screen patched!")
