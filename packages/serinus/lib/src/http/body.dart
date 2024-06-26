import 'dart:io';

import 'form_data.dart';

/// The class [Body] is used to create a body for the request.
class Body {
  /// If the content type is [multipart/form-data] or [x-www-form-urlencoded], the [formData] will be used.
  final FormData? formData;

  /// The content type of the body.
  final ContentType contentType;

  /// The content of the body if it is text.
  final String? text;

  /// The content of the body if it is binary.
  final List<int>? bytes;

  /// The content of the body if it is json.
  final Map<String, dynamic>? json;

  Body(this.contentType, {this.formData, this.text, this.bytes, this.json});

  /// Factory constructor to create an empty body.
  factory Body.empty() => Body(ContentType.text);

  Body change({
    FormData? formData,
    ContentType? contentType,
    String? text,
    List<int>? bytes,
    Map<String, dynamic>? json,
  }) {
    if (formData != null) {
      return Body(contentType ?? this.contentType, formData: formData);
    } else if (text != null) {
      return Body(contentType ?? this.contentType, text: text);
    } else if (bytes != null) {
      return Body(contentType ?? this.contentType, bytes: bytes);
    } else if (json != null) {
      return Body(contentType ?? this.contentType, json: json);
    }
    return this;
  }
}
