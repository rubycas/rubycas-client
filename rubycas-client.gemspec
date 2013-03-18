# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path("../lib", __FILE__)
require 'rubycas-client/version'

Gem::Specification.new do |gem|
  gem.authors = ["Matt Campbell", "Matt Zukowski", "Matt Walker", "Matt Campbell"]
  gem.email         = ["matt@soupmatt.com"]
  gem.summary = %q{Client library for the Central Authentication Service (CAS) protocol.}
  gem.description = %q{Client library for the Central Authentication Service (CAS) protocol.}
  gem.homepage = "https://github.com/rubycas/rubycas-client"
  gem.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  gem.licenses = ["MIT"]
  gem.rdoc_options = ["--main", "README.rdoc"]
  gem.version       = CasClient::VERSION

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "rubycas-client"
  gem.require_paths = ["lib"]

  gem.add_dependency("activesupport")
  gem.add_development_dependency("rake")
  gem.add_development_dependency("database_cleaner")
  gem.add_development_dependency("json")
  gem.add_development_dependency("rspec")
  gem.add_development_dependency("appraisal")
  gem.add_development_dependency("rails")
  gem.add_development_dependency("simplecov")
  if defined?(JRUBY_VERSION)
    gem.add_development_dependency("activerecord-jdbcsqlite3-adapter")
  else
    gem.add_development_dependency("sqlite3")
  end
end
