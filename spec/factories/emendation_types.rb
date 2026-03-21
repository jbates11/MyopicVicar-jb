FactoryBot.define do
  factory :emendation_type do
    sequence(:name) { |n| "Emendation Type #{n}" }
    target_field { :forename }
    origin { "load_emendations rake task" }
  end
end
