Gem::Specification.new do |s|
  s.name        = "taylor-swift"
  s.version     = "0.1.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jade Dominguez"]
  s.email       = ["plusjade@gmail.com"]
  s.homepage    = "http://github.com/plusjade/taylor-swift"
  s.summary     = "Simple Redis backed tagging system."
  s.description = "Simple Redis backed tagging system."
  s.date        = "2011-11-08"
  s.require_paths = ["lib"]  

  libdir = Dir.new('lib/taylor-swift').entries
  libdir.delete('.')
  libdir.delete('..')
  libdir = libdir.collect{|filename| 'lib/taylor-swift/' + filename}
  
  s.files = [
    "Rakefile", 
    "README.md", 
    'lib/taylor-swift.rb',
    "lib/taylor-swift/query.rb",
    "lib/taylor-swift/utils.rb"
    ]
  
end
