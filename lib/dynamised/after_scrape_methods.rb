module Dynamised
  class Scraper
    module After_Scrape
      def scrub_tags(string,field_data)
        string.gsub(/<\/?[^>]*>/, "").strip.gsub(/ ?\\r\\n/,'')
      end

      def unescape_html(string,field_data)
        CGI::unescapeHTML(string)
      end

      def escape_html(string,field_data)
        CGI::escapeHTML(string)
      end

      def page_url(string,field_data)
        @current_url
      end
    end
  end
end
