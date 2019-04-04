# load the gem
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'catalog-api-client', :git => 'https://github.com/mkanoor/catalog-api-client-ruby', :branch => 'master'
end
require 'yaml'
require 'securerandom'

def process_messages(api_instance, order_id, order_item_id)
  loop do
    sleep(10)
    messages = api_instance.list_progress_messages(order_item_id).data
    messages.each do |msg|
      puts "Message : #{msg.received_at} #{msg.level} #{msg.message}"
    end
  end
end

# setup authorization
CatalogApiClient.configure do |config|
  hash  = YAML.load_file('./config.yml')
  hash.keys.each do |key|
    config.send("#{key}=".to_sym, hash[key])
  end
end

order_item_api = CatalogApiClient::OrderItemApi.new
api_instance = CatalogApiClient::PortfolioItemApi.new
portfolio_item_id = "118"

begin
  result = api_instance.list_service_plans(portfolio_item_id)
  
  service_plan = result.first
  schema = service_plan.create_json_schema
  props = schema[:required]
  service_params = props.each.with_object({}) do |name, hash|
    default = schema[:properties][name.to_sym][:default]
    if name == "NAME"
      default = "#{default}-#{SecureRandom.uuid}"
    end
    hash[name] = default
  end
  puts service_params
  order_api = CatalogApiClient::OrderApi.new
  new_order = order_api.create_order
  oitem = CatalogApiClient::OrderItem.new # OrderItem
  oitem.service_plan_ref = service_plan.id
  oitem.portfolio_item_id = portfolio_item_id
  oitem.count = 1
  oitem.service_parameters = service_params
  oitem.provider_control_parameters = {'namespace' => 'default'}
  result = order_api.add_to_order(new_order.id, oitem)
  result = order_api.submit_order(new_order.id)
  order_item_id = order_api.list_order_items(new_order.id).data[0].id
  process_messages(order_item_api, new_order.id, order_item_id)
rescue CatalogApiClient::ApiError => e
  puts "Exception when calling UsersApi->catalog_items: #{e}"
end
