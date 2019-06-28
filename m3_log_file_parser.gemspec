$:.push File.expand_path("../lib", __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "m3_log_file_parser"
  s.version     = "0.0.4"
  s.authors     = ["Georg Limbach"]
  s.email       = ["georg.limbach@lichtbit.com"]
  s.summary     = "Parser for Rails applications"
  s.license     = "MIT"
  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.add_dependency "rails"
end
