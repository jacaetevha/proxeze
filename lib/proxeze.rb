require 'delegate'

def Delegator.delegating_block mid
  lambda do |*args, &block|
    target = self.__getobj__
    begin
      method = mid.to_s

      execute_call(@before_all, target, mid, args)
      execute_call(@before, target, args)

      result = target.__send__(mid, *args, &block)

      result_after = execute_call(@after, target, result, args)
      result_after_all = execute_call(@after_all, target, result, mid, args)

      return result_after_all if result_after_all
      return result_after if result_after
      result
    ensure
      $@.delete_if {|t| /\A#{Regexp.quote(__FILE__)}:#{__LINE__-2}:/o =~ t} if $@
    end
  end
end

def Delegator.delegating_block_for_method_and_target mid, target
  lambda do |*args, &block|
    begin
      target.__send__(mid, *args, &block)
    ensure
      $@.delete_if {|t| /\A#{Regexp.quote(__FILE__)}:#{__LINE__-2}:/o =~ t} if $@
    end
  end
end

module Proxeze
  if RUBY_VERSION =~ /1\.9/
    def self.class_defined? name
      const_defined? name, false
    end

    def self.object_methods
      Object.methods
    end
    
    def self.class_methods_from target_class
      target_class.methods
    end
  else
    def self.class_defined? name
      const_defined? name
    end

    def self.object_methods
      Object.methods.collect{|e| e.to_sym}
    end
    
    def self.class_methods_from target_class
      target_class.methods.collect{|e| e.to_sym}
    end
  end
  
  module ClassMethods
    # callback hooks
    def before mid, &blk
      @before ||= {}
      @before[mid] = blk
    end
  end
  
  # Create a proxy class for the given target class.
  # If the :redefine_new_method option is false, the
  # target class' #new method will not be reimplemented.
  #
  # When the target class' #new method is reimplemented,
  # all subsequent calls to #new on that class will return
  # an instance of a proxied class (in the Proxeze namespace),
  # thereby allowing seemless integration with existing
  # classes and object creation.
  # 
  # Typically, only the Proxeze>>#for method should pass in
  # :redefine_new_method => false here.
  def self.proxy target_class, opts = {}, &callback_blk
    options = default_proxy_options.merge opts
    cls_name = target_class.name.gsub( '::', '' )
    unless self.class_defined? cls_name
      cls = DelegateClass target_class
      cls.send :include, self
      cls.send :extend, ClassMethods
      self.const_set cls_name, cls

      excluded_class_methods = object_methods + [:new, :public_api, :delegating_block] + options[:exclude_class_methods]
      (class_methods_from(target_class) - excluded_class_methods + options[:include_class_methods]).each do |method|
        blk = Delegator.delegating_block_for_method_and_target(method, target_class)
        (class << cls; self; end).instance_eval do
          define_method(method, &blk)
        end
      end
    end
    
    cls = self.const_get cls_name

    # we have to collect the methods as Strings here because
    # 1.9 changed the implementation to return Symbols instead of Strings
    if options[:redefine_new_method] && !target_class.methods.collect{|e| e.to_s}.include?('new_with_extra_behavior')
      meta = class << target_class; self; end
      meta.class_eval %Q{
        def new_with_extra_behavior *args, &blk
          #{cls_name}.new( self.new_without_extra_behavior(*args, &blk) )
        end
        alias_method :new_without_extra_behavior, :new
        alias_method :new, :new_with_extra_behavior
      }, __FILE__, __LINE__
    end
    cls = self.const_get cls_name
    unless callback_blk.nil?
      cls.class_eval &callback_blk
    end
    cls
  end
  
  def self.default_proxy_options
    {:redefine_new_method => true, :exclude_class_methods => [], :include_class_methods => []}
  end
  
  # create a proxy object for the given object
  def self.for object
    self.proxy( object.class, :redefine_new_method => false ).new( object )
  end
  
  # create a new proxy around a clone of my delegate object
  def clone
    Proxeze.for __getobj__.clone
  end

  # create a new proxy object for my delegate
  def new_proxy
    Proxeze.for __getobj__
  end
  
  private               
    def execute_call container, *args
      executor = get_executor(container)
      result = nil
      if executor.class == Array
        executor.each do |e|
          result = e.send :call, *args if proc?(e)
          result = e.send(:new, *args).call if class?(e) 
        end
        return result
      end                    

      return executor.send :call, *args if proc?(executor)
      return executor.send(:new, *args).call if class?(executor) 
    end

    def get_executor container
      return nil unless container                              

      # The content is a proc or a class
      return container if proc?(container) or class?(container)

      # The content is an array with an array filled with a regex and a proc or a class
      if array?(container) and regexp?(container)
        matched = regexp_elements(container).select {|array| get_regexp(array) =~ @method}
        return matched.collect {|array| get_proc_or_class(array)} unless matched.empty?
      end

      hash?(container) ? container[@method_symbol] : container
    end

    def regexp_elements array
      elements = array.collect {|sub_array| array_with_regex?(sub_array) ? sub_array : nil}
      compacted_array = elements.compact
      compacted_array.nil? ? [] : compacted_array
    end

    def get_regexp array
      array.detect {|element| element.class == Regexp}
    end

    def get_proc_or_class array
      array.detect {|element| proc?(element) or class?(element)}
    end  

    def array_with_regex? array
      array.class == Array and array.size == 2 and not get_regexp(array).nil?
    end

    def proc? block; block and block.class == Proc end
    def class? param; param and param.class == Class end
    def array? param; param and param.class == Array end
    def hash? param; param and param.class == Hash end
    def regexp? array; array and not regexp_elements(array).empty? end
end