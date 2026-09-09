require 'xcodeproj'
path = 'ABAProgress/XcodeProject/ABAProgress.xcodeproj'
project = Xcodeproj::Project.open(path)
app = project.targets.find { |t| t.name == 'ABAProgress' }
target = project.new_target(:ui_test_bundle, 'DemoUITests', :ios, '17.0')
target.add_dependency(app)
file = project.main_group.new_file(File.expand_path('ABAProgress/QA/DemoUITests.swift'))
target.source_build_phase.add_file_reference(file)
target.build_configurations.each do |c|
 c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.abaprogress.demo-tests'
 c.build_settings['TEST_TARGET_NAME'] = 'ABAProgress'
 c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
 c.build_settings['SWIFT_VERSION'] = '5.0'
 c.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.set_launch_target(app)
scheme.save_as(path, 'Demo')
