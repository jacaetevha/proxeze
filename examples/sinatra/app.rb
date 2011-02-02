require 'rubygems'
require 'sinatra'
require 'haml'
require 'proxeze'

module Visibility
  def visible?
    @visible = true if @visible.nil?
    @visible
  end

  def be_invisible!
    @visible = false
    self
  end

  def be_visible!
    @visible = true
    self
  end
end

class ListingItem
  attr_reader :name, :children, :path
  attr_accessor :parent

  def initialize name, is_directory
    @name = name.split('/').last
    @path = name.split('/')[0..-2]
    @is_directory = is_directory
    @children = []
  end
  
  def full_path
    if parent.nil?
      name
    else
      File.join(*([parent.full_path] + [name]).flatten)
    end
  end
  
  def top_level?
    path.nil? || path.empty?
  end
  
  def directory?
    @is_directory
  end
end

Proxeze.proxy ListingItem
Proxeze::ListingItem.send :include, Visibility
configure do
  ALL_LISTINGS = Dir['**/**'].collect{|e| ListingItem.new(e, File.directory?(e)) }
  ALL_LISTINGS.each do |e|
    next if e.path.nil? || e.path.empty?
    e.parent = ALL_LISTINGS.detect{|e1| e1.name == e.path.last}
    e.parent.children << e if e.parent
  end
end

helpers do  
  def unhide &blk
    hide_all_listings
    ALL_LISTINGS.select(&blk).each{|e| e.be_visible!}
  end
  
  def hide_all_listings
    ALL_LISTINGS.each{|e| e.be_invisible!}
  end
  
  def unhide_all_listings
    ALL_LISTINGS.each{|e| e.be_visible!}
  end
end

before do
  hide_all_listings
end

get '/' do
  unhide {|e| e.top_level?}
  @top = true
  haml :index
end

get '/*' do
  if request.xhr?
    content_type 'text/plain'
    File.read(params[:splat].first)
  else
    path = params[:splat].first.split('/')
    unhide {|e| e.name == path.last || e.path == path.last}
    haml :index
  end
end