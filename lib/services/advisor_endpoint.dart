import 'package:flutter/foundation.dart';

Uri get advisorEndpoint {
  const path = '/.netlify/functions/advisor';
  return kIsWeb
      ? Uri.base.resolve(path)
      : Uri.https('tigerpath.netlify.app', path);
}
