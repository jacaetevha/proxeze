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
  
  def self.proxy target_class
    cls_name = target_class.name.gsub '::', ''
    unless self.class_defined? cls_name
      cls = DelegateClass target_class
      cls.send :include, self
      meta = class << target_class; self; end
      meta.class_eval %Q{
        def new_with_extra_behavior *args, &blk
          #{cls_name}.new( self.new_without_extra_behavior(*args, &blk) )
        end
        alias_method :new_without_extra_behavior, :new
        alias_method :new, :new_with_extra_behavior
      }, __FILE__, __LINE__
      self.const_set cls_name, cls
    end
    self.const_get cls_name
  end
  
  def self.for object
    self.proxy( object.class ).new( object )
  end
  
  def clone
    self.class.for __getobj__.clone
  end

  def proxy
    self.class.for __getobj__
  end
end