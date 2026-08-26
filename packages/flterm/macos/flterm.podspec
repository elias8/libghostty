Pod::Spec.new do |s|
  s.name             = 'flterm'
  s.version          = '0.0.4'
  s.summary          = 'Flutter terminal widget on top of Ghostty.'
  s.description      = 'Native keyboard metadata companion for flterm.'
  s.homepage         = 'https://github.com/elias8/libghostty'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'libghostty contributors' => 'opensource@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'flterm/Sources/flterm/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
