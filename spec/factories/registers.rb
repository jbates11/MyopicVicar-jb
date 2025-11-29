FactoryBot.define do
  factory :register do
    register_name { "Baptism Register" }
    register_type { "baptism" }
    status        { "active" }
    association :church
  end
end
