# Uncomment this line to define a global platform for your project
# platform :ios, '9.0'
source 'https://github.com/CocoaPods/Specs.git'

def using_pods
    # Pods for TrendingTweetsWidget and extension
    pod 'Fabric'
    pod 'Crashlytics'
    pod 'TwitterKit'
    pod 'TwitterCore'
end

target 'TrendingTweetsWidget' do
  # Comment this line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  using_pods
end

target 'TrendingTweetsTodayWidget' do
    # Comment this line if you're not using Swift and don't want to use dynamic frameworks
    use_frameworks!

    using_pods
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
            config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
            config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
            config.build_settings['SWIFT_VERSION'] = '3.0'
            config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.10'
        end
    end
end
