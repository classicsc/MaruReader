devices([
  "iPhone 17 Pro",
])

languages([
  "en-US",
])

scheme("MaruReader")
project("./MaruReader.xcodeproj")

output_directory("./fastlane/screenshots")
clear_previous_screenshots(true)
override_status_bar(true)

testplan("MaruReaderUITests")

# Only run the ScreenshotTests class
only_testing(["MaruReaderUITests/ScreenshotTests"])

# For more information about all available options run
# fastlane action snapshot
