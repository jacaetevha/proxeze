require 'delegate'

def Delegator.delegating_block mid
  lambda do |*args, &block|
    target = self.__getobj__
    begin
      method = mid.to_s

      after_all = self.class.hooks[:after_all]
      after = self.class.hooks[:after][mid]
      before_all = self.class.hooks[:before_all]
      before = self.class.hooks[:before][mid]

      execute_call(before_all, target, mid, args)
      execute_call(before, target, args)

      result = target.__send__(mid, *args, &block)
      result_after = execute_call(after, target, result, args)
      result_after_all = execute_call(after_all, target, result, mid, args)
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