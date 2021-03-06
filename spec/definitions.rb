module Testing
  class NestedClass
    def foo; 1; end
    def bar; 10_000_009; end
    def ==(other); other.foo == self.foo && other.bar == self.bar; end
  end
end

class NonNestedClass
  def baz; 2; end
  def ==(other); other.baz == self.baz; end
end

module NewBaz
  def self.included into
    begin
      into.instance_eval{ remove_method :baz }
    rescue
    end
  end

  def baz; 'new baz'; end
end

module NewBar
  def self.included into
    begin
      into.send :remove_method, :bar
    rescue
    end
  end

  def bar; 'new bar'; end
end

class ClassForProxyingAnInstance
end

class ClassForProxyingAfterAnInstanceWasProxied
end

class ClassWithClassMethods
  def self.foo; 1; end
end

class ClassWithClassMethods_SomeOfWhichWillBeExcluded
  def self.foo; 1; end
  def self.bar; 2; end
end

class ClassWithOverriddenObjectMethod
  def self.hash; 17; end
end

class ClassWhereinWeMeetBeforeBlocks
  def foo; 1; end
  def bar; 2.0; end
  def baz arg
    (arg.to_f / foo) * bar
  end
end

class Category
  attr_accessor :categories
  attr_reader   :name

  def initialize name
    @name = name
    @categories = []
  end
  
  def == other
    other.name == self.name &&
      other.categories == self.categories
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
