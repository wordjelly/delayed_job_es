lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "delayed_job_es/version"

Gem::Specification.new do |spec|
  spec.name          = "delayed_job_es"
  spec.version       = DelayedJobEs::VERSION
  spec.authors       = ["Great Manta"]
  spec.email         = ["icantremember111@gmail.com"]
  # just get the basic thing working.
  # we can go for the detailed specs later.
  spec.summary       = "Elasticsearch on ruby , has had many different gems being built and used. The official library itself has gone through some major revisions, and shifted from a simple persistence pattern to a repository pattern, before which there was a 'Tire' gem that has since been retired. Its clear that a delayed job backend using elasticsearch should be a zero assumption system. In this gem, I have only used two (stable) dependencies (ES-transport and Es-api). Morever the Job class does not include any modules/classes from either of them, and is a PORO that only includes the Delayed::Job::Backend module. This gem is in use in a high-volume production system and has had no major issues, under heavy load."
  spec.description   = "Elastic Search backend for Delayed Job, only using the ES transport client and the Es-ruby api as dependencies."
  spec.homepage      = "https://github.com/wordjelly/delayed_job_es"
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
    
  spec.add_runtime_dependency "delayed_job"
  spec.add_runtime_dependency "elasticsearch"
  spec.add_runtime_dependency "json"
  

end
