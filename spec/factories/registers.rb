FactoryBot.define do
  factory :register do
    sequence(:register_name) { |n| "Register#{n}" }
    register_type { "baptism" }
    association :church
  end
end
