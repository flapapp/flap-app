// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ProfileEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() started,
    required TResult Function() donationPromptDismissRequested,
    required TResult Function(String downloadUrl) avatarCommitted,
    required TResult Function() userProfileSyncRequested,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? started,
    TResult? Function()? donationPromptDismissRequested,
    TResult? Function(String downloadUrl)? avatarCommitted,
    TResult? Function()? userProfileSyncRequested,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? started,
    TResult Function()? donationPromptDismissRequested,
    TResult Function(String downloadUrl)? avatarCommitted,
    TResult Function()? userProfileSyncRequested,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ProfileStarted value) started,
    required TResult Function(ProfileDonationPromptDismissRequested value)
        donationPromptDismissRequested,
    required TResult Function(ProfileAvatarCommitted value) avatarCommitted,
    required TResult Function(ProfileUserProfileSyncRequested value)
        userProfileSyncRequested,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ProfileStarted value)? started,
    TResult? Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult? Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult? Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ProfileStarted value)? started,
    TResult Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileEventCopyWith<$Res> {
  factory $ProfileEventCopyWith(
          ProfileEvent value, $Res Function(ProfileEvent) then) =
      _$ProfileEventCopyWithImpl<$Res, ProfileEvent>;
}

/// @nodoc
class _$ProfileEventCopyWithImpl<$Res, $Val extends ProfileEvent>
    implements $ProfileEventCopyWith<$Res> {
  _$ProfileEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$ProfileStartedImplCopyWith<$Res> {
  factory _$$ProfileStartedImplCopyWith(_$ProfileStartedImpl value,
          $Res Function(_$ProfileStartedImpl) then) =
      __$$ProfileStartedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ProfileStartedImplCopyWithImpl<$Res>
    extends _$ProfileEventCopyWithImpl<$Res, _$ProfileStartedImpl>
    implements _$$ProfileStartedImplCopyWith<$Res> {
  __$$ProfileStartedImplCopyWithImpl(
      _$ProfileStartedImpl _value, $Res Function(_$ProfileStartedImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$ProfileStartedImpl implements ProfileStarted {
  const _$ProfileStartedImpl();

  @override
  String toString() {
    return 'ProfileEvent.started()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ProfileStartedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() started,
    required TResult Function() donationPromptDismissRequested,
    required TResult Function(String downloadUrl) avatarCommitted,
    required TResult Function() userProfileSyncRequested,
  }) {
    return started();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? started,
    TResult? Function()? donationPromptDismissRequested,
    TResult? Function(String downloadUrl)? avatarCommitted,
    TResult? Function()? userProfileSyncRequested,
  }) {
    return started?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? started,
    TResult Function()? donationPromptDismissRequested,
    TResult Function(String downloadUrl)? avatarCommitted,
    TResult Function()? userProfileSyncRequested,
    required TResult orElse(),
  }) {
    if (started != null) {
      return started();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ProfileStarted value) started,
    required TResult Function(ProfileDonationPromptDismissRequested value)
        donationPromptDismissRequested,
    required TResult Function(ProfileAvatarCommitted value) avatarCommitted,
    required TResult Function(ProfileUserProfileSyncRequested value)
        userProfileSyncRequested,
  }) {
    return started(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ProfileStarted value)? started,
    TResult? Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult? Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult? Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
  }) {
    return started?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ProfileStarted value)? started,
    TResult Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
    required TResult orElse(),
  }) {
    if (started != null) {
      return started(this);
    }
    return orElse();
  }
}

abstract class ProfileStarted implements ProfileEvent {
  const factory ProfileStarted() = _$ProfileStartedImpl;
}

/// @nodoc
abstract class _$$ProfileDonationPromptDismissRequestedImplCopyWith<$Res> {
  factory _$$ProfileDonationPromptDismissRequestedImplCopyWith(
          _$ProfileDonationPromptDismissRequestedImpl value,
          $Res Function(_$ProfileDonationPromptDismissRequestedImpl) then) =
      __$$ProfileDonationPromptDismissRequestedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ProfileDonationPromptDismissRequestedImplCopyWithImpl<$Res>
    extends _$ProfileEventCopyWithImpl<$Res,
        _$ProfileDonationPromptDismissRequestedImpl>
    implements _$$ProfileDonationPromptDismissRequestedImplCopyWith<$Res> {
  __$$ProfileDonationPromptDismissRequestedImplCopyWithImpl(
      _$ProfileDonationPromptDismissRequestedImpl _value,
      $Res Function(_$ProfileDonationPromptDismissRequestedImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$ProfileDonationPromptDismissRequestedImpl
    implements ProfileDonationPromptDismissRequested {
  const _$ProfileDonationPromptDismissRequestedImpl();

  @override
  String toString() {
    return 'ProfileEvent.donationPromptDismissRequested()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileDonationPromptDismissRequestedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() started,
    required TResult Function() donationPromptDismissRequested,
    required TResult Function(String downloadUrl) avatarCommitted,
    required TResult Function() userProfileSyncRequested,
  }) {
    return donationPromptDismissRequested();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? started,
    TResult? Function()? donationPromptDismissRequested,
    TResult? Function(String downloadUrl)? avatarCommitted,
    TResult? Function()? userProfileSyncRequested,
  }) {
    return donationPromptDismissRequested?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? started,
    TResult Function()? donationPromptDismissRequested,
    TResult Function(String downloadUrl)? avatarCommitted,
    TResult Function()? userProfileSyncRequested,
    required TResult orElse(),
  }) {
    if (donationPromptDismissRequested != null) {
      return donationPromptDismissRequested();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ProfileStarted value) started,
    required TResult Function(ProfileDonationPromptDismissRequested value)
        donationPromptDismissRequested,
    required TResult Function(ProfileAvatarCommitted value) avatarCommitted,
    required TResult Function(ProfileUserProfileSyncRequested value)
        userProfileSyncRequested,
  }) {
    return donationPromptDismissRequested(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ProfileStarted value)? started,
    TResult? Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult? Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult? Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
  }) {
    return donationPromptDismissRequested?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ProfileStarted value)? started,
    TResult Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
    required TResult orElse(),
  }) {
    if (donationPromptDismissRequested != null) {
      return donationPromptDismissRequested(this);
    }
    return orElse();
  }
}

abstract class ProfileDonationPromptDismissRequested implements ProfileEvent {
  const factory ProfileDonationPromptDismissRequested() =
      _$ProfileDonationPromptDismissRequestedImpl;
}

/// @nodoc
abstract class _$$ProfileAvatarCommittedImplCopyWith<$Res> {
  factory _$$ProfileAvatarCommittedImplCopyWith(
          _$ProfileAvatarCommittedImpl value,
          $Res Function(_$ProfileAvatarCommittedImpl) then) =
      __$$ProfileAvatarCommittedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String downloadUrl});
}

/// @nodoc
class __$$ProfileAvatarCommittedImplCopyWithImpl<$Res>
    extends _$ProfileEventCopyWithImpl<$Res, _$ProfileAvatarCommittedImpl>
    implements _$$ProfileAvatarCommittedImplCopyWith<$Res> {
  __$$ProfileAvatarCommittedImplCopyWithImpl(
      _$ProfileAvatarCommittedImpl _value,
      $Res Function(_$ProfileAvatarCommittedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadUrl = null,
  }) {
    return _then(_$ProfileAvatarCommittedImpl(
      downloadUrl: null == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ProfileAvatarCommittedImpl implements ProfileAvatarCommitted {
  const _$ProfileAvatarCommittedImpl({required this.downloadUrl});

  @override
  final String downloadUrl;

  @override
  String toString() {
    return 'ProfileEvent.avatarCommitted(downloadUrl: $downloadUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileAvatarCommittedImpl &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl));
  }

  @override
  int get hashCode => Object.hash(runtimeType, downloadUrl);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileAvatarCommittedImplCopyWith<_$ProfileAvatarCommittedImpl>
      get copyWith => __$$ProfileAvatarCommittedImplCopyWithImpl<
          _$ProfileAvatarCommittedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() started,
    required TResult Function() donationPromptDismissRequested,
    required TResult Function(String downloadUrl) avatarCommitted,
    required TResult Function() userProfileSyncRequested,
  }) {
    return avatarCommitted(downloadUrl);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? started,
    TResult? Function()? donationPromptDismissRequested,
    TResult? Function(String downloadUrl)? avatarCommitted,
    TResult? Function()? userProfileSyncRequested,
  }) {
    return avatarCommitted?.call(downloadUrl);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? started,
    TResult Function()? donationPromptDismissRequested,
    TResult Function(String downloadUrl)? avatarCommitted,
    TResult Function()? userProfileSyncRequested,
    required TResult orElse(),
  }) {
    if (avatarCommitted != null) {
      return avatarCommitted(downloadUrl);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ProfileStarted value) started,
    required TResult Function(ProfileDonationPromptDismissRequested value)
        donationPromptDismissRequested,
    required TResult Function(ProfileAvatarCommitted value) avatarCommitted,
    required TResult Function(ProfileUserProfileSyncRequested value)
        userProfileSyncRequested,
  }) {
    return avatarCommitted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ProfileStarted value)? started,
    TResult? Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult? Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult? Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
  }) {
    return avatarCommitted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ProfileStarted value)? started,
    TResult Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
    required TResult orElse(),
  }) {
    if (avatarCommitted != null) {
      return avatarCommitted(this);
    }
    return orElse();
  }
}

abstract class ProfileAvatarCommitted implements ProfileEvent {
  const factory ProfileAvatarCommitted({required final String downloadUrl}) =
      _$ProfileAvatarCommittedImpl;

  String get downloadUrl;
  @JsonKey(ignore: true)
  _$$ProfileAvatarCommittedImplCopyWith<_$ProfileAvatarCommittedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ProfileUserProfileSyncRequestedImplCopyWith<$Res> {
  factory _$$ProfileUserProfileSyncRequestedImplCopyWith(
          _$ProfileUserProfileSyncRequestedImpl value,
          $Res Function(_$ProfileUserProfileSyncRequestedImpl) then) =
      __$$ProfileUserProfileSyncRequestedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ProfileUserProfileSyncRequestedImplCopyWithImpl<$Res>
    extends _$ProfileEventCopyWithImpl<$Res,
        _$ProfileUserProfileSyncRequestedImpl>
    implements _$$ProfileUserProfileSyncRequestedImplCopyWith<$Res> {
  __$$ProfileUserProfileSyncRequestedImplCopyWithImpl(
      _$ProfileUserProfileSyncRequestedImpl _value,
      $Res Function(_$ProfileUserProfileSyncRequestedImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$ProfileUserProfileSyncRequestedImpl
    implements ProfileUserProfileSyncRequested {
  const _$ProfileUserProfileSyncRequestedImpl();

  @override
  String toString() {
    return 'ProfileEvent.userProfileSyncRequested()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileUserProfileSyncRequestedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() started,
    required TResult Function() donationPromptDismissRequested,
    required TResult Function(String downloadUrl) avatarCommitted,
    required TResult Function() userProfileSyncRequested,
  }) {
    return userProfileSyncRequested();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? started,
    TResult? Function()? donationPromptDismissRequested,
    TResult? Function(String downloadUrl)? avatarCommitted,
    TResult? Function()? userProfileSyncRequested,
  }) {
    return userProfileSyncRequested?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? started,
    TResult Function()? donationPromptDismissRequested,
    TResult Function(String downloadUrl)? avatarCommitted,
    TResult Function()? userProfileSyncRequested,
    required TResult orElse(),
  }) {
    if (userProfileSyncRequested != null) {
      return userProfileSyncRequested();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ProfileStarted value) started,
    required TResult Function(ProfileDonationPromptDismissRequested value)
        donationPromptDismissRequested,
    required TResult Function(ProfileAvatarCommitted value) avatarCommitted,
    required TResult Function(ProfileUserProfileSyncRequested value)
        userProfileSyncRequested,
  }) {
    return userProfileSyncRequested(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ProfileStarted value)? started,
    TResult? Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult? Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult? Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
  }) {
    return userProfileSyncRequested?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ProfileStarted value)? started,
    TResult Function(ProfileDonationPromptDismissRequested value)?
        donationPromptDismissRequested,
    TResult Function(ProfileAvatarCommitted value)? avatarCommitted,
    TResult Function(ProfileUserProfileSyncRequested value)?
        userProfileSyncRequested,
    required TResult orElse(),
  }) {
    if (userProfileSyncRequested != null) {
      return userProfileSyncRequested(this);
    }
    return orElse();
  }
}

abstract class ProfileUserProfileSyncRequested implements ProfileEvent {
  const factory ProfileUserProfileSyncRequested() =
      _$ProfileUserProfileSyncRequestedImpl;
}

/// @nodoc
mixin _$ProfileState {
  ProgressStatus get streamProgress => throw _privateConstructorUsedError;
  UserProfile? get profile => throw _privateConstructorUsedError;
  Failure? get streamFailure => throw _privateConstructorUsedError;
  ProgressStatus get dismissDonationProgress =>
      throw _privateConstructorUsedError;
  Failure? get dismissDonationFailure => throw _privateConstructorUsedError;
  ProgressStatus get avatarCommitProgress => throw _privateConstructorUsedError;
  Failure? get avatarCommitFailure => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ProfileStateCopyWith<ProfileState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileStateCopyWith<$Res> {
  factory $ProfileStateCopyWith(
          ProfileState value, $Res Function(ProfileState) then) =
      _$ProfileStateCopyWithImpl<$Res, ProfileState>;
  @useResult
  $Res call(
      {ProgressStatus streamProgress,
      UserProfile? profile,
      Failure? streamFailure,
      ProgressStatus dismissDonationProgress,
      Failure? dismissDonationFailure,
      ProgressStatus avatarCommitProgress,
      Failure? avatarCommitFailure});

  $FailureCopyWith<$Res>? get streamFailure;
  $FailureCopyWith<$Res>? get dismissDonationFailure;
  $FailureCopyWith<$Res>? get avatarCommitFailure;
}

/// @nodoc
class _$ProfileStateCopyWithImpl<$Res, $Val extends ProfileState>
    implements $ProfileStateCopyWith<$Res> {
  _$ProfileStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? streamProgress = null,
    Object? profile = freezed,
    Object? streamFailure = freezed,
    Object? dismissDonationProgress = null,
    Object? dismissDonationFailure = freezed,
    Object? avatarCommitProgress = null,
    Object? avatarCommitFailure = freezed,
  }) {
    return _then(_value.copyWith(
      streamProgress: null == streamProgress
          ? _value.streamProgress
          : streamProgress // ignore: cast_nullable_to_non_nullable
              as ProgressStatus,
      profile: freezed == profile
          ? _value.profile
          : profile // ignore: cast_nullable_to_non_nullable
              as UserProfile?,
      streamFailure: freezed == streamFailure
          ? _value.streamFailure
          : streamFailure // ignore: cast_nullable_to_non_nullable
              as Failure?,
      dismissDonationProgress: null == dismissDonationProgress
          ? _value.dismissDonationProgress
          : dismissDonationProgress // ignore: cast_nullable_to_non_nullable
              as ProgressStatus,
      dismissDonationFailure: freezed == dismissDonationFailure
          ? _value.dismissDonationFailure
          : dismissDonationFailure // ignore: cast_nullable_to_non_nullable
              as Failure?,
      avatarCommitProgress: null == avatarCommitProgress
          ? _value.avatarCommitProgress
          : avatarCommitProgress // ignore: cast_nullable_to_non_nullable
              as ProgressStatus,
      avatarCommitFailure: freezed == avatarCommitFailure
          ? _value.avatarCommitFailure
          : avatarCommitFailure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $FailureCopyWith<$Res>? get streamFailure {
    if (_value.streamFailure == null) {
      return null;
    }

    return $FailureCopyWith<$Res>(_value.streamFailure!, (value) {
      return _then(_value.copyWith(streamFailure: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $FailureCopyWith<$Res>? get dismissDonationFailure {
    if (_value.dismissDonationFailure == null) {
      return null;
    }

    return $FailureCopyWith<$Res>(_value.dismissDonationFailure!, (value) {
      return _then(_value.copyWith(dismissDonationFailure: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $FailureCopyWith<$Res>? get avatarCommitFailure {
    if (_value.avatarCommitFailure == null) {
      return null;
    }

    return $FailureCopyWith<$Res>(_value.avatarCommitFailure!, (value) {
      return _then(_value.copyWith(avatarCommitFailure: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ProfileStateImplCopyWith<$Res>
    implements $ProfileStateCopyWith<$Res> {
  factory _$$ProfileStateImplCopyWith(
          _$ProfileStateImpl value, $Res Function(_$ProfileStateImpl) then) =
      __$$ProfileStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ProgressStatus streamProgress,
      UserProfile? profile,
      Failure? streamFailure,
      ProgressStatus dismissDonationProgress,
      Failure? dismissDonationFailure,
      ProgressStatus avatarCommitProgress,
      Failure? avatarCommitFailure});

  @override
  $FailureCopyWith<$Res>? get streamFailure;
  @override
  $FailureCopyWith<$Res>? get dismissDonationFailure;
  @override
  $FailureCopyWith<$Res>? get avatarCommitFailure;
}

/// @nodoc
class __$$ProfileStateImplCopyWithImpl<$Res>
    extends _$ProfileStateCopyWithImpl<$Res, _$ProfileStateImpl>
    implements _$$ProfileStateImplCopyWith<$Res> {
  __$$ProfileStateImplCopyWithImpl(
      _$ProfileStateImpl _value, $Res Function(_$ProfileStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? streamProgress = null,
    Object? profile = freezed,
    Object? streamFailure = freezed,
    Object? dismissDonationProgress = null,
    Object? dismissDonationFailure = freezed,
    Object? avatarCommitProgress = null,
    Object? avatarCommitFailure = freezed,
  }) {
    return _then(_$ProfileStateImpl(
      streamProgress: null == streamProgress
          ? _value.streamProgress
          : streamProgress // ignore: cast_nullable_to_non_nullable
              as ProgressStatus,
      profile: freezed == profile
          ? _value.profile
          : profile // ignore: cast_nullable_to_non_nullable
              as UserProfile?,
      streamFailure: freezed == streamFailure
          ? _value.streamFailure
          : streamFailure // ignore: cast_nullable_to_non_nullable
              as Failure?,
      dismissDonationProgress: null == dismissDonationProgress
          ? _value.dismissDonationProgress
          : dismissDonationProgress // ignore: cast_nullable_to_non_nullable
              as ProgressStatus,
      dismissDonationFailure: freezed == dismissDonationFailure
          ? _value.dismissDonationFailure
          : dismissDonationFailure // ignore: cast_nullable_to_non_nullable
              as Failure?,
      avatarCommitProgress: null == avatarCommitProgress
          ? _value.avatarCommitProgress
          : avatarCommitProgress // ignore: cast_nullable_to_non_nullable
              as ProgressStatus,
      avatarCommitFailure: freezed == avatarCommitFailure
          ? _value.avatarCommitFailure
          : avatarCommitFailure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// @nodoc

class _$ProfileStateImpl implements _ProfileState {
  const _$ProfileStateImpl(
      {this.streamProgress = ProgressStatus.pure,
      this.profile,
      this.streamFailure,
      this.dismissDonationProgress = ProgressStatus.pure,
      this.dismissDonationFailure,
      this.avatarCommitProgress = ProgressStatus.pure,
      this.avatarCommitFailure});

  @override
  @JsonKey()
  final ProgressStatus streamProgress;
  @override
  final UserProfile? profile;
  @override
  final Failure? streamFailure;
  @override
  @JsonKey()
  final ProgressStatus dismissDonationProgress;
  @override
  final Failure? dismissDonationFailure;
  @override
  @JsonKey()
  final ProgressStatus avatarCommitProgress;
  @override
  final Failure? avatarCommitFailure;

  @override
  String toString() {
    return 'ProfileState(streamProgress: $streamProgress, profile: $profile, streamFailure: $streamFailure, dismissDonationProgress: $dismissDonationProgress, dismissDonationFailure: $dismissDonationFailure, avatarCommitProgress: $avatarCommitProgress, avatarCommitFailure: $avatarCommitFailure)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileStateImpl &&
            (identical(other.streamProgress, streamProgress) ||
                other.streamProgress == streamProgress) &&
            (identical(other.profile, profile) || other.profile == profile) &&
            (identical(other.streamFailure, streamFailure) ||
                other.streamFailure == streamFailure) &&
            (identical(
                    other.dismissDonationProgress, dismissDonationProgress) ||
                other.dismissDonationProgress == dismissDonationProgress) &&
            (identical(other.dismissDonationFailure, dismissDonationFailure) ||
                other.dismissDonationFailure == dismissDonationFailure) &&
            (identical(other.avatarCommitProgress, avatarCommitProgress) ||
                other.avatarCommitProgress == avatarCommitProgress) &&
            (identical(other.avatarCommitFailure, avatarCommitFailure) ||
                other.avatarCommitFailure == avatarCommitFailure));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      streamProgress,
      profile,
      streamFailure,
      dismissDonationProgress,
      dismissDonationFailure,
      avatarCommitProgress,
      avatarCommitFailure);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileStateImplCopyWith<_$ProfileStateImpl> get copyWith =>
      __$$ProfileStateImplCopyWithImpl<_$ProfileStateImpl>(this, _$identity);
}

abstract class _ProfileState implements ProfileState {
  const factory _ProfileState(
      {final ProgressStatus streamProgress,
      final UserProfile? profile,
      final Failure? streamFailure,
      final ProgressStatus dismissDonationProgress,
      final Failure? dismissDonationFailure,
      final ProgressStatus avatarCommitProgress,
      final Failure? avatarCommitFailure}) = _$ProfileStateImpl;

  @override
  ProgressStatus get streamProgress;
  @override
  UserProfile? get profile;
  @override
  Failure? get streamFailure;
  @override
  ProgressStatus get dismissDonationProgress;
  @override
  Failure? get dismissDonationFailure;
  @override
  ProgressStatus get avatarCommitProgress;
  @override
  Failure? get avatarCommitFailure;
  @override
  @JsonKey(ignore: true)
  _$$ProfileStateImplCopyWith<_$ProfileStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
