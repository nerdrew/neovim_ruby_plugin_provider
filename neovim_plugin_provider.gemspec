# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'neovim_plugin_provider/version'

Gem::Specification.new do |spec|
  spec.name          = "neovim_plugin_provider"
  spec.version       = NeovimPluginProvider::VERSION
  spec.authors       = ["Andrew Lazarus"]
  spec.email         = ["nerdrew@gmail.com"]

  spec.summary       = %q{Neovim Ruby Plugin Host Provider}
  spec.description   = %q{Neovim Ruby Plugin Host Provider}
  spec.homepage      = "https://github.com/nerdrew/neovim_plugin_provider"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  if spec.respond_to?(:metadata)
    #spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
  end

  spec.add_dependency "msgpack"

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2.0"
end
