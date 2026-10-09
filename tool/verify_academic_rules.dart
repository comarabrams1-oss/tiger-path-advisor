import '../test/academic_regression_cases.dart';

void main() {
  var passed = 0;
  registerAcademicRegressionCases((name, body) {
    body();
    passed++;
    print('PASS: $name');
  });
  print('$passed regression cases passed.');
}
