$:.unshift '.'
require 'app'

set :run, false

run Sinatra::Application