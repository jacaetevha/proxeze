source 'http://rubygems.org'

group :development do
  platforms :mri_19 do
    gem "ruby-debug19"
  end
  platforms :mri_18 do
    gem 'ruby-debug'
  end
  platforms :jruby do
    gem 'jruby-openssl'
    gem 'ruby-debug'
  end
  gem "rspec", "~> 2.4.0"
  gem "bundler", "~> 1.0.0"
  gem "jeweler", "~> 1.5.2"
  gem "rcov", ">= 0"
end
