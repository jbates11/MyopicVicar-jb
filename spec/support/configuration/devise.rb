RSpec.configure do |config|
  # For controller specs
  config.include Devise::Test::ControllerHelpers, type: :controller
  # For request/system specs
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Warden::Test::Helpers
end
