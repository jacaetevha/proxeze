require File.dirname(__FILE__) + '/spec_helper'
require 'definitions'

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
    Proxeze.proxy Category
    instance = Category.new('test')
    
    instance.should_not respond_to(:visible?)
    Proxeze::Category.send :include, Visibility
    instance.should respond_to(:visible?)
    instance.__getobj__.should_not respond_to(:visible?)
  end
  
  it "should operate on the proxy object seemlessly" do
    Proxeze.proxy Category
    Proxeze::Category.send :include, Visibility

    c1, c2, c3 = Category.new('1'), Category.new('2'), Category.new('3')
    c1.categories = [c2, c3]
    c2.categories << Category.new('4')
    c2.categories << Category.new('5')
    c6 = Category.new('6')
    c2.categories << c6
    c6.categories << Category.new('7')
    c6.categories << Category.new('8')
    
    c1.should be_visible
    c2.should be_visible
    c2.categories.each do |cat|
      cat.should be_visible
    end
    c3.should be_visible
    c6.should be_visible
    c6.categories.each do |cat|
      cat.should be_visible
    end
    
    c6.be_invisible!
    c6.should_not be_visible
    c6.categories.each do |cat|
      cat.should_not be_visible
    end
  end
  
  it "should proxy an object" do
    Proxeze.class_defined?('NonNestedClass').should == false
    instance = Proxeze.for(NonNestedClass.new)
    Proxeze.class_defined?('NonNestedClass').should == true
    
    instance.should_not respond_to(:visible?)
    instance.class.send :include, Visibility
    instance.should respond_to(:visible?)
  end
end