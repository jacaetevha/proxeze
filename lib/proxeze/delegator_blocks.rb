require 'delegate'

def Delegator.delegating_block mid
  lambda do |*args, &block|
    target = self.__getobj__
    begin
      mid    = mid.to_sym
      method = mid.to_s

      after_all = self.class.hooks[:after_all]
      after = self.class.hooks[:after] ? self.class.hooks[:after][mid] : nil
      before_all = self.class.hooks[:before_all]
      before = self.class.hooks[:before] ? self.class.hooks[:before][mid] : nil

      execute_call(before_all, :before_all, target, args, mid)
      execute_call(before, :before, target, args, mid)

      result = target.__send__(mid, *args, &block)
      result_after = execute_call(after, :after, target, args, mid, result)
      result_after_all = execute_call(after_all, :after_all, target, args, mid, result)
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

unless RUBY_VERSION =~ /1\.9/
  def DelegateClass(superclass)
    klass = Class.new
    methods = superclass.public_instance_methods(true)
    methods -= ::Kernel.public_instance_methods(false)
    methods |= ["to_s","to_a","inspect","==","=~","==="]
    klass.module_eval {
      def initialize(obj)  # :nodoc:
        @_dc_obj = obj
      end
      def method_missing(m, *args, &block)  # :nodoc:
        unless @_dc_obj.respond_to?(m)
          super(m, *args, &block)
        end
        @_dc_obj.__send__(m, *args, &block)
      end
      def respond_to?(m, include_private = false)  # :nodoc:
        return true if super
        return @_dc_obj.respond_to?(m, include_private)
      end
      def __getobj__  # :nodoc:
        @_dc_obj
      end
      def __setobj__(obj)  # :nodoc:
        raise ArgumentError, "cannot delegate to self" if self.equal?(obj)
        @_dc_obj = obj
      end
      def clone  # :nodoc:
        new = super
        new.__setobj__(__getobj__.clone)
        new
      end
      def dup  # :nodoc:
        new = super
        new.__setobj__(__getobj__.clone)
        new
      end
    }
    for method in methods
      begin
        klass.module_eval do
          define_method method, Delegator.delegating_block(method)
        end
      rescue SyntaxError
        raise NameError, "invalid identifier %s" % method, caller(3)
      end
    end
    return klass
  end
end