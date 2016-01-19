#
# Be sure to run `pod lib lint ReactNativeAutoUpdater.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "ReactNativeAutoUpdater"
  s.version          = "0.1.5"
  s.summary          = "A library to manage dynamic updates to React Native apps. Available as a CocoaPod."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
                       A library to manage dynamic updates to React Native apps. Available as a CocoaPod.
                       For more information, check out the Github repo -- https://github.com/aerofs/react-native-auto-updater
                        DESC
  s.homepage         = "https://github.com/aerofs/react-native-auto-updater"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Rahul Jiresal" => "rahul@aerofs.com" }
  s.source           = { :git => "https://github.com/aerofs/react-native-auto-updater", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/rahuljiresal'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'ReactNativeAutoUpdater' => ['Pod/Assets/*.png']
  }

  s.public_header_files = 'Pod/Classes/ReactNativeAutoUpdater.h'
  
end
