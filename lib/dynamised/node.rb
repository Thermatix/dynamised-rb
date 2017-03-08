module Dynamised
  class Node
    include Enumerable

    attr_accessor :childs,:init, :data, :ident,:siblings


    def initialize(init={},ident=nil)
      @ident  = ident
      @childs = {}
      @sibilngs =  {}
      @init   = init.clone
      @data   = init.clone
    end

    def each(&block)
      block.call(self)
      @childs.map do |key,child|
        child.each(&block)
      end
    end

    def <=>(other_node)
      @data <=> other_node.data
    end

    def [](*keys)
      return self if @childs.empty?
      [*keys.flatten].inject(self) do |node,ident|
          node.find {|n| n.ident == ident}
      end
    end

    def new_child(ident,&block)
      child = self.class.new(@init,ident)
      child.siblings = self.childs
      child.tap(&block) if block_given?
      @childs[ident] = child
    end

    def pretty_print(pp)
      self.each {|node| pp.text(node.ident || "" );puts "\n";pp.pp_hash node.data}
    end

  end
end
