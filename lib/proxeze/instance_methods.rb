module Proxeze
  module InstanceMethods
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
end