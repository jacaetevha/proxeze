require File.dirname(__FILE__) + '/spec_helper'
require 'definitions'

class Symbol
  def <=> other
    self.to_s <=> other.to_s
  end
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
  
  it "should run 'before' callbacks" do
    baz_method_args = nil
    Proxeze.proxy( ClassWhereinWeMeetBeforeBlocks ) do
      before :baz do |target, args, mid, result|
        baz_method_args = args
      end
    end
    instance = ClassWhereinWeMeetBeforeBlocks.new
    instance.foo.should == 1
    instance.bar.should == 2.0
    instance.baz(2).should == 4.0
    baz_method_args.should == [2]
  end

  it "should run 'before_all' callbacks" do
    callbacks = {}
    Proxeze.proxy( ClassWhereinWeMeetBeforeBlocks ) do
      before_all do |target, args, mid, result|
        callbacks[mid] = args
      end
    end
    instance = ClassWhereinWeMeetBeforeBlocks.new
    instance.foo.should == 1
    instance.bar.should == 2.0
    instance.baz(2).should == 4.0
    
    callbacks.keys.sort.should == [:bar, :baz, :foo]
    callbacks[:foo].should == []
    callbacks[:bar].should == []
    callbacks[:baz].should == [2]
  end

  it "should run 'after' callbacks" do
    callbacks = {}
    Proxeze.proxy( ClassWhereinWeMeetBeforeBlocks ) do
      after :foo do |target, args, mid, result|
        callbacks[mid] = args
        result
      end
    end
    instance = ClassWhereinWeMeetBeforeBlocks.new
    instance.foo.should == 1
    instance.bar.should == 2.0
    instance.baz(2).should == 4.0
    
    callbacks.keys.sort.should == [:foo]
    callbacks[:foo].should == []
  end

  it "should run 'after_all' callbacks" do
    callbacks = {}
    Proxeze.proxy( ClassWhereinWeMeetBeforeBlocks ) do
      after_all do |target, arguments, mid, result|
        callbacks[mid] = result
        result * 2
      end
    end
    instance = ClassWhereinWeMeetBeforeBlocks.new
    instance.foo.should == 2
    instance.bar.should == 4.0
    instance.baz(2).should == 8.0
    
    callbacks.keys.sort.should == [:bar, :baz, :foo]
    callbacks[:foo].should == 1
    callbacks[:bar].should == 2.0
    callbacks[:baz].should == 4.0
  end
  
  it "should be able to add hooks to a proxied instance" do
    a = Proxeze.for [0, 1, 3, 2, 5, 4] do
      before :reverse do |target, arguments, mid|
        target << target.length
      end
    end
    a.reverse.should == [6, 4, 5, 2, 3, 1, 0]

    a.after :sort do |target, arguments, mid, result|
      result << result.length
    end
    a.sort.should == [0, 1, 2, 3, 4, 5, 6, 7]
    
    # make sure that other instances of Arrays don't get the
    # behavior added to the proxied instances above
    [0, 1, 3, 2, 5, 4].sort.reverse.should == [5, 4, 3, 2, 1, 0]
    [1, 3, 2].reverse.should == [2, 3, 1]
    Proxeze.for([1, 3, 2]).reverse.should == [2, 3, 1]
  end
  
  it "should accept a class for the callbacks" do
    class SortPerformer
      def initialize callback_type, object, args = nil, method = nil, result = nil
        @object = object; @result = result; @method = method, @args = args
      end

      def call; @object.sort! end
    end
    p = Proxeze.for [1, 2, 3] do
      after :reverse, SortPerformer
    end
    p.reverse.should == [1, 2, 3]
  end
  
  it "should accept a class for before_all and after_all callbacks" do
    class MyClass
      attr_accessor :foo
      def inspect
        'an instance of MyClass'
      end
    end

    class DebugLogInterceptor
      def self.logger
        @logger ||= []
        @logger
      end
      
      def initialize callback_type, object, args = nil, method = nil, result = nil
        @callback_type = callback_type
        @object = object
        @result = result
        @method = method
        @args = args
      end
      
      def call
        self.class.logger << log_message
      end

      def log_message
        "#{@callback_type}: #{@method} on #{@object.inspect} with args[#{@args.inspect}], result is [#{@result}]"
      end
    end

    Proxeze.proxy MyClass do
      after_all  DebugLogInterceptor
      before_all DebugLogInterceptor
    end

    o = MyClass.new
    o.foo = 2
    DebugLogInterceptor.logger.should == ["before_all: foo= on an instance of MyClass with args[[2]], result is []", 
                                          "after_all: foo= on an instance of MyClass with args[[2]], result is [2]"]
  end
end