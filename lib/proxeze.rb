require 'delegate'

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
  
  # Create a proxy class for the given target class.
  # If the :redefine_new_method option is false, the
  # target class' #new method will not be reimplemented.
  #
  # When the target class' #new method is reimplemented,
  # all subsequent calls to #new on that class will return
  # an instance of a proxied class (in the Proxeze namespace),
  # thereby allowing seemless integration with existing
  # classes.
  # 
  # Typically, only the Proxeze.for method should pass in
  # redefine_new_method=false here.
  def self.proxy target_class, opts = {}
    options = default_proxy_options.merge opts
    cls_name = target_class.name.gsub( '::', '' )
    unless self.class_defined? cls_name
      cls = DelegateClass target_class
      cls.send :include, self
      self.const_set cls_name, cls

      excluded_class_methods = object_methods + [:new, :public_api, :delegating_block] + options[:exclude_class_methods]
      (class_methods_from(target_class) - excluded_class_methods + options[:include_class_methods]).each do |method|
        blk = class_delegating_block(method, target_class)
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
    
    self.const_get cls_name
  end
  
  def self.default_proxy_options
    {:redefine_new_method => true, :exclude_class_methods => [], :include_class_methods => []}
  end
  
  def self.class_delegating_block mid, target
    lambda do |*args, &block|
      begin
        target.__send__(mid, *args, &block)
      ensure
        $@.delete_if {|t| /\A#{Regexp.quote(__FILE__)}:#{__LINE__-2}:/o =~ t} if $@
      end
    end
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
end