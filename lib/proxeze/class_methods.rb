module Proxeze
  module ClassHooks
    def hooks
      @hooks ||= {:after => {}, :after_all => {}, :before => {}, :before_all => {}}
    end
    
    # The after hook will receive 3 arguments:
    # target, result, and any arguments to the
    # method that was called.
    def after mid, *args, &blk
      insert_into_callback_chain :hook => :after, :mid => mid, :args => args, :blk => blk
    end

    # The after_all hook will receive 4 arguments:
    # target, result, method id, and any arguments
    # to the method that was called.
    def after_all &blk
      insert_into_callback_chain :hook => :after_all, :blk => blk
    end

    # The before hook will receive 2 arguments:
    # target and any arguments to the method that
    # is being called.
    def before mid, *args, &blk
      insert_into_callback_chain :hook => :before, :mid => mid, :args => args, :blk => blk
    end

    # The before_all hook will receive 3 arguments:
    # target, method id, and any arguments to the
    # method that is being called.
    def before_all &blk
      insert_into_callback_chain :hook => :before_all, :blk => blk
    end
    
    private
      def insert_into_callback_chain options={}
        hook, mid, args, blk = options[:hook], options[:mid], options[:args], options[:blk]
        callback = blk.nil? ? args : blk
        if mid
          self.hooks[hook] ||= {}
          self.hooks[hook][mid] = callback
        else
          self.hooks[hook] = callback
        end
      end
  end
end