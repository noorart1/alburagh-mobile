# uCrop 2.2.11 (pulled in by image_cropper) references OkHttp classes for its
# optional custom-OkHttpClient download path (UCrop.Options.setOkHttpClient),
# which this app never calls -- OkHttp isn't a dependency here (networking
# goes through Dio, not native OkHttp), so R8 can't resolve those classes and
# fails the release build without this. Safe to silence: the referencing code
# is unreachable without that opt-in call.
-dontwarn okhttp3.**
