## OptionsHouse API client

OptionsHouse API client implements basic interface to OptionsHouse.com API through OptionsHouse::Manager class.


## Example

```ruby
require 'options_house_api'

# Create a new API manager:
options_house = OptionsHouse::Manager.new('<username>', '<password>')


# Start a new session (optional, the gem knows how to auto authenticate):
options_house.auth_login #=> true


# View account details:
options_house.account_info #=>
    {"EZMessage" =>
      {"data" =>
        {"account" =>
          {"currentCommissionSchedule" => "COMMISSION_VI",
           "accountTypeId"             => "0",
           "optionsWarning"            => "false",
           "nextCommissionSchedule"    => "COMMISSION_VI",
           "riskMaxDollarsPerOrder"    => "5000000",
           ... }},
       "action" => "account.info"}}


# View account finances:
options_house.account_cash(account) #=>
    {"EZMessage" =>
      {"action" => "account.cash",
       "data"   =>
        {"dayTradingBuyPower"  => "0.00",
         "cashHold"            => "0.00",
         "availableToTrade"    => "5000.00",
         "cashBalance"         => "5000.00",
         "optionBuyingPower"   => "5000.00",
         "availableToWithdraw" => "0.00",
         "stockBuyingPower"    => "10000.00"}}}


# View option series:
options_house.view_series('AAPL') #=>
    {"EZMessage"=>
      {"action" => "view.series",
       "data"   =>
        {"q" => "555.04504",
         "s" =>
          [{"k" =>
             ["AAPL:20131221:490:P",
              "AAPL:20131221:500:C",
              ... ],
           {"multiplier" => "10.0",
            "spc"        => "10",
            "isMini"     => "true",
            "content"    => "AAPL7:20160115:7950000:P",
            "isNormal"   => "false"}],
         "e" => "Jan 16"}]}}}


# Place a new order:
order = {
  'm_order_id'              => '1',
  'price_type'              => 'limit',
  'time_in_force'           => 'day',
  'price'                   => '70.00',
  'order_type'              => 'regular',
  'order_subtype'           => 'regular',
  'underlying_stock_symbol' => 'COP',
  'source'                  => 'API',
  'client_id'               => Time.now.to_i,
  'preferred_destination'   => 'BEST',
  'legs'                    => [{
    'index'         => 0,
    'side'          => 'buy',
    'security_type' => 'stock',
    'quantity'      => '5',
    'key'           => 'COP:::S',
    'multiplier'    => '1',
    'position_type' => 'opening'
  }]
}
options_house.create_order(account, order) #=>
    {"EZMessage"=>
      {"action"=>"order.create.json",
       "data"=>{"created"=>"true",
                "id"=>"192743916"}}}


# Close current session:
options_house.auth_logout #=> true
```


## Supported API methods

* account_activity
* account_cash
* account_info
* account_margin_json (or preview_order)
* account_positions
* auth_keep_alive
* auth_login
* auth_logout
* master_account_orders (or list_orders)
* order_cancel_json (or cancel_order)
* order_create_json (or create_order)
* order_modify_json (or modify_order)
* view_quote_list
* view_series


## Test coverage

There are no any tests yet...

## Author

2013, Konstantin Dzreev