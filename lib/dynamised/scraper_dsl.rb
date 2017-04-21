module Dynamised
  class Scraper
    module DSL

      # include Tree
      def set_up_tree
        unless @tree
          @tree = Node.new({
            fields:             {},
            meta:               {},
            paginate:           {},
            recursive_select:   false,
            select:             false,
            scrape_if:          nil
          })
          @tree_pointer = []
          @xpath_prefix = []
          @useables = {}
          @writer = nil
          @base_url = ""
          @inc = 1
        end
      end

      def tree_down(key,childs=false)
        @tree_pointer << key
        yield
        @tree_pointer.pop
      end

      def re_useable(name,&block)
        check_for_block(&block)
        @useables[name] = block
      end

      def use(name)
        instance_exec(&@useables[name])
      end

      def set_base_url(url)
        @base_url = url
      end

      def set_pag_increment(value)
        @inc = value
      end


      def xpath_prefix(prefix,&block)
        check_for_block(&block)
        @xpath_prefix << prefix
        block.call
        @xpath_prefix.pop
      end


      def scrape_here_if(args=nil,&block)
        at_p.data[:scrape_if] = args || {block: block}
      end

      def select_crawl
        at_p.data[:select] = true
      end


      def pag_if(check)
        at_p.data[:paginate][:if] = check
      end

      def pag_next(xpath)
        at_p.data[:paginate][:next] = xpath
      end

      def pag_inc(xpath)
        at_p.data[:paginate][:inc] = xpath
      end

      def pag_item(xpath)
        at_p.data[:paginate][:item] = xpath
      end


      def crawl(items,&block)
        items.each do |item,path|
          at_p.new_child(item)
          tree_down(item) do
            set_meta_tag(:crawl_tag,join_xpath(path),{attr: [:attr,:href]})
            block.call
          end
        end
      end


      def set_field(name,xpath,meta={})
        set_info(:fields,name,xpath,meta)
      end

      def set_meta_tag(name,xpath,meta={})
        set_info(:meta,name,xpath,meta)
      end

      def writer(writers=nil,&block)
        @writer = writers || block
      end

      private

      def at_p
        @tree[@tree_pointer]
      end

      def check_for_block(&block)
        raise "No block given for #%s" % caller[0][/`.*'/][1..-2] unless block_given?
      end

      def set_info(type,name,xpath,meta)
        @tree[@tree_pointer].data[type] = @tree[@tree_pointer].data[type].merge({name => {
          xpath: join_xpath(xpath),
          meta: meta
        }})
      end

      def join_xpath(tag)
        tag.empty? ? tag : @xpath_prefix.join + tag
      end


    end
  end
end
