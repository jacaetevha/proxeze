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
    Proxeze.class_defined?('ClassForProxyingAnInstance').should == false
    instance = Proxeze.for(ClassForProxyingAnInstance.new)
    ClassForProxyingAnInstance.methods.collect{|e| e.to_s}.include?('new_with_extra_behavior').should == false
    ClassForProxyingAnInstance.methods.collect{|e| e.to_s}.include?('new_without_extra_behavior').should == false
    Proxeze.class_defined?('ClassForProxyingAnInstance').should == true
    
    instance.should_not respond_to(:visible?)
    instance.class.send :include, Visibility
    instance.should respond_to(:visible?)
  end
  
  it "should redefine the #new method when the class is proxied, even after an instance of the class was proxied" do
    Proxeze.class_defined?('ClassForProxyingAfterAnInstanceWasProxied').should == false
    instance = Proxeze.for(ClassForProxyingAfterAnInstanceWasProxied.new)
    Proxeze.class_defined?('ClassForProxyingAfterAnInstanceWasProxied').should == true
    
    Proxeze.proxy ClassForProxyingAfterAnInstanceWasProxied
    instance = ClassForProxyingAfterAnInstanceWasProxied.new
    instance.__getobj__.class.methods.collect{|e| e.to_s}.should include('new_without_extra_behavior')
  end

  it "should create a new proxy around the same delegate object" do
    Proxeze.proxy NonNestedClass
    instance = NonNestedClass.new
    copy     = instance.new_proxy

    instance.class.should == Proxeze::NonNestedClass
    copy.class.should == Proxeze::NonNestedClass
    
    instance.__getobj__.should be_equal(copy.__getobj__)
    instance.__getobj__.should == copy.__getobj__
    instance.baz.should == 2
    copy.baz.should == 2
    
    copy.class.send :include, NewBaz
    instance.__getobj__.should == copy.__getobj__
    instance.baz.should == 'new baz'
    copy.baz.should == 'new baz'
  end

  it "should create a new proxy around a clone of the delegate object" do
    Proxeze.proxy Testing::NestedClass
    instance = Testing::NestedClass.new
    copy     = instance.clone

    instance.class.should == Proxeze::TestingNestedClass
    copy.class.should == Proxeze::TestingNestedClass
    
    instance.__getobj__.should_not be_equal(copy.__getobj__)
    instance.__getobj__.should == copy.__getobj__
    instance.bar.should == 10_000_009
    copy.bar.should == 10_000_009

    copy_meta = class << copy.__getobj__; self; end
    copy_meta.send :include, NewBar
    instance.bar.should == 10_000_009
    copy.bar.should == 'new bar'
    instance.__getobj__.should_not == copy.__getobj__
  end
  
  it "should not attempt to redefine #new in the class of the proxied object" do
    lambda{Proxeze.for(1)}.should_not raise_error(NameError)
    proxy = Proxeze.for(1)
    proxy.should be_kind_of(Proxeze::Fixnum)
  end
  
  it "should proxy class methods also" do
    Proxeze.proxy ClassWithClassMethods
    Proxeze::ClassWithClassMethods.should respond_to(:foo)
    Proxeze::ClassWithClassMethods.foo.should == ClassWithClassMethods.foo
  end
  
  it "should not proxy class methods that are marked as excluded" do
    Proxeze.proxy ClassWithClassMethods_SomeOfWhichWillBeExcluded, :exclude_class_methods => [:foo]
    Proxeze::ClassWithClassMethods_SomeOfWhichWillBeExcluded.should_not respond_to(:foo)
    Proxeze::ClassWithClassMethods_SomeOfWhichWillBeExcluded.should respond_to(:bar)
    Proxeze::ClassWithClassMethods_SomeOfWhichWillBeExcluded.bar.should == ClassWithClassMethods_SomeOfWhichWillBeExcluded.bar
  end

  it "should proxy class methods also" do
    Proxeze.proxy ClassWithOverriddenObjectMethod, :include_class_methods => [:hash]
    Proxeze::ClassWithOverriddenObjectMethod.should respond_to(:hash)
    Proxeze::ClassWithOverriddenObjectMethod.hash.should == 17
  end
  
  it "should allow 'before' callbacks to run and do anything with arguments" do
    baz_method_args = nil
    Proxeze.proxy( ClassWhereinWeMeetBeforeBlocks ) do
      before :baz do |*args|
        baz_method_args = args.last
      end
    end
    instance = ClassWhereinWeMeetBeforeBlocks.new
    instance.foo.should == 1
    instance.bar.should == 2.0
    instance.baz(2).should == 4.0
    baz_method_args.should == [2]
  end
end