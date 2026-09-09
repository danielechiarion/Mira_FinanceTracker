SOURCE_PATH=desktop/background_check.dart
FLUTTER_BUILD_PATH=build/linux/x64/release/bundle/mira_finance_tracker
BUILD_PATH=build/background_check

flutter build linux --release --target="$SOURCE_PATH"
BUILD_EXIT_CODE=$?
if [ $BUILD_EXIT_CODE -ne 0 ]; then
	exit $BUILD_EXIT_CODE
fi
cp "$FLUTTER_BUILD_PATH" "$BUILD_PATH"