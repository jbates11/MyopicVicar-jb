require "rails_helper"

RSpec.describe "Factories" do
  FactoryBot.factories.map(&:name).each do |factory_name|
    it "builds #{factory_name} successfully" do
      expect(build(factory_name)).to be_valid
    end
  end
end
