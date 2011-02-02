module Testing
  class NestedClass
    def foo; 1; end
    def bar; 10_000_009; end
  end
end

class NonNestedClass
  def baz; 2; end
end

class Category
  attr_accessor :categories
  attr_reader   :name

  def initialize name
    @name = name
    @categories = []
  end
end

module Visibility
  def visible?
    @visible = true if @visible.nil?
    @visible
  end
  
  def be_invisible!
    @visible = false
    categories.each {|e| e.be_invisible!}
    self
  end
  
  def be_visible!
    @visible = true
    categories.each {|e| e.be_visible!}
    self
  end
end
