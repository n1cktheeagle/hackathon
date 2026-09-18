require 'xcodeproj'
require 'fileutils'
root = File.expand_path('../ios', __dir__)
project = Xcodeproj::Project.new(File.join(root, 'Detour.xcodeproj'))
app = project.new_target(:application, 'Detour', :ios, '26.0')
tests = project.new_target(:unit_test_bundle, 'DetourTests', :ios, '26.0')
ui_tests = project.new_target(:ui_test_bundle, 'DetourUITests', :ios, '26.0')
tests.add_dependency(app)
ui_tests.add_dependency(app)
config = project.main_group.new_file('Config.xcconfig')
[[app, 'Detour'], [tests, 'DetourTests'], [ui_tests, 'DetourUITests']].each do |target, directory|
  group = project.main_group.new_group(directory, directory)
  Dir.glob(File.join(root, directory, '**', '*.swift')).sort.each do |path|
    relative = path.delete_prefix(File.join(root, directory) + '/')
    file = group.new_file(relative)
    target.source_build_phase.add_file_reference(file)
  end
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings['SWIFT_VERSION'] = '6.0'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.steph.detour#{target == app ? '' : '.' + directory}"
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['GENERATE_INFOPLIST_FILE'] = target == app ? 'NO' : 'YES'
    settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
    if target == app
      configuration.base_configuration_reference = config
      settings['INFOPLIST_FILE'] = 'Detour/Info.plist'
      settings['OTHER_LDFLAGS'] = '$(inherited) -ObjC'
    elsif target == tests
      settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Detour.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Detour'
      settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    else
      settings['TEST_TARGET_NAME'] = 'Detour'
    end
  end
end
resources = project.main_group.new_group('Resources', 'Detour/Resources')
Dir.glob(File.join(root, 'Detour/Resources', '*')).sort.each do |path|
  reference = resources.new_file(File.basename(path))
  app.resources_build_phase.add_file_reference(reference)
end
package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
package.repositoryURL = 'https://github.com/googlemaps/ios-maps-sdk.git'
package.requirement = { 'kind' => 'exactVersion', 'version' => '10.15.0' }
project.root_object.package_references << package
product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product.package = package
product.product_name = 'GoogleMaps'
app.package_product_dependencies << product
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product
app.frameworks_build_phase.files << build_file
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.set_launch_target(app)
scheme.add_test_target(tests)
scheme.add_test_target(ui_tests)
scheme.save_as(File.join(root, 'Detour.xcodeproj'), 'Detour', true)
puts 'Generated ios/Detour.xcodeproj'
