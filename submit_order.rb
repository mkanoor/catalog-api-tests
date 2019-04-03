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

api_instance = CatalogApiClient::AdminsApi.new
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
  service_params['GITHUB_WEBHOOK_SECRET'] = '787878abc'
  service_params["GENERIC_WEBHOOK_SECRET"] ="12345678"
  puts service_params
  new_order = api_instance.create_order
  oitem = CatalogApiClient::OrderItem.new # OrderItem
  oitem.service_plan_ref = service_plan.id
  oitem.portfolio_item_id = portfolio_item_id
  oitem.count = 1
  oitem.service_parameters = service_params
  oitem.provider_control_parameters = {'namespace' => 'default'}
  result = api_instance.add_to_order(new_order.id, oitem)
  result = api_instance.submit_order(new_order.id)
  order_item_id = api_instance.list_order_items(new_order.id).data[0].id
  process_messages(api_instance, new_order.id, order_item_id)
rescue CatalogApiClient::ApiError => e
  puts "Exception when calling UsersApi->catalog_items: #{e}"
end
