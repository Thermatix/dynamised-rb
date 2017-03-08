require "csv"
require "json"
module Dynamised
  class Scraper
    module Writers
      def write_csv(scraped_data,file_name,&spinner)
        CSV.open(file_name, "wb") do |csv|
          headers_written = false
          title = ""
          @scraped_data.each do |url,json|
            hash = JSON.parse(json)
    #       the next two lines are a temporary hack to solve the double scrape issue  
            next unless title != hash[:title]
            title = hash[:title]
            (csv << hash.keys && headers_written = true) unless headers_written
            csv << hash.values
            spinner.call
          end
      end
      end
    end

  end
end
