FactoryBot.define do
  factory :search_result do
    records        { {} }
    viewed_records { [] }
    ucf_records    { [] }

    # Prevent standalone persistence
    initialize_with { new(attributes) }
  end
end
