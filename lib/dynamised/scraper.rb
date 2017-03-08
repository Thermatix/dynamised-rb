module Dynamised
  class Scraper
    XPATH_Anchor = ".%s"
    extend DSL

    class << self
      def inherited(base)
        @scrapers ||= {}
        @scrapers[base.to_s.split('::').last.downcase] = base
        base.instance_exec do
          set_up_tree
        end
      end

      def list
        @scrapers ||= {}
        @scrapers.map {|i,s| i}
      end


      def each(&block)
        @scrapers ||= {}
        @scrapers.each(&block)
      end

      def fetch(*args,&block)
        @scrapers ||= {}
        @scrapers.fetch(args.first.downcase) {|name|raise "No scraper called %s was found" % name }
      end

    end

    include Curb_DSL
    include Helpers
    include Before_Scrape
    include After_Scrape
    include Writers

    def initialize(args=[],&block)
      @args = args
      @tree_pointer = []
      @scraped_data = GDBM.new("%s_scraped_data.db" % self.class.to_s)
      [:inc,:uri,:tree,:tree_pointer,:base_url,:writer].each do |attr|
        varb_name = "@%s" % attr
        self.instance_variable_set(varb_name,self.class.instance_variable_get(varb_name))
      end
      super(&block)
    end

    def uri
      @uri ||= self.class.instance_variable_get(:@uri)
    end


    def inc
      @inc ||= self.class.instance_variable_get(:@inc)
    end


    def pull_and_store(&spinner)
      raise "No writer detected" unless @writer
        CSV.open(@writer[:csv], "wb") do |csv|
          headers_written = false
          title = ""
          pull(pull_initial,@tree) do |hash|
    #       the next two lines are a temporary hack to solve the double scrape issue  
            next unless title != hash[:title]
            title = hash[:title]
            (csv << hash.keys && headers_written = true) unless headers_written
            csv << hash.values
            spinner.call
          end
        end
    end

    def pull_and_check
      doc = pull_initial
      seperator = "}#{'-' * 40}{"
      ap seperator
      pull(doc,@tree) do |hash|
        ap hash
        ap seperator
       sleep 0.5
      end
    end



    private

    def scrape_data(&spinner)
      pull(pull_initial) do |hash|
        @scraped_data[@current_url] = hash.to_json
        spinner.call
      end
    end

    def write_data(&spinner)
      @writer.each do |type,data|
        case type
          when :csv
            write_csv(@scraped_data,data,&spinner)
          when :custom
            data.call(@scraped_data,&spinner)
          else
            raise '%s is a non supported writer type'
        end
      end
    end

  # pass through single nodes or array of nodes
    # if single just pass it through, if array treat as group, 
    # check for each sub_tag and then pass group down

    def pull(doc,tree,&block)
      if fields?(tree)
        scrape?(doc,tree,&block)
      end
      childs?(tree) do |pos,node,sub_tr|
        @current_child = node #get_by_ident(sub_tr,pos)
        # tree_down(pos) do
        spt = node.data[:meta][:sub_page_tag]
        scrape_tag_set(doc,spt[:xpath],spt[:meta]) do |url,i|
            ap "%s(%s)|%s" % [pos,i,url]
            # next if @scraped_data[segment?(url)]
            pull(get_doc(segment?(url)),sub_tr||node,&block)
          end
          # end
      end
    end

    def segment?(url)
      url =~ /http/ ? url : "%s/%s"  % [@base_url.gsub(/\/$|\z/,''), url.gsub(/\A\//,'')]
    end

    def tree_down(key,tree=false)
      @tree_pointer << key
      yield
      @tree_pointer.pop
    end

    def fields?(tree)
      not tree.data[:fields].empty?
    end

    def scrape?(doc,tree,&block)
      if can_scrape(doc,tree)
        block.call(tree.data[:fields].each_with_object({}) do |(field,data),res_hash|
          target = execute_method(data[:meta][:before],remove_style_tags(doc),res_hash)
          value = scrape_tag(target,data[:xpath],data[:meta])
          res_hash[field] = value ? execute_method(data[:meta][:after],value,res_hash) : data[:meta].fetch(:default,nil)
        end)
      end
    end

    def remove_style_tags(doc)
      doc.css("style").remove
      doc
    end

    def get_by_ident(tree,ident)
      return false unless tree
      tree.find {|ch_i,ch| ch_i == ident}.last
    end

    def can_scrape(doc,tree)
      scrape_if = tree.data[:scrape_if]
      case true
        when scrape_if.respond_to?(:call)
          scrape_if.call(doc)
        when scrape_if.respond_to?(:keys)
          case true
            when scrape_if.keys.include?(:fields)
              check_for_fields(doc,tree,scrape_if)
          end
        else
          @tree[@tree_pointer].data[:fields].length > 0
      end
    end

    def check_for_fields(doc,tree,scrape_if)
      [*scrape_if[:fields]].find do |field|
        f = (tree || @tree[@tree_pointer]).data[:fields][field]
        search_for_tag(doc,f[:xpath])
      end
    end

    def execute_method(meth_name=nil,*args)
      if meth_name
        self.send(meth_name,*args)
      else
        args.first
      end
    end


    def childs?(node,tree=nil,&block)
      if node.is_a? Array
        tree.each do |child_node|
         childs?(child_node,tree,&block)
        end
      else
        unless node.childs.empty? && node.siblings.empty?
          (node.childs.empty? ? node.siblings : node.childs).each do |ident,child_node|
            block.call(ident,child_node,tree)
          end
        end
      end
    end


    def scrape_tag_set(doc,xpath,meta={})
      (doc.xpath(xpath)).each_with_index do |node,i|
        yield(pull_from_node(node,meta),i)
      end
    end

    def search_for_tag(doc,xpath)
      doc.at_xpath(XPATH_Anchor % xpath)
    end

    def scrape_tag(doc,xpath,meta={})
      pull_from_node(doc.xpath(XPATH_Anchor % xpath),meta)
    end


    def pull_from_node(node,meta)
      (return nil if node.empty?) if node.respond_to?(:empty?)
      (node.respond_to?(:empty?) ? node.first : node).send(*meta.fetch(:attr,:inner_text))
          .send(meta.fetch(:r_type,:to_s))
    end

    def get_doc(url)
      @current_url = url
      set_uri(url)
      get
      to_doc(body)
    end


    def pull_initial
      @inital_pull ||= begin
        get_doc(@base_url)
      end
    end

  end
end