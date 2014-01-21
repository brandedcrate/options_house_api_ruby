require 'rubygems'
require 'bundler/setup'
require 'net/https'
require 'json'
require 'logger'


# OptionsHouseApi Gem Namespace.
module OptionsHouse
  
  # Base API functionality.
  #
  # The class provides minimal required functionality to be able to communicate
  # with OptionsHouse API.
  #
  class Api

    # Any other errors: argument error, unexpected response from OptionsHouse, etc.
    class Error < StandardError
    end


    # OptionsHouse API  Errors.
    # This type of error can be disabled using :raise option.
    # @see OptionsHouse::API#initialize method
    #
    class ApiError < Error
    end


    # OptionsHouse API Authentication Errors.
    #
    # The error is raised when provided credentials are wrong.
    #
    class AuthError < ApiError
    end


    # OptionsHouse API endpoints URL.
    REMOTE_HOST = 'https://api.optionshouse.com'

    # Base OpenHouse API path.
    BASE_PATH   = '/m'

    # Order related OpenHouse API path.
    ORDER_PATH  = '/j'

    MAX_LOG_MESSAGE_SIZE = 50

    # Min delay (in seconds) between 2 consecutive API calls.
    MIN_API_REQUEST_DELAY = 1.0

    # OptiohsHouse API restrictions
    MAX_EZ_MESSAGES_IN_EZ_LIST = 3

    # Current AothToken.
    attr_reader :auth_token

    # Current logger (can be nil).
    attr_reader :logger

    # A set of original params.
    attr_reader :options

    # Current API password.
    attr_reader :password

    # Last API request.
    attr_reader :request

    # Last API response.
    attr_reader :response

    # Current API username.
    attr_reader :username


    # Creates a new handler to manage your OptionsHouse data.
    #
    # @param [String] username
    # @param [String] password
    # @param [Hash]   options
    # @option options [Symbol] :auth_token
    # @option options [Symbol] :logger
    # @option options [Symbol] :remote_host
    # @option options [Symbol] :raise  When set to +false+ it does not fail on
    #  API errors but returns them
    # @option options [Symbol] :fast_api By default the code makes delays follow OptionHouse requirements
    #  (not more than 1 API call per second). When the flag set to +true+ it does not make any delays.
    #  Be careful with this, because OptionsHouse may ban you if you are too fast.
    #
    def initialize(username, password, options={})
      @username     = username
      @password     = password
      @auth_token   = options[:auth_token]
      @connection   = nil
      @logger       = options[:logger]
      @request      = nil
      @response     = nil
      @uri          = URI.parse(options[:remote_host] || REMOTE_HOST)
      @options      = options.dup
      @options[:raise] = true if !options.has_key?(:raise) || options[:raise]
    end


    # Logs the given message under the given log level.
    #
    # @param [String,Symbol] level  One of: :debug, :info, :warn, :error, :critical
    # @param [String] log_message  Message to log
    #
    # @return [Object] Returns the message object back.
    #
    def log(level, log_message='')
      logger.__send__(level, log_message.to_s) if logger
      log_message
    end


    # Returns +true+ if authenticated and +false+ otherwise.
    #
    # @return [Boolean]
    #
    def authenticated?
      !!@auth_token
    end


    # Returns +true+ if there is an established connection to the remote host
    # and  +false+ otherwise.
    #
    # @return [Boolean]
    #
    def connected?
      !!@connection && @connection.started?
    end


    # Creates a new connection to OptionsHouse.
    #
    # @return [void]
    #
    def connect
      # Make sure the old connection is closed.
      disconnect
      # Create a new connection.
      log(:debug, "Establishing a new connection to #{@uri.host}")
      @connection             = Net::HTTP.new(@uri.host, @uri.port)
      @connection.use_ssl     = true
      @connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
      @connection.start
      log(:debug, "Connection successfully established")
    rescue => e
      log(:error, "Failed to established SSL connection to #{@uri.host}: #{e.inspect}")
      fail e
    end


    # Closes current connection to OptionsHouse.
    #
    # @return [void]
    #
    def disconnect
      if connected?
        @connection.finish
        log(:debug, "Connection successfully closed")
      end
    rescue => e
      log(:error, "Close connection error: #{e.class.name}: #{e.message}")
    ensure
      @connection = nil
    end


    # The method checks if there is any of the required top level keys and raises
    # an exception when none of them presents.
    #
    # @return [TrueClass]
    #
    # @raise [OptionsHouseApi::Error] When the response is unexpected.
    #
    def validate_message_consistency!(message)
      return true if message['EZMessage']

      if message['EZList']
        return true if message['EZList'].size <= MAX_EZ_MESSAGES_IN_EZ_LIST
        fail(Error, "EZList cannot have more that #{MAX_EZ_MESSAGES_IN_EZ_LIST} EZMessages.")
      end

      fail(Error, "Unexpected message format: either 'EZMessage' or 'EZList' " + 
                  "is expected as a top level key.")
    end


    # Adds current ApiToken to the message.
    #
    # @param [Hash] message
    #
    # @return [Hash]
    #
    def sign(message)
      validate_message_consistency!(message)
      items = (message['EZMessage'] ? [message['EZMessage']] : message['EZList'])
      items.each do |item|
        item['data']['authToken'] = @auth_token
      end
      message
    end


    # Establishes a connection to the remote host and makes a POST API request.
    #
    # @param [String] path  see BASE_PATH, ORDER_PATH.
    # @param [String] body  POST request body.
    #
    # @return [void]
    #
    # @raise [OptionsHouseApi::Error] When unexpected response is received.
    #
    def make_http_request(path, body)
      # Be clever not to bother OpenHouse too much (and too fast)
      if !@options[:fast_api] && @last_request_at
        secs = Time.now.utc - @last_request_at
        sleep(MIN_API_REQUEST_DELAY - secs) if secs < MIN_API_REQUEST_DELAY
      end

      @response     = nil
      @request      = Net::HTTP::Post.new(path)
      @request.body = body
      # Create a connection unless it is.
      connect unless connected?
      # Make a request.
      log(:debug, "Sending message: #{body[0..MAX_LOG_MESSAGE_SIZE]}...")
      @response = @connection.request(@request)
      # In case of unexpected response, complain:
      if (@response.code != '200') || (!@response['content-type'].to_s[/json/])
        fail(Error, "Unexpected response received: #{response.code.inspect} \n" +
                    "Headers: #{response.to_hash.inspect}\n" + 
                    "Body   : #{response.body.inspect}\n")
      end
    ensure
      @last_request_at = Time.now.utc
    end
    private :make_http_request


    # Analyzes am HTTP response.
    #
    # @return [Hash] The message.
    #
    # @raise [OptionsHouseApi::AuthError] When creds are wrong or expired.
    #
    def analyze_response
      # Return parsed response
      message = JSON.parse(@response.body)
      validate_message_consistency!(message)
      # Grab API errors.
      errors = case 
               when message['EZMessage']
                 [ message['EZMessage']['errors'] ]
               when message['EZList']
                 message['EZList']['EZMessage'].map { |emz| emz['errors'] }
               end
      errors = errors.flatten.compact

      unless errors.empty?
        # Fail if there is auth problem.
        errors.each do |error|
          next unless error['access']
          @auth_token = nil
          fail(AuthError)
        end
        # Fail on any other error.
        fail(ApiError, "Error: #{errors.inspect}") if options[:raise]
      end
      # Return API response.
      message
    end
    private :analyze_response


    # Sends the given message to the remote endpoint.
    # No pre-process is performed on the message: it should be signed already.
    #
    # @param [String] path
    # @param [String] message
    #
    # @return [Hash] API response.
    #
    def send_message(path, message)
      make_http_request(path, "r=#{message.to_json}")
      analyze_response
    end


    # Authenticates.
    #
    # @return [TrueClass] The method either return +true+ on success or 
    # @raise  [OptionsHouseApi::Error]  On any error
    #
    def authenticate
      @auth_token = nil
      ez_message = {
       'EZMessage' => {
          'action' => 'auth.login',
          'data'   => {
            'userName' => @username,
            'password' => @password,
          }
        }
      }
      response    = send_message(BASE_PATH, ez_message)
      @auth_token = response['EZMessage']['data']['authToken']
      true
    end
  end
end


require File.expand_path(File.join(File.dirname(__FILE__), 'options_house'))
