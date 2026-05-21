كل ما أبدأ مشروع Flutter، بضيّع ساعات في نفس الشغل:

أفتح Postman/Apidog، أنسخ كل endpoint، أكتب Action class، أعمل response model... وأكرر.

ده شغل ممل وممكن يتأتمت.

عملت أداة صغيرة اسمها api_to_dart — CLI بياخد Postman أو OpenAPI أو Apidog وبيطلّعلك الكود جاهز.

اللي بتعمله:
- تختار endpoints من الـterminal
- بترسل request فعلي وتولّد الـmodel من الـresponse
- لو مفيش api_request في مشروعك، بتولّد response model بس

```
dart pub global activate api_to_dart
api2dart generate
```

لينك الـpackage: [link]
GitHub: github.com/abdo-ahmed-it/api_to_dart

لو جربتها وفي feedback، يا ريت تقولي.

#Flutter #Dart
