FactoryBot.define do
  factory :search_result do
    skip_create  # 
    to_create { |_instance| }  # absolutely prevent persistence
    # Prevent standalone persistence
    initialize_with { new(attributes) }

    records        { {} }
    viewed_records { [] }
    ucf_records    { [] }

  end
end
