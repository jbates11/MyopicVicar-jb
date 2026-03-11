FactoryBot.define do
  factory :syndicate do
    # syndicate_code { "ABC123" }
    sequence(:syndicate_code) { |n| "Syndicate_#{n}" }
    sequence(:syndicate_coordinator) { |n| "coordinator#{n}" }
    sequence(:previous_syndicate_coordinator) { |n| "previous.coordinator#{n}" }
  end
end
