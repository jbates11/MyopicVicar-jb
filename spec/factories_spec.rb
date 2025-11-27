require 'rails_helper'

RSpec.describe 'FactoryBot' do
  it 'lints all factories' do
    # Use transaction rollback for speed
    FactoryBot.lint
  end
end
