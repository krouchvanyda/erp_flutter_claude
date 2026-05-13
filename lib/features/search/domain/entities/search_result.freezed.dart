// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SearchResult {
  /// Stable identity within [providerId] — used for keying widgets and
  /// deduping within a provider's own response.
  String get id => throw _privateConstructorUsedError;

  /// Primary line shown in the result tile.
  String get title => throw _privateConstructorUsedError;

  /// Optional secondary line (record code, customer name, etc.).
  String? get subtitle => throw _privateConstructorUsedError;

  /// Which provider produced this row — drives grouping in the UI.
  String get providerId => throw _privateConstructorUsedError;

  /// `go_router` named route to push when the user taps the result.
  String get routeName => throw _privateConstructorUsedError;

  /// Path parameters passed alongside [routeName].
  Map<String, String> get pathParameters => throw _privateConstructorUsedError;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchResultCopyWith<SearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResultCopyWith<$Res> {
  factory $SearchResultCopyWith(
    SearchResult value,
    $Res Function(SearchResult) then,
  ) = _$SearchResultCopyWithImpl<$Res, SearchResult>;
  @useResult
  $Res call({
    String id,
    String title,
    String? subtitle,
    String providerId,
    String routeName,
    Map<String, String> pathParameters,
  });
}

/// @nodoc
class _$SearchResultCopyWithImpl<$Res, $Val extends SearchResult>
    implements $SearchResultCopyWith<$Res> {
  _$SearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? subtitle = freezed,
    Object? providerId = null,
    Object? routeName = null,
    Object? pathParameters = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            subtitle: freezed == subtitle
                ? _value.subtitle
                : subtitle // ignore: cast_nullable_to_non_nullable
                      as String?,
            providerId: null == providerId
                ? _value.providerId
                : providerId // ignore: cast_nullable_to_non_nullable
                      as String,
            routeName: null == routeName
                ? _value.routeName
                : routeName // ignore: cast_nullable_to_non_nullable
                      as String,
            pathParameters: null == pathParameters
                ? _value.pathParameters
                : pathParameters // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SearchResultImplCopyWith<$Res>
    implements $SearchResultCopyWith<$Res> {
  factory _$$SearchResultImplCopyWith(
    _$SearchResultImpl value,
    $Res Function(_$SearchResultImpl) then,
  ) = __$$SearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? subtitle,
    String providerId,
    String routeName,
    Map<String, String> pathParameters,
  });
}

/// @nodoc
class __$$SearchResultImplCopyWithImpl<$Res>
    extends _$SearchResultCopyWithImpl<$Res, _$SearchResultImpl>
    implements _$$SearchResultImplCopyWith<$Res> {
  __$$SearchResultImplCopyWithImpl(
    _$SearchResultImpl _value,
    $Res Function(_$SearchResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? subtitle = freezed,
    Object? providerId = null,
    Object? routeName = null,
    Object? pathParameters = null,
  }) {
    return _then(
      _$SearchResultImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        subtitle: freezed == subtitle
            ? _value.subtitle
            : subtitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        providerId: null == providerId
            ? _value.providerId
            : providerId // ignore: cast_nullable_to_non_nullable
                  as String,
        routeName: null == routeName
            ? _value.routeName
            : routeName // ignore: cast_nullable_to_non_nullable
                  as String,
        pathParameters: null == pathParameters
            ? _value._pathParameters
            : pathParameters // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
      ),
    );
  }
}

/// @nodoc

class _$SearchResultImpl implements _SearchResult {
  const _$SearchResultImpl({
    required this.id,
    required this.title,
    this.subtitle,
    required this.providerId,
    required this.routeName,
    final Map<String, String> pathParameters = const <String, String>{},
  }) : _pathParameters = pathParameters;

  /// Stable identity within [providerId] — used for keying widgets and
  /// deduping within a provider's own response.
  @override
  final String id;

  /// Primary line shown in the result tile.
  @override
  final String title;

  /// Optional secondary line (record code, customer name, etc.).
  @override
  final String? subtitle;

  /// Which provider produced this row — drives grouping in the UI.
  @override
  final String providerId;

  /// `go_router` named route to push when the user taps the result.
  @override
  final String routeName;

  /// Path parameters passed alongside [routeName].
  final Map<String, String> _pathParameters;

  /// Path parameters passed alongside [routeName].
  @override
  @JsonKey()
  Map<String, String> get pathParameters {
    if (_pathParameters is EqualUnmodifiableMapView) return _pathParameters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_pathParameters);
  }

  @override
  String toString() {
    return 'SearchResult(id: $id, title: $title, subtitle: $subtitle, providerId: $providerId, routeName: $routeName, pathParameters: $pathParameters)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.providerId, providerId) ||
                other.providerId == providerId) &&
            (identical(other.routeName, routeName) ||
                other.routeName == routeName) &&
            const DeepCollectionEquality().equals(
              other._pathParameters,
              _pathParameters,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    subtitle,
    providerId,
    routeName,
    const DeepCollectionEquality().hash(_pathParameters),
  );

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      __$$SearchResultImplCopyWithImpl<_$SearchResultImpl>(this, _$identity);
}

abstract class _SearchResult implements SearchResult {
  const factory _SearchResult({
    required final String id,
    required final String title,
    final String? subtitle,
    required final String providerId,
    required final String routeName,
    final Map<String, String> pathParameters,
  }) = _$SearchResultImpl;

  /// Stable identity within [providerId] — used for keying widgets and
  /// deduping within a provider's own response.
  @override
  String get id;

  /// Primary line shown in the result tile.
  @override
  String get title;

  /// Optional secondary line (record code, customer name, etc.).
  @override
  String? get subtitle;

  /// Which provider produced this row — drives grouping in the UI.
  @override
  String get providerId;

  /// `go_router` named route to push when the user taps the result.
  @override
  String get routeName;

  /// Path parameters passed alongside [routeName].
  @override
  Map<String, String> get pathParameters;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SearchResultGroup {
  String get providerId => throw _privateConstructorUsedError;
  List<SearchResult> get results => throw _privateConstructorUsedError;

  /// Create a copy of SearchResultGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchResultGroupCopyWith<SearchResultGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResultGroupCopyWith<$Res> {
  factory $SearchResultGroupCopyWith(
    SearchResultGroup value,
    $Res Function(SearchResultGroup) then,
  ) = _$SearchResultGroupCopyWithImpl<$Res, SearchResultGroup>;
  @useResult
  $Res call({String providerId, List<SearchResult> results});
}

/// @nodoc
class _$SearchResultGroupCopyWithImpl<$Res, $Val extends SearchResultGroup>
    implements $SearchResultGroupCopyWith<$Res> {
  _$SearchResultGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchResultGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? providerId = null, Object? results = null}) {
    return _then(
      _value.copyWith(
            providerId: null == providerId
                ? _value.providerId
                : providerId // ignore: cast_nullable_to_non_nullable
                      as String,
            results: null == results
                ? _value.results
                : results // ignore: cast_nullable_to_non_nullable
                      as List<SearchResult>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SearchResultGroupImplCopyWith<$Res>
    implements $SearchResultGroupCopyWith<$Res> {
  factory _$$SearchResultGroupImplCopyWith(
    _$SearchResultGroupImpl value,
    $Res Function(_$SearchResultGroupImpl) then,
  ) = __$$SearchResultGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String providerId, List<SearchResult> results});
}

/// @nodoc
class __$$SearchResultGroupImplCopyWithImpl<$Res>
    extends _$SearchResultGroupCopyWithImpl<$Res, _$SearchResultGroupImpl>
    implements _$$SearchResultGroupImplCopyWith<$Res> {
  __$$SearchResultGroupImplCopyWithImpl(
    _$SearchResultGroupImpl _value,
    $Res Function(_$SearchResultGroupImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SearchResultGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? providerId = null, Object? results = null}) {
    return _then(
      _$SearchResultGroupImpl(
        providerId: null == providerId
            ? _value.providerId
            : providerId // ignore: cast_nullable_to_non_nullable
                  as String,
        results: null == results
            ? _value._results
            : results // ignore: cast_nullable_to_non_nullable
                  as List<SearchResult>,
      ),
    );
  }
}

/// @nodoc

class _$SearchResultGroupImpl implements _SearchResultGroup {
  const _$SearchResultGroupImpl({
    required this.providerId,
    required final List<SearchResult> results,
  }) : _results = results;

  @override
  final String providerId;
  final List<SearchResult> _results;
  @override
  List<SearchResult> get results {
    if (_results is EqualUnmodifiableListView) return _results;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_results);
  }

  @override
  String toString() {
    return 'SearchResultGroup(providerId: $providerId, results: $results)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResultGroupImpl &&
            (identical(other.providerId, providerId) ||
                other.providerId == providerId) &&
            const DeepCollectionEquality().equals(other._results, _results));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    providerId,
    const DeepCollectionEquality().hash(_results),
  );

  /// Create a copy of SearchResultGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResultGroupImplCopyWith<_$SearchResultGroupImpl> get copyWith =>
      __$$SearchResultGroupImplCopyWithImpl<_$SearchResultGroupImpl>(
        this,
        _$identity,
      );
}

abstract class _SearchResultGroup implements SearchResultGroup {
  const factory _SearchResultGroup({
    required final String providerId,
    required final List<SearchResult> results,
  }) = _$SearchResultGroupImpl;

  @override
  String get providerId;
  @override
  List<SearchResult> get results;

  /// Create a copy of SearchResultGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchResultGroupImplCopyWith<_$SearchResultGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
