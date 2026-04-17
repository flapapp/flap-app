// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Failure {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() cache,
    required TResult Function(String? message) network,
    required TResult Function(String? message) unexpected,
    required TResult Function(String code, String? message) auth,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? cache,
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? unexpected,
    TResult? Function(String code, String? message)? auth,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? cache,
    TResult Function(String? message)? network,
    TResult Function(String? message)? unexpected,
    TResult Function(String code, String? message)? auth,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FailureCache value) cache,
    required TResult Function(FailureNetwork value) network,
    required TResult Function(FailureUnexpected value) unexpected,
    required TResult Function(FailureAuth value) auth,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FailureCache value)? cache,
    TResult? Function(FailureNetwork value)? network,
    TResult? Function(FailureUnexpected value)? unexpected,
    TResult? Function(FailureAuth value)? auth,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FailureCache value)? cache,
    TResult Function(FailureNetwork value)? network,
    TResult Function(FailureUnexpected value)? unexpected,
    TResult Function(FailureAuth value)? auth,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FailureCopyWith<$Res> {
  factory $FailureCopyWith(Failure value, $Res Function(Failure) then) =
      _$FailureCopyWithImpl<$Res, Failure>;
}

/// @nodoc
class _$FailureCopyWithImpl<$Res, $Val extends Failure>
    implements $FailureCopyWith<$Res> {
  _$FailureCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$FailureCacheImplCopyWith<$Res> {
  factory _$$FailureCacheImplCopyWith(
          _$FailureCacheImpl value, $Res Function(_$FailureCacheImpl) then) =
      __$$FailureCacheImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$FailureCacheImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$FailureCacheImpl>
    implements _$$FailureCacheImplCopyWith<$Res> {
  __$$FailureCacheImplCopyWithImpl(
      _$FailureCacheImpl _value, $Res Function(_$FailureCacheImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$FailureCacheImpl implements FailureCache {
  const _$FailureCacheImpl();

  @override
  String toString() {
    return 'Failure.cache()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$FailureCacheImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() cache,
    required TResult Function(String? message) network,
    required TResult Function(String? message) unexpected,
    required TResult Function(String code, String? message) auth,
  }) {
    return cache();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? cache,
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? unexpected,
    TResult? Function(String code, String? message)? auth,
  }) {
    return cache?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? cache,
    TResult Function(String? message)? network,
    TResult Function(String? message)? unexpected,
    TResult Function(String code, String? message)? auth,
    required TResult orElse(),
  }) {
    if (cache != null) {
      return cache();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FailureCache value) cache,
    required TResult Function(FailureNetwork value) network,
    required TResult Function(FailureUnexpected value) unexpected,
    required TResult Function(FailureAuth value) auth,
  }) {
    return cache(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FailureCache value)? cache,
    TResult? Function(FailureNetwork value)? network,
    TResult? Function(FailureUnexpected value)? unexpected,
    TResult? Function(FailureAuth value)? auth,
  }) {
    return cache?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FailureCache value)? cache,
    TResult Function(FailureNetwork value)? network,
    TResult Function(FailureUnexpected value)? unexpected,
    TResult Function(FailureAuth value)? auth,
    required TResult orElse(),
  }) {
    if (cache != null) {
      return cache(this);
    }
    return orElse();
  }
}

abstract class FailureCache implements Failure {
  const factory FailureCache() = _$FailureCacheImpl;
}

/// @nodoc
abstract class _$$FailureNetworkImplCopyWith<$Res> {
  factory _$$FailureNetworkImplCopyWith(_$FailureNetworkImpl value,
          $Res Function(_$FailureNetworkImpl) then) =
      __$$FailureNetworkImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$FailureNetworkImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$FailureNetworkImpl>
    implements _$$FailureNetworkImplCopyWith<$Res> {
  __$$FailureNetworkImplCopyWithImpl(
      _$FailureNetworkImpl _value, $Res Function(_$FailureNetworkImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$FailureNetworkImpl(
      freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$FailureNetworkImpl implements FailureNetwork {
  const _$FailureNetworkImpl([this.message]);

  @override
  final String? message;

  @override
  String toString() {
    return 'Failure.network(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FailureNetworkImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FailureNetworkImplCopyWith<_$FailureNetworkImpl> get copyWith =>
      __$$FailureNetworkImplCopyWithImpl<_$FailureNetworkImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() cache,
    required TResult Function(String? message) network,
    required TResult Function(String? message) unexpected,
    required TResult Function(String code, String? message) auth,
  }) {
    return network(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? cache,
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? unexpected,
    TResult? Function(String code, String? message)? auth,
  }) {
    return network?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? cache,
    TResult Function(String? message)? network,
    TResult Function(String? message)? unexpected,
    TResult Function(String code, String? message)? auth,
    required TResult orElse(),
  }) {
    if (network != null) {
      return network(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FailureCache value) cache,
    required TResult Function(FailureNetwork value) network,
    required TResult Function(FailureUnexpected value) unexpected,
    required TResult Function(FailureAuth value) auth,
  }) {
    return network(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FailureCache value)? cache,
    TResult? Function(FailureNetwork value)? network,
    TResult? Function(FailureUnexpected value)? unexpected,
    TResult? Function(FailureAuth value)? auth,
  }) {
    return network?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FailureCache value)? cache,
    TResult Function(FailureNetwork value)? network,
    TResult Function(FailureUnexpected value)? unexpected,
    TResult Function(FailureAuth value)? auth,
    required TResult orElse(),
  }) {
    if (network != null) {
      return network(this);
    }
    return orElse();
  }
}

abstract class FailureNetwork implements Failure {
  const factory FailureNetwork([final String? message]) = _$FailureNetworkImpl;

  String? get message;
  @JsonKey(ignore: true)
  _$$FailureNetworkImplCopyWith<_$FailureNetworkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FailureUnexpectedImplCopyWith<$Res> {
  factory _$$FailureUnexpectedImplCopyWith(_$FailureUnexpectedImpl value,
          $Res Function(_$FailureUnexpectedImpl) then) =
      __$$FailureUnexpectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$FailureUnexpectedImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$FailureUnexpectedImpl>
    implements _$$FailureUnexpectedImplCopyWith<$Res> {
  __$$FailureUnexpectedImplCopyWithImpl(_$FailureUnexpectedImpl _value,
      $Res Function(_$FailureUnexpectedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$FailureUnexpectedImpl(
      freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$FailureUnexpectedImpl implements FailureUnexpected {
  const _$FailureUnexpectedImpl([this.message]);

  @override
  final String? message;

  @override
  String toString() {
    return 'Failure.unexpected(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FailureUnexpectedImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FailureUnexpectedImplCopyWith<_$FailureUnexpectedImpl> get copyWith =>
      __$$FailureUnexpectedImplCopyWithImpl<_$FailureUnexpectedImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() cache,
    required TResult Function(String? message) network,
    required TResult Function(String? message) unexpected,
    required TResult Function(String code, String? message) auth,
  }) {
    return unexpected(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? cache,
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? unexpected,
    TResult? Function(String code, String? message)? auth,
  }) {
    return unexpected?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? cache,
    TResult Function(String? message)? network,
    TResult Function(String? message)? unexpected,
    TResult Function(String code, String? message)? auth,
    required TResult orElse(),
  }) {
    if (unexpected != null) {
      return unexpected(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FailureCache value) cache,
    required TResult Function(FailureNetwork value) network,
    required TResult Function(FailureUnexpected value) unexpected,
    required TResult Function(FailureAuth value) auth,
  }) {
    return unexpected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FailureCache value)? cache,
    TResult? Function(FailureNetwork value)? network,
    TResult? Function(FailureUnexpected value)? unexpected,
    TResult? Function(FailureAuth value)? auth,
  }) {
    return unexpected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FailureCache value)? cache,
    TResult Function(FailureNetwork value)? network,
    TResult Function(FailureUnexpected value)? unexpected,
    TResult Function(FailureAuth value)? auth,
    required TResult orElse(),
  }) {
    if (unexpected != null) {
      return unexpected(this);
    }
    return orElse();
  }
}

abstract class FailureUnexpected implements Failure {
  const factory FailureUnexpected([final String? message]) =
      _$FailureUnexpectedImpl;

  String? get message;
  @JsonKey(ignore: true)
  _$$FailureUnexpectedImplCopyWith<_$FailureUnexpectedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FailureAuthImplCopyWith<$Res> {
  factory _$$FailureAuthImplCopyWith(
          _$FailureAuthImpl value, $Res Function(_$FailureAuthImpl) then) =
      __$$FailureAuthImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String code, String? message});
}

/// @nodoc
class __$$FailureAuthImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$FailureAuthImpl>
    implements _$$FailureAuthImplCopyWith<$Res> {
  __$$FailureAuthImplCopyWithImpl(
      _$FailureAuthImpl _value, $Res Function(_$FailureAuthImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? message = freezed,
  }) {
    return _then(_$FailureAuthImpl(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$FailureAuthImpl implements FailureAuth {
  const _$FailureAuthImpl({required this.code, this.message});

  @override
  final String code;
  @override
  final String? message;

  @override
  String toString() {
    return 'Failure.auth(code: $code, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FailureAuthImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, code, message);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FailureAuthImplCopyWith<_$FailureAuthImpl> get copyWith =>
      __$$FailureAuthImplCopyWithImpl<_$FailureAuthImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() cache,
    required TResult Function(String? message) network,
    required TResult Function(String? message) unexpected,
    required TResult Function(String code, String? message) auth,
  }) {
    return auth(code, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? cache,
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? unexpected,
    TResult? Function(String code, String? message)? auth,
  }) {
    return auth?.call(code, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? cache,
    TResult Function(String? message)? network,
    TResult Function(String? message)? unexpected,
    TResult Function(String code, String? message)? auth,
    required TResult orElse(),
  }) {
    if (auth != null) {
      return auth(code, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FailureCache value) cache,
    required TResult Function(FailureNetwork value) network,
    required TResult Function(FailureUnexpected value) unexpected,
    required TResult Function(FailureAuth value) auth,
  }) {
    return auth(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FailureCache value)? cache,
    TResult? Function(FailureNetwork value)? network,
    TResult? Function(FailureUnexpected value)? unexpected,
    TResult? Function(FailureAuth value)? auth,
  }) {
    return auth?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FailureCache value)? cache,
    TResult Function(FailureNetwork value)? network,
    TResult Function(FailureUnexpected value)? unexpected,
    TResult Function(FailureAuth value)? auth,
    required TResult orElse(),
  }) {
    if (auth != null) {
      return auth(this);
    }
    return orElse();
  }
}

abstract class FailureAuth implements Failure {
  const factory FailureAuth(
      {required final String code, final String? message}) = _$FailureAuthImpl;

  String get code;
  String? get message;
  @JsonKey(ignore: true)
  _$$FailureAuthImplCopyWith<_$FailureAuthImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
