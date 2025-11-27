FactoryBot.define do
  factory :church do
    sequence(:church_name) { |n| "Church#{n}" }
    association :place
  end
end
