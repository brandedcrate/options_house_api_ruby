module OptionsHouse

  # Main API functionality.
  #
  # The class provides full support for OptionsHouse API.
  #
  class Manager < OptionsHouse::Api

    # Returns a new representation of EZMessage by the given action and data.
    #
    # @param [String] action
    # @param [Hash]   data
    #
    # @return [Hash]
    #
    def EZMessage(action, data)
      {
        'EZMessage' => {
          'action' => action,
          'data'   => data
        }
      }
    end


    # Joins the given EZMessage(s) into a single EZList hash.
    #
    # @param  [Hash, Array] ez_messages
    # @return [Hash]
    #
    def EZList(*ez_messages)
      {
        'EZList' => ez_messages.flatten.map { |ezm| ezm['EZMessage'] }
      }
    end


    # Sends the given EZMessage or EZList.
    #
    # The message is automatically signed and then sent. The method authenticates
    # when required (if no login was performed yet or current token expired).
    #
    # @param [String] path  see BASE_PATH, ORDER_PATH
    # @param [String] message
    #
    # @return [Hash] API response.
    #
    def api(path, message)
      authenticate unless authenticated?
      begin
        send_message(path, sign(message))
      rescue AuthError
        authenticate
        send_message(path, sign(message))
      end
    end


    # Creates an EZMessage or a EZList by the given action and message(s) data and makes an
    # API call against BASE_PATH.
    #
    # @param [String]      action
    # @param [Hash, Array] Single or multiple messages data.
    #
    # @return [Object]
    #
    # @example
    #   # Fetch data using EZMessage (single item).
    #   options_house.ez_base('view.series', {'symbol' => 'AAPL'})
    #     {
    #       'EZMessage => {...}
    #     }
    #
    # @example
    #   # Fetch data using EZList (multiple items, but not more than MAX_EZ_MESSAGES_IN_EZ_LIST)
    #   items = [{'symbol' => 'AAPL'},
    #            {'symbol' => 'MSFT'}]
    #   options_house.ez_base('view.series', items) #=>
    #     {
    #       'EZList' => {
    #         'EZMessage => [...]
    #       }
    #     }
    #
    def ez_base(action, *data)
      data = data.flatten
      data << {} if data.empty?
      fail(Error, "At least one data item is expected.") if data.empty?
      if data.size == 1
        api(BASE_PATH, EZMessage(action, data.first))
      else
        ezms = data.map { |item| EZMessage(action, item) }
        api(BASE_PATH, EZList(ezms))
      end
    end


    # Creates an EZMessage or a EZList by the given action and message(s) data and makes an
    # API call against ORDER_PATH.
    #
    # @param [String]      Action
    # @param [Hash, Array] Single or multiple messages data.
    #
    # @return [Object]
    #
    # @see ez_base
    #
    def ez_order(action, *data)
      data = data.flatten
      fail(Error, "At least one data item is expected.") if data.empty?
      if data.size == 1
        api(ORDER_PATH, EZMessage(action, data.first))
      else
        ezms = data.map { |item| EZMessage(action, item) }
        api(ORDER_PATH, EZList(ezms))
      end
    end


    # Starts a new API Session.
    #
    # The action is optional: unless logged in the gem auto authenticates on
    # the first API request.
    #
    # @return [TrueClass]
    #
    # @example
    #   options_house.auth_login #=> true
    #
    def auth_login
      authenticate
    end


    # Ends current API Session.
    #
    # @return [TrueClass]
    #
    # @example
    #   options_house.auth_logout
    #
    def auth_logout
      ez_base('auth.logout') if authenticated?
      disconnect             if connected?
      true
    end


    # Refreshes Token Expiration Windows.
    #
    # @param [String] account
    #
    # @example
    #   options_house.keep_alive(account) #=>
    #     {"EZMessage"=>
    #       {"action"=>"auth.keepAlive",
    #        "data"=>
    #         {"refreshRate.quote"=>"7",
    #          "refreshRate.position"=>"15",
    #          "refresh"=>"7",
    #          "refreshRate.exchangelookup"=>"5",
    #          "refreshRate.watchlist"=>"7",
    #          "refreshRate.accountorder"=>"15",
    #          "refreshRate.messagecenter"=>"60",
    #          "refreshRate.cash"=>"15",
    #          "refreshRate.chart"=>"7",
    #          "refreshRate.chain"=>"7",
    #          "refreshRate.accountdetail"=>"15"}}}
    #
    def auth_keep_alive(account)
      ez_base('auth.keepAlive', 'account' => account)
    end


    # Returns Account Details.
    #
    # @return [Hash]
    #
    # @example
    #   options_house.account_info #=>
    #     {"EZMessage"=>
    #       {"data"=>
    #         {"account"=>
    #           {"currentCommissionSchedule"=>"COMMISSION_VI",
    #            "accountTypeId"=>"0",
    #            "optionsWarning"=>"false",
    #            "nextCommissionSchedule"=>"COMMISSION_VI",
    #            "riskMaxDollarsPerOrder"=>"5000000",
    #            ... }},
    #        "action"=>"account.info"}}
    #
    def account_info
      ez_base('account.info')
    end


    # Returns Finances and Portfolio Information.
    #
    # @param [String] account
    #
    # @return [Hash]
    #
    # @example
    #   options_house.account_cash(account) #=>
    #     {"EZMessage"=>
    #       {"data"=>
    #         {"cashHold"=>"0.00",
    #          "optionBuyingPower"=>"5000.00",
    #          "availableToTrade"=>"5000.00",
    #          "cashBalance"=>"5000.00",
    #          "dayTradingBuyPower"=>"0.00",
    #          "stockBuyingPower"=>"10000.00",
    #          "availableToWithdraw"=>"0.00"},
    #        "action"=>"account.cash"}}
    #
    def account_cash(account, options={})
      params = options.merge('account' => account)
      ez_base('account.cash', params)
    end


    # Returns Quote Data.
    #
    # @param [String,Array] key
    # @param [Hash] options
    # @option options [Array] 'addExtended'
    # @option options [Array] 'addStockDetails'
    # @option options [Array] 'addFundamentalDetails'
    #
    # @return [Hash]
    #
    # @example
    #   options_house.view_quote_list('COP:::S') #=>
    #     {"EZMessage"=>
    #       {"action"=>"view.quote.list",
    #        "data"=>
    #         {"quote"=>
    #           {"earningsConfirm"=>"false",
    #            "symbol"=>"COP",
    #            "high"=>"70.16",
    #            "vol"=>"4664600",
    #            "mark"=>"69.375",
    #            "divConfirm"=>"false",
    #            "hasEarnings"=>"false",
    #            "earningsDate"=>"null",
    #            "hasDividends"=>"true",
    #            "prevClose"=>"69.43",
    #            "ask"=>"69.43",
    #            "last"=>"69.43",
    #            "key"=>"COP:::S",
    #            "stockLast"=>"69.43",
    #            "divAmount"=>"0.69",
    #            "exDate"=>"Mon Jan 13 00:00:00 CST 2014",
    #            "dailyChange"=>"0.0",
    #            "bid"=>"69.32",
    #            "low"=>"69.29",
    #            "isExchangeDelayed"=>"false"}}}}
    #
    def view_quote_list(key, options={})
      key    = [ key ] unless key.is_a?(Array)
      params = options.merge('key' => key)
      ez_order('view.quote.list', params)
    end


    # Returns Options Series.
    #
    # @param [String] symbol
    # @param [Hash] options
    # @option options [Boolean] 'quarterlies'
    # @option options [Boolean] 'weeklies'
    #
    # @return [Hash]
    #
    # @example
    #   options_house.view_series('AAPL') #=>
    #     {"EZMessage"=>
    #       {"action"=>"view.series",
    #        "data"=>
    #         {"q"=>"555.04504",
    #          "s"=>
    #           [{"k"=>
    #              ["AAPL:20131221:490:P",
    #               "AAPL:20131221:500:C",
    #               ... ],
    #            {"multiplier"=>"10.0",
    #             "spc"=>"10",
    #             "isMini"=>"true",
    #             "content"=>"AAPL7:20160115:7950000:P",
    #             "isNormal"=>"false"}],
    #          "e"=>"Jan 16"}]}}}
    #
    def view_series(symbol, options={})
      params = options.merge('symbol' => symbol)
      ez_base('view.series', params)
    end


    # Pre-verify a new order.
    #
    # @param [String] account
    # @param [Hash] order
    #
    # @return [Hash]
    #
    # @example
    #   order = {
    #     'm_order_id'              => '1',
    #     'price_type'              => 'limit',
    #     'time_in_force'           => 'day',
    #     'price'                   => '70.00',
    #     'order_type'              => 'regular',
    #     'order_subtype'           => 'regular',
    #     'underlying_stock_symbol' => 'COP',
    #     'source'                  => 'API',
    #     'client_id'               => Time.now.to_i,
    #     'preferred_destination'   => 'BEST',
    #     'legs'                    => [{
    #       'index'         => 0,
    #       'side'          => 'buy',
    #       'security_type' => 'stock',
    #       'quantity'      => '5',
    #       'key'           => 'COP:::S',
    #       'multiplier'    => '1',
    #       'position_type' => 'opening'
    #     }]
    #   }
    #   options_house.preview_order(account, order) #=>
    #     {"EZMessage"=>
    #       {"action"=>"account.margin.json",
    #        "data"=>
    #         {"dayTradesActualPrior"=>"0",
    #          "patternDayTrader"=>"false",
    #          "noDatabaseRecord"=>"true",
    #          "dayTradesActualAfterOrder"=>"0",
    #          "marginChange"=>"-86.3500",
    #          "orgSma"=>"5000.0000",
    #          "fudgeFactor"=>"0.0000",
    #          "stockBuyingPower"=>"9635.9000",
    #          "optionBuyingPower"=>"4817.9500",
    #          "commission"=>
    #           [{"m_order_id"=>"1",
    #             "commission"=>"4.7500",
    #             "fee"=>
    #              {"CBOE"=>"0.0000",
    #               "SEC"=>"0.0100",
    #               "DIRECTED_ORDER"=>"0.0000",
    #               "OCC"=>"0.0000",
    #               "TAF"=>"0.0100",
    #               "PENNY_STOCK"=>"0.0000",
    #               "INDEX"=>"0.0000"}}],
    #          "warning"=>
    #           "The market for this security is currently closed.  If you place this order it will be submitted when the market opens."}}}
    #
    # P.S. Plz refer to OptionsHouse API docs for order keys.
    #
    def account_margin_json(account, order)
      params = {
        'account' => account,
        'order'   => order,
      }
      ez_order('account.margin.json', params)
    end
    alias_method :preview_order, :account_margin_json


    # Creates a new order.
    #
    # @param [String] account
    # @param [Hash] order
    #
    # @return [Hash]
    #
    # @example
    #   order = {
    #     'm_order_id'              => '1',
    #     'price_type'              => 'limit',
    #     'time_in_force'           => 'day',
    #     'price'                   => '70.00',
    #     'order_type'              => 'regular',
    #     'order_subtype'           => 'regular',
    #     'underlying_stock_symbol' => 'COP',
    #     'source'                  => 'API',
    #     'client_id'               => Time.now.to_i,
    #     'preferred_destination'   => 'BEST',
    #     'legs'                    => [{
    #       'index'         => 0,
    #       'side'          => 'buy',
    #       'security_type' => 'stock',
    #       'quantity'      => '5',
    #       'key'           => 'COP:::S',
    #       'multiplier'    => '1',
    #       'position_type' => 'opening'
    #     }]
    #   }
    #   options_house.create_order(account, order) #=>
    #     {"EZMessage"=>
    #       {"action"=>"order.create.json",
    #        "data"=>{"created"=>"true", "id"=>"192743916"}}}
    #
    def order_create_json(account, order)
      params = {
        'account' => account,
        'order'   => order,
      }
      ez_order('order.create.json', params)
    end
    alias_method :create_order, :order_create_json


    # Modifies an order.
    #
    # @param [String] account
    # @param [Hash] order
    #
    # @return [Hash]
    #
    # @example
    #   order   = {
    #     'modify_order'            => true,
    #     'order_id'                => '192743916',
    #     'm_order_id'              => '1',
    #     'price_type'              => 'limit',
    #     'time_in_force'           => 'day',
    #     'price'                   => '70.00',
    #     'order_type'              => 'regular',
    #     'order_subtype'           => 'regular',
    #     'underlying_stock_symbol' => 'COP',
    #     'source'                  => 'API',
    #     'client_id'               => Time.now.to_i,
    #     'preferred_destination'   => 'BEST',
    #     'legs'                    => [{
    #       'index'         => 0,
    #       'side'          => 'buy',
    #       'security_type' => 'stock',
    #       'quantity'      => '7',
    #       'key'           => 'COP:::S',
    #       'multiplier'    => '1',
    #       'position_type' => 'opening'
    #     }]
    #   }
    #   options_house.preview_order(account, order) #=>
    #     {"EZMessage"=>
    #       {"action"=>"order.modify.json",
    #        "data"=>{"modified"=>"true", "id"=>"192743917"}}}
    #
    def order_modify_json(account, order)
      params = {
        'account' => account,
        'order'   => order,
      }
      ez_order('order.modify.json', params)
    end
    alias_method :modify_order, :order_modify_json


    # Cancels an order.
    #
    # @param [String] account
    # @param [String] order_is
    #
    # @return [Hash]
    #
    # @example
    #   options_house.order_cancel_json(account, 192743916)
    #     {"EZMessage"=>
    #       {"action"=>"order.cancel.json",
    #        "data"=>{"canceled"=>"true", "id"=>"192743916"}}}
    #
    def order_cancel_json(account, order_id)
      params = {
        'account'  => account,
        'order_id' => order_id,
      }
      ez_order('order.cancel.json', params)
    end
    alias_method :cancel_order, :order_cancel_json


    # Retrieves the current status and details of a specific order.
    #
    def order_details(account_id, order_details)
      params = {
        'account_id'    => account_id,
        'order_details' => order_details,
      }
      ez_base('order.details', params)
    end


    # Retrieves status changes for a single order.
    #
    def order_history(account_id, order_history)
      params = {
        'account_id'    => account_id,
        'order_history' => order_history,
      }
      ez_base('order.history', params)
    end


    # Returns all orders related to the account.
    #
    # @params [String] account_id
    # @param  [Hash] master_order
    #
    # @return [Hash]
    #
    # @example
    #   master_order = {
    #     "page"              => 0,
    #     "page_count"        => 3,
    #     "page_size"         => 30,
    #     "master_order_view" => "current",
    #   }
    #   options_house.master_account_orders(account, master_order) #=>
    #     {"EZMessage"=>
    #       {"action"=>"master.account.orders",
    #        "data"=>
    #         {"timestamp"=>"2013-12-20 00:47:15.993932",
    #          "response_type"=>"json",
    #          "master_account_orders"=>
    #           {"page"=>0,
    #            "page_size"=>30,
    #            "total_records"=>1,
    #            "records"=>
    #             [{"order_id"=>60148891,
    #               "time_in_force"=>"day",
    #               "quantity"=>5,
    #               "transaction"=>"Buy To Open",
    #               "short_description"=>"COP Stock",
    #               "long_description"=>"COP Stock",
    #               "status"=>"Pending",
    #               "date_created_ms"=>1387521552000,
    #               "last_updated_ms"=>1387521552000,
    #               "date_created"=>"2013-12-20 00:39:12",
    #               "last_updated"=>"2013-12-20 00:39:12",
    #               "master_order_id"=>192743916,
    #               "order_type"=>"regular",
    #               "price_type"=>"limit",
    #               "price"=>70,
    #               "trigger_order"=>false,
    #               "trailing_stop_order"=>false,
    #               "complex_order"=>false,
    #               "modifiable"=>true,
    #               "root_order_id"=>192743916,
    #               "is_spread_order"=>false,
    #               "is_mutual_fund_order"=>false,
    #               "underlying_stock_symbol"=>"COP",
    #               "security_keys"=>"COP:::S",
    #               "timestamp"=>"2013-12-20 00:47:15",
    #               "has_expired_keys"=>false,
    #               "company_name"=>"ConocoPhillips",
    #               "bid"=>"69.05",
    #               "ask"=>"69.28",
    #               "high"=>"69.38",
    #               "low"=>"68.72"}]}}}}
    #
    def master_account_orders(account_id, master_order, options={})
      params = options.merge(
        'account_id'   => account_id,
        'master_order' => master_order
      )
      ez_order('master.account.orders', params)
    end
    alias_method :list_orders ,:master_account_orders


    # Returns all positions held by the specified account.
    #
    # @param [String] account
    #
    # @return [Hash]
    #
    def account_positions(account)
      params = options.merge('account' => account)
      ez_base('account.positions', params)
    end


    # Returns the historical activity of the specified account.
    #
    # @param [String] account
    # @param options [Hash]
    # @option options [Integer] 'maxPage'
    # @option options [Integer] 'page'
    # @option options [Integer] 'size'
    # @option options [Integer] 'totalCount'
    # @option options [String]  'sDate'
    # @option options [String]  'sDate'
    # @option options [String]  'symbol'
    #
    # @return [Hash]
    #
    def account_activity(account, options={})
      params = options.merge('account' => account)
      ez_base('account.activity', params)
    end

  end
end
