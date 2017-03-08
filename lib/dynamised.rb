%w{tty-spinner nokogiri awesome_print gdbm json}.each {|lib| require lib}
%w{meta after_scrape_methods before_scrape_methods curb_dsl helpers node scraper_dsl writers dbm_wrapper scraper}
  .each do |f|
  require_relative "dynamised/%s" % f
end
module Dynamised
  # Your code goes here...
end
