require "curb"
require 'cgi'

module Curb_DSL
  Regex = {
    cookie_header: /Set-Cookie: /
  }
  def self.included(base)
    base.extend Singleton
    base.instance_eval do
      attr_reader :curl, :headers,:payload, :username, :password, :auth_type, :uri, :ssl, :redirects, :type_converter,:cookies, :form_field_name, :form_fields

      [:get, :post, :put, :delete, :head, :options, :patch, :link, :unlink].each do |func_name|
        define_method func_name do |&block|
          make_request_of func_name.to_s.upcase, &block
        end
      end

      [:password,:username,:payload, :auth_type, :uri, :ssl, :redirects,:type_converter,:cookies,:form_field_name,:error_handler].each do |func_name|
        define_method "set_#{func_name}" do |value|
          self.instance_variable_set :"@#{func_name}", value
        end
      end
    end

    def form_field name,value
      @form_fields ||= []
      if @form_field_name
        @form_fields.push(Curl::PostField.content([("%[%]" % [@form_field_name,name]),value.to_s]))
      else
        @form_fields.push(Curl::PostField.content(name ,value.to_s))
      end
    end



  end

  module Singleton
    def request(&block)
      self.new(&block).body
    end

    def query_params(value)
      Curl::postalize(value)
    end
  end



  def initialize(&block)
    @headers ||= {}
    instance_eval(&block) if block_given?
  end

  def header(name, content)
    @headers ||= {}
    @headers[name] = content
  end

  def make_request_of(request_method,i_e =nil,&block)
    i_e ||= @ignore_error
    @resp_cookies = nil
    @curl = Curl::Easy.new(@uri) do |http|
      setup_request request_method, http
    end
    @curl.ssl_verify_peer = @ssl ||false
    # @curl.ignore_content_length = true
    if @form_fields
      @curl.http_post(*@form_field)
    else
      @curl.http request_method
    end
    if @curl.response_code == 301
      @uri =  @curl.redirect_url
      make_request_of request_method, i_e
    end
    if @curl.response_code != 200
      if @error_handler
        puts @error_handler.call unless i_e
      end
    end
    @ignore_error = false
  end

  def status_code
    @curl.response_code
  end

  def decode_html(string)
    CGI.unescapeHTML(string)
  end

  def encode_html(string)
    CGI.escapeHTML(string)
  end

  def post_body
    get_payload
  end

  def ignore_error
    @ignore_error = true
  end

  def body
    @curl.body
  end

  def response_code
    @curl.response_code
  end

  def response_cookies
    @resp_cookies ||=
    @curl.header_str.split("\r\n").each_with_object({}) do |header,headers|
      if header =~ Regex[:cookie_header]
        header.gsub(Regex[:cookie_header],'').split(';').each do |segment|
          unless segment =~ /secure/
            headers[$1.strip.downcase] = $2.gsub('"','') if segment =~ /(.*?)=(.*?)($|;|,(?! ))/
          end
        end
      end
    end
  end

  def query_params(value)
    Curl::postalize(value)
  end


  private


  def setup_request(method,http)
    http.headers['request-method'] = method.to_s
    http.headers.update(headers || {})
    http.max_redirects = @redirects || 3
    http.post_body = get_payload || nil
    http.http_auth_types = @auth_type || nil
    http.username = @username || nil
    http.password = @password || nil
    http.useragent = "curb"
    http.multipart_form_post = @form_field_name ? true : false
    if @cookies
      http.enable_cookies = true
      http.cookies = (@cookies.is_a? String) ? @cookies : @cookies.inject("") {|cookies,data| "%s%s=%s;" % data.unshift(cookies) }
    end
    http
  end


  def get_payload
    if @type_converter
      @type_converter.call(@payload)
    else
      @payload
    end
  end

end
