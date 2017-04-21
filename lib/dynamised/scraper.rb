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
      @use_store = false
      @scraped_data = DBM_Wrapper.new("%s_scraped_data" % get_class_name(self.class.to_s))
      [:inc,:uri,:tree,:tree_pointer,:base_url,:writer].each do |attr|
        varb_name = "@%s" % attr
        self.instance_variable_set(varb_name,self.class.instance_variable_get(varb_name))
      end
      super(&block)
    end

    def pull_and_store(&spinner)
      raise "No writer detected" unless @writer
      @use_store = true
      scrape_data(&spinner)
      write_data(&spinner)
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

    def get_class_name(string)
      string.split('::').last.split('.').first.gsub(/ /,'_').capitalize
    end

    def scrape_data(&spinner)
      pull(pull_initial,@tree) do |hash|
        spinner.call
      end
    end

    def write_data(&spinner)
      parsed_data = @scraped_data.map {|r| JSON.parse(r) }
      @writer.each do |type,data|
        case type
          when :csv
            write_csv(parsed_data, data, &spinner)
          when :custom
            data.call(parsed_data, &spinner)
          else
            raise '%s is a non supported writer type'
        end
      end
      @scraped_data.stop
    end


    def pull(doc,tree,&block)
      if fields?(tree)
        scrape(doc,tree,&block)
      end
      if pagination?(doc,tree)
        paginate(tree) do |item|
          pull(item,tree,&block)
        end
      else
        childs(tree) do |pos,node,sub_tr|
          @current_child = node
          spt = node.data[:meta][:crawl_tag]
          scrape_tag_set(doc,spt[:xpath],spt[:meta]) do |url,i|
            pull(get_doc(segment?(url)),sub_tr||node,&block)
          end
        end
      end
    end

    def paginate(doc,tree)
      current_page = doc
      max = scrape_tag(current_page,tree[:paginate][:max],{r_type: :to_i})
      raise "No paginate max tag found" unless max
      (1..max).each do
        (current_page.xpath(tree[:paginate][:item])).each do |node|
          yield(item)
        end
        current_page = get_doc(current_page.xpath(tree[:paginate][:next]).attr('href'))
      end
    end

    def pagination?(doc,tree)
      search_for_tag(doc,tree[:paginate][:if])
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

    def scrape(doc,tree,&block)
      c_url = @current_url
      if (@use_store ? !@scraped_data[c_url] : true) && can_scrape(doc,tree)
        fields =
        tree.data[:fields].each_with_object({}) do |(field,data),res_hash|
          target = execute_method(data[:meta][:before],remove_style_tags(doc),res_hash)
          value = scrape_tag(target,data[:xpath],data[:meta])
          res_hash[field] =
          if value
            [*data[:meta][:after]].each do |method|
              execute_method(method,value,res_hash)
            end
          else
            data[:meta].fetch(:default,nil)
          end
        end
        @scraped_data[c_url] = fields.to_json if @use_store
        block.call(fields)
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


    def childs(node,tree=nil,&block)
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
