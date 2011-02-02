require 'delegate'

module Proxeze
  if RUBY_VERSION =~ /1\.9/
    def self.class_defined? name
      const_defined? name, false
    end
  else
    def self.class_defined? name
      const_defined? name
    end
  end
  
  def self.proxy target_class, redefine_new_method = true
    cls_name = target_class.name.gsub '::', ''
    unless self.class_defined? cls_name
      cls = DelegateClass target_class
      cls.send :include, self
      self.const_set cls_name, cls
    end

    # we have to collect the methods as Strings here because
    # 1.9 changed the implementation to return Symbols instead of Strings
    if redefine_new_method && !target_class.methods.collect{|e| e.to_s}.include?('new_with_extra_behavior')
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
  
  # create a proxy object for the given object
  def self.for object
    self.proxy( object.class, false ).new( object )
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