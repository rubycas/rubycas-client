require 'rake'

Gem::Specification.new do |s|
  s.name = %q{rubycas-client}
  s.version = "0.12.0"
  s.date = %q{2007-04-04}
  s.summary = %q{Client library for the CAS single-sign-on protocol.}
  s.email = %q{matt@roughest.net}
  s.homepage = %q{http://rubycas-client.rubyforge.org}
  s.rubyforge_project = %q{rubycas-client}
  s.description = %q{RubyCAS-Client is a Ruby client library for Yale's Central Authentication Service (CAS) single-sign-on protocol for web-based applications.}
  s.has_rdoc = true
  s.authors = ["Matt Zukowski", "Ola Bini", "Matt Walker"]
  s.files = FileList['*.rb', 'lib/**/*.rb', '[A-Z]*', 'test/*.xml']
# s.test_files = Dir['test/*_test.rb']
  s.rdoc_options = ["--title", "RubyCAS-Client RDocs", "--main", "README", "--line-numbers"]
  s.extra_rdoc_files = ["README", "LICENSE"]
# s.require_paths << '.' # in addition 'lib', which is the default require_paths
  s.rubyforge_project = %q{rubycas-client}
end
