require File.dirname(__FILE__) + '/spec_helper'

module Visibility
  def visible?
    @visible ||= true
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

module Testing
  class NestedClass
    def foo; 1; end
    def bar; 10_000_009; end
  end
end

class NonNestedClass
  def baz; 2; end
end

shared_examples_for "all wrapped classes" do
  it "should wrap the class>>#new method so we get an instance of the proxy instead" do
    Proxeze.proxy Testing::NestedClass
    instance = Testing::NestedClass.new
    instance.should respond_to(:__getobj__)
    instance.should respond_to(:__setobj__)
    instance.should be_kind_of(Proxeze::TestingNestedClass)

    Proxeze.proxy NonNestedClass
    instance = NonNestedClass.new
    instance.should respond_to(:__getobj__)
    instance.should respond_to(:__setobj__)
    instance.should be_kind_of(Proxeze::NonNestedClass)

    cls = Class.new
    cls_name = Date.today.strftime('%B%d%H%m%s')
    Object.const_set cls_name, cls
    
    Proxeze.proxy cls
    instance = cls.new
    instance.should respond_to(:__getobj__)
    instance.should respond_to(:__setobj__)
    instance.should be_kind_of(Proxeze.const_get(cls_name))
  end
end

describe Proxeze do
  it_should_behave_like "all wrapped classes"
  
  it "should respond to the target object's methods" do
    Proxeze.proxy Testing::NestedClass
    instance = Testing::NestedClass.new
    
    instance.should respond_to(:foo)
    instance.foo.should == 1
    
    instance.should respond_to(:bar)
    instance.bar.should == 10_000_009
  end
  
  it "should be able to add behavior to the proxy without disturbing the wrapped object" do
    Proxeze.proxy NonNestedClass
    instance = NonNestedClass.new
    
    instance.should_not respond_to(:visible?)
    Proxeze::NonNestedClass.send :include, Visibility
    instance.should respond_to(:visible?)
  end
end