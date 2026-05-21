require_relative "lib/local_domain/version"

Gem::Specification.new do |spec|
  spec.name        = "local_domain"
  spec.version     = LocalDomain::VERSION
  spec.authors     = ["Matt Hall"]
  spec.email       = ["matt.hall@webascender.com"]

  spec.summary     = "Run multiple Rails apps simultaneously on pretty .localhost subdomains via Caddy."
  spec.description = <<~DESC
    local_domain registers each Rails project with a local Caddy reverse proxy
    so that `bin/dev` in a folder named `my-app` is reachable at
    https://my-app.localhost. Multiple projects can run at the same time on
    dynamically assigned ports.
  DESC
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/mhall/local_domain"

  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir[
    "lib/**/*.rb",
    "exe/*",
    "README.md",
    "LICENSE.txt",
    "local_domain.gemspec",
  ]
  spec.bindir      = "exe"
  spec.executables = ["local_domain"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "rubygems_mfa_required" => "true",
  }
end
