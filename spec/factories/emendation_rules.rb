FactoryBot.define do
  factory :emendation_rule do
    original { "Elia" }
    replacement { "Elias" }
    gender { nil }

    association :emendation_type, factory: :emendation_type
  end
end
