require 'rails_helper'

RSpec.describe 'FactoryBot' do
  it 'lints all factories' do
    # Ensure DB state is isolated while linting factories
    DatabaseCleaner[:mongoid].cleaning do
      FactoryBot.lint
    end
  end
end