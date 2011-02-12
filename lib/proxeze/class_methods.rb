module Proxeze
  module ClassMethods
    def hooks
      @hooks ||= {:after => {}, :after_all => {}, :before => {}, :before_all => {}}
    end
    
    def after mid, &blk
      insert_into_callback_chain :after, mid, blk
    end

    def after_all &blk
      insert_into_callback_chain :after_all, nil, blk
    end

    def before mid, &blk
      insert_into_callback_chain :before, mid, blk
    end

    def before_all &blk
      insert_into_callback_chain :before_all, nil, blk
    end
    
    private
      def insert_into_callback_chain hook, mid, blk
        if mid
          self.hooks[hook] ||= {}
          self.hooks[hook][mid] = blk
        else
          self.hooks[hook] = blk
        end
      end
  end
end