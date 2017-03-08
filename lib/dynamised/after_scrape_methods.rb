module Dynamised
  class Scraper
    module After_Scrape
      def scrub_tags(string,field_data)
        string.gsub(/<\/?[^>]*>/, "").strip.gsub(/ ?\\r\\n/,'')
      end

      def page_url(string,field_data)
        @current_url
      end
    end
  end
end
