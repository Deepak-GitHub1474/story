sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => this is Success<T> ? (this as Success<T>).value : null;

  Failure<T>? get failureOrNull => this is Failure<T> ? this as Failure<T> : null;

  R fold<R>({
    required R Function(Success<T> success) onSuccess,
    required R Function(Failure<T> failure) onFailure,
  }) {
    final self = this;
    return self is Success<T> ? onSuccess(self) : onFailure(self as Failure<T>);
  }
}

class Success<T> extends Result<T> {
  const Success(this.value, {this.message = ''});

  final T value;
  final String message;
}

class Failure<T> extends Result<T> {
  const Failure({
    required this.code,
    required this.message,
    this.field,
    this.fields = const [],
    this.statusCode,
  });

  final String code;
  final String message;
  final String? field;
  final List<FieldError> fields;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  Failure<R> cast<R>() => Failure<R>(
    code: code,
    message: message,
    field: field,
    fields: fields,
    statusCode: statusCode,
  );
}

class FieldError {
  const FieldError({required this.field, required this.code, required this.message});

  factory FieldError.fromJson(Map<String, dynamic> json) => FieldError(
    field: json['field'] as String? ?? '',
    code: json['code'] as String? ?? '',
    message: json['message'] as String? ?? '',
  );

  final String field;
  final String code;
  final String message;
}
