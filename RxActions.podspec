Pod::Spec.new do |spec|

  spec.name = "RxActions"
  spec.version = "0.0.2"
  spec.summary = "Helpful primitives for modelling UI actions in RxSwift"

  spec.description  = <<~DESC
    This framework can be used on top of [RxSwift] to provide a new _Action_
    primitive. An action will perform some work when given an _input_, producing
    an `Observable` which will generate zero or more values before either
    completing or terminating in an error.

    [RxSwift]: https://github.com/ReactiveX/RxSwift
  DESC

  spec.homepage = "https://github.com/rhysforyou/RxActions"

  spec.license = { :type => "MIT", :file => "LICENSE" }

  spec.authors = { "Rhys Powell" => "rhys@rpowell.me" }
  spec.social_media_url = "https://twitter.com/rhysforyou"

  spec.ios.deployment_target = "8.0"
  spec.osx.deployment_target = "10.9"

  spec.swift_version = "4.2"

  spec.source = { :git => "https://github.com/rhysforyou/RxActions.git", :tag => "v#{spec.version}" }

  spec.source_files  = "Sources/RxActions/**/*.swift"

  spec.requires_arc = true

  spec.dependency "RxSwift", "~> 4.2"
  spec.dependency "RxCocoa", "~> 4.2"

end
