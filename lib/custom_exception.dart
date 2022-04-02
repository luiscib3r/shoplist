class CustomException implements Exception {
  CustomException({this.message = 'Something went wrong!'});

  final String? message;

  @override
  String toString() => 'CustomException { message: $message }';
}
