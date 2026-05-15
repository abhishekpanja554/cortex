// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'note.dart';

// **************************************************************************
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Note {

 String get id; String get title; String get content; DateTime get createdAt; DateTime? get updatedAt; String? get coverImage; List<Block> get blocks; List<String> get tags;
/// Create a copy of Note
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteCopyWith<Note> get copyWith => _$NoteCopyWithImpl<Note>(this as Note, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Note&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.coverImage, coverImage) || other.coverImage == coverImage)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&const DeepCollectionEquality().equals(other.tags, tags));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,content,createdAt,updatedAt,coverImage,const DeepCollectionEquality().hash(blocks),const DeepCollectionEquality().hash(tags));

@override
String toString() {
  return 'Note(id: $id, title: $title, content: $content, createdAt: $createdAt, updatedAt: $updatedAt, coverImage: $coverImage, blocks: $blocks, tags: $tags)';
}


}

/// @nodoc
abstract mixin class $NoteCopyWith<$Res>  {
  factory $NoteCopyWith(Note value, $Res Function(Note) _then) = _$NoteCopyWithImpl;
@useResult
$Res call({
 String id, String title, String content, DateTime createdAt, DateTime? updatedAt, String? coverImage, List<Block> blocks, List<String> tags
});




}
/// @nodoc
class _$NoteCopyWithImpl<$Res>
    implements $NoteCopyWith<$Res> {
  _$NoteCopyWithImpl(this._self, this._then);

  final Note _self;
  final $Res Function(Note) _then;

/// Create a copy of Note
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? content = null,Object? createdAt = null,Object? updatedAt = freezed,Object? coverImage = freezed,Object? blocks = null,Object? tags = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,coverImage: freezed == coverImage ? _self.coverImage : coverImage // ignore: cast_nullable_to_non_nullable
as String?,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<Block>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Note].
extension NotePatterns on Note {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Note value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Note() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Note value)  $default,){
final _that = this;
switch (_that) {
case _Note():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Note value)?  $default,){
final _that = this;
switch (_that) {
case _Note() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String content,  DateTime createdAt,  DateTime? updatedAt,  String? coverImage,  List<Block> blocks,  List<String> tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Note() when $default != null:
return $default(_that.id,_that.title,_that.content,_that.createdAt,_that.updatedAt,_that.coverImage,_that.blocks,_that.tags);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String content,  DateTime createdAt,  DateTime? updatedAt,  String? coverImage,  List<Block> blocks,  List<String> tags)  $default,) {final _that = this;
switch (_that) {
case _Note():
return $default(_that.id,_that.title,_that.content,_that.createdAt,_that.updatedAt,_that.coverImage,_that.blocks,_that.tags);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String content,  DateTime createdAt,  DateTime? updatedAt,  String? coverImage,  List<Block> blocks,  List<String> tags)?  $default,) {final _that = this;
switch (_that) {
case _Note() when $default != null:
return $default(_that.id,_that.title,_that.content,_that.createdAt,_that.updatedAt,_that.coverImage,_that.blocks,_that.tags);case _:
  return null;

}
}

}

/// @nodoc


class _Note extends Note {
  const _Note({required this.id, required this.title, required this.content, required this.createdAt, this.updatedAt, this.coverImage, final  List<Block> blocks = const [], final  List<String> tags = const []}): _blocks = blocks,_tags = tags,super._();
  

@override final  String id;
@override final  String title;
@override final  String content;
@override final  DateTime createdAt;
@override final  DateTime? updatedAt;
@override final  String? coverImage;
 final  List<Block> _blocks;
@override@JsonKey() List<Block> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}


/// Create a copy of Note
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NoteCopyWith<_Note> get copyWith => __$NoteCopyWithImpl<_Note>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Note&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.coverImage, coverImage) || other.coverImage == coverImage)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&const DeepCollectionEquality().equals(other._tags, _tags));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,content,createdAt,updatedAt,coverImage,const DeepCollectionEquality().hash(_blocks),const DeepCollectionEquality().hash(_tags));

@override
String toString() {
  return 'Note(id: $id, title: $title, content: $content, createdAt: $createdAt, updatedAt: $updatedAt, coverImage: $coverImage, blocks: $blocks, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$NoteCopyWith<$Res> implements $NoteCopyWith<$Res> {
  factory _$NoteCopyWith(_Note value, $Res Function(_Note) _then) = __$NoteCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String content, DateTime createdAt, DateTime? updatedAt, String? coverImage, List<Block> blocks, List<String> tags
});




}
/// @nodoc
class __$NoteCopyWithImpl<$Res>
    implements _$NoteCopyWith<$Res> {
  __$NoteCopyWithImpl(this._self, this._then);

  final _Note _self;
  final $Res Function(_Note) _then;

/// Create a copy of Note
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? content = null,Object? createdAt = null,Object? updatedAt = freezed,Object? coverImage = freezed,Object? blocks = null,Object? tags = null,}) {
  return _then(_Note(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,coverImage: freezed == coverImage ? _self.coverImage : coverImage // ignore: cast_nullable_to_non_nullable
as String?,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<Block>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$Block {

 String get id; String get data; int get orderIndex;
/// Create a copy of Block
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlockCopyWith<Block> get copyWith => _$BlockCopyWithImpl<Block>(this as Block, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Block&&(identical(other.id, id) || other.id == id)&&(identical(other.data, data) || other.data == data)&&(identical(other.orderIndex, orderIndex) || other.orderIndex == orderIndex));
}


@override
int get hashCode => Object.hash(runtimeType,id,data,orderIndex);

@override
String toString() {
  return 'Block(id: $id, data: $data, orderIndex: $orderIndex)';
}


}

/// @nodoc
abstract mixin class $BlockCopyWith<$Res>  {
  factory $BlockCopyWith(Block value, $Res Function(Block) _then) = _$BlockCopyWithImpl;
@useResult
$Res call({
 String id, String data, int orderIndex
});




}
/// @nodoc
class _$BlockCopyWithImpl<$Res>
    implements $BlockCopyWith<$Res> {
  _$BlockCopyWithImpl(this._self, this._then);

  final Block _self;
  final $Res Function(Block) _then;

/// Create a copy of Block
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? data = null,Object? orderIndex = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,orderIndex: null == orderIndex ? _self.orderIndex : orderIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Block].
extension BlockPatterns on Block {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TextBlock value)?  text,TResult Function( ImageBlock value)?  image,TResult Function( CheckboxBlock value)?  checkbox,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that);case ImageBlock() when image != null:
return image(_that);case CheckboxBlock() when checkbox != null:
return checkbox(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TextBlock value)  text,required TResult Function( ImageBlock value)  image,required TResult Function( CheckboxBlock value)  checkbox,}){
final _that = this;
switch (_that) {
case TextBlock():
return text(_that);case ImageBlock():
return image(_that);case CheckboxBlock():
return checkbox(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TextBlock value)?  text,TResult? Function( ImageBlock value)?  image,TResult? Function( CheckboxBlock value)?  checkbox,}){
final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that);case ImageBlock() when image != null:
return image(_that);case CheckboxBlock() when checkbox != null:
return checkbox(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String data,  int orderIndex)?  text,TResult Function( String id,  String data,  int orderIndex)?  image,TResult Function( String id,  String data,  bool isChecked,  int orderIndex)?  checkbox,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that.id,_that.data,_that.orderIndex);case ImageBlock() when image != null:
return image(_that.id,_that.data,_that.orderIndex);case CheckboxBlock() when checkbox != null:
return checkbox(_that.id,_that.data,_that.isChecked,_that.orderIndex);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String data,  int orderIndex)  text,required TResult Function( String id,  String data,  int orderIndex)  image,required TResult Function( String id,  String data,  bool isChecked,  int orderIndex)  checkbox,}) {final _that = this;
switch (_that) {
case TextBlock():
return text(_that.id,_that.data,_that.orderIndex);case ImageBlock():
return image(_that.id,_that.data,_that.orderIndex);case CheckboxBlock():
return checkbox(_that.id,_that.data,_that.isChecked,_that.orderIndex);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String data,  int orderIndex)?  text,TResult? Function( String id,  String data,  int orderIndex)?  image,TResult? Function( String id,  String data,  bool isChecked,  int orderIndex)?  checkbox,}) {final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that.id,_that.data,_that.orderIndex);case ImageBlock() when image != null:
return image(_that.id,_that.data,_that.orderIndex);case CheckboxBlock() when checkbox != null:
return checkbox(_that.id,_that.data,_that.isChecked,_that.orderIndex);case _:
  return null;

}
}

}

/// @nodoc


class TextBlock implements Block {
  const TextBlock({required this.id, required this.data, this.orderIndex = 0});
  

@override final  String id;
@override final  String data;
@override@JsonKey() final  int orderIndex;

/// Create a copy of Block
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextBlockCopyWith<TextBlock> get copyWith => _$TextBlockCopyWithImpl<TextBlock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.data, data) || other.data == data)&&(identical(other.orderIndex, orderIndex) || other.orderIndex == orderIndex));
}


@override
int get hashCode => Object.hash(runtimeType,id,data,orderIndex);

@override
String toString() {
  return 'Block.text(id: $id, data: $data, orderIndex: $orderIndex)';
}


}

/// @nodoc
abstract mixin class $TextBlockCopyWith<$Res> implements $BlockCopyWith<$Res> {
  factory $TextBlockCopyWith(TextBlock value, $Res Function(TextBlock) _then) = _$TextBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String data, int orderIndex
});




}
/// @nodoc
class _$TextBlockCopyWithImpl<$Res>
    implements $TextBlockCopyWith<$Res> {
  _$TextBlockCopyWithImpl(this._self, this._then);

  final TextBlock _self;
  final $Res Function(TextBlock) _then;

/// Create a copy of Block
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? data = null,Object? orderIndex = null,}) {
  return _then(TextBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,orderIndex: null == orderIndex ? _self.orderIndex : orderIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ImageBlock implements Block {
  const ImageBlock({required this.id, required this.data, this.orderIndex = 0});
  

@override final  String id;
@override final  String data;
@override@JsonKey() final  int orderIndex;

/// Create a copy of Block
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageBlockCopyWith<ImageBlock> get copyWith => _$ImageBlockCopyWithImpl<ImageBlock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.data, data) || other.data == data)&&(identical(other.orderIndex, orderIndex) || other.orderIndex == orderIndex));
}


@override
int get hashCode => Object.hash(runtimeType,id,data,orderIndex);

@override
String toString() {
  return 'Block.image(id: $id, data: $data, orderIndex: $orderIndex)';
}


}

/// @nodoc
abstract mixin class $ImageBlockCopyWith<$Res> implements $BlockCopyWith<$Res> {
  factory $ImageBlockCopyWith(ImageBlock value, $Res Function(ImageBlock) _then) = _$ImageBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String data, int orderIndex
});




}
/// @nodoc
class _$ImageBlockCopyWithImpl<$Res>
    implements $ImageBlockCopyWith<$Res> {
  _$ImageBlockCopyWithImpl(this._self, this._then);

  final ImageBlock _self;
  final $Res Function(ImageBlock) _then;

/// Create a copy of Block
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? data = null,Object? orderIndex = null,}) {
  return _then(ImageBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,orderIndex: null == orderIndex ? _self.orderIndex : orderIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class CheckboxBlock implements Block {
  const CheckboxBlock({required this.id, required this.data, this.isChecked = false, this.orderIndex = 0});
  

@override final  String id;
@override final  String data;
@JsonKey() final  bool isChecked;
@override@JsonKey() final  int orderIndex;

/// Create a copy of Block
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckboxBlockCopyWith<CheckboxBlock> get copyWith => _$CheckboxBlockCopyWithImpl<CheckboxBlock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckboxBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.data, data) || other.data == data)&&(identical(other.isChecked, isChecked) || other.isChecked == isChecked)&&(identical(other.orderIndex, orderIndex) || other.orderIndex == orderIndex));
}


@override
int get hashCode => Object.hash(runtimeType,id,data,isChecked,orderIndex);

@override
String toString() {
  return 'Block.checkbox(id: $id, data: $data, isChecked: $isChecked, orderIndex: $orderIndex)';
}


}

/// @nodoc
abstract mixin class $CheckboxBlockCopyWith<$Res> implements $BlockCopyWith<$Res> {
  factory $CheckboxBlockCopyWith(CheckboxBlock value, $Res Function(CheckboxBlock) _then) = _$CheckboxBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String data, bool isChecked, int orderIndex
});




}
/// @nodoc
class _$CheckboxBlockCopyWithImpl<$Res>
    implements $CheckboxBlockCopyWith<$Res> {
  _$CheckboxBlockCopyWithImpl(this._self, this._then);

  final CheckboxBlock _self;
  final $Res Function(CheckboxBlock) _then;

/// Create a copy of Block
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? data = null,Object? isChecked = null,Object? orderIndex = null,}) {
  return _then(CheckboxBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,isChecked: null == isChecked ? _self.isChecked : isChecked // ignore: cast_nullable_to_non_nullable
as bool,orderIndex: null == orderIndex ? _self.orderIndex : orderIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
