/// The HTTP methods `AppService.send` supports (from the MVVM template).
///
/// lowerCamelCase (`get`, not `GET`) is the Dart style for enum values;
/// `patch` is added because our backend uses PATCH for updates.
enum HttpMethods { get, post, put, patch, delete }
