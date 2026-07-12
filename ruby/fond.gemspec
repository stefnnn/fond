Gem::Specification.new do |spec|
  spec.name = "fond"
  spec.version = "0.1.0"
  spec.authors = ["Stefan N"]
  spec.summary = "Typed React frontends for Rails: Sorbet DTOs as the API contract, generated TypeScript types and hooks"
  spec.homepage = "https://github.com/stnu/fond"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.1"
  spec.add_dependency "actionpack", ">= 7.1"
  spec.add_dependency "sorbet-runtime", ">= 0.5"
end
