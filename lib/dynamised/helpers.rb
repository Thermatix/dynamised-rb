module Dynamised
  class Scraper
    module Helpers
      def to_doc(html)
        Nokogiri::HTML(html)
      end

      def crawl(html_listing)
        html_listing.xpath(".%s" % get_crawl_tag[:path]).attr('href').to_s
      end

      def mpc(doc)
        get_mpc(doc.xpath(get_mpc_tag[:path]))
      end

      def get_mpc(doc)
        doc[-2].respond_to?(:inner_text) ? doc[-2].inner_text.to_i : 0
      end

      def field_keys
        @current_page.data[:fields].keys
      end

    end
  end
end
