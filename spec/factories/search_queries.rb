FactoryBot.define do
  factory :search_query do
    first_name { "John" }
    last_name  { "Doe" }

    # Required by your model validations
    chapman_codes   { [] }           # or whatever your model expects
    record_type   { "bu" }        # example valid type
    start_year    { 1800 }
    end_year      { 1900 }

    # Optional fields commonly used in the UCF pipeline
    ucf_filtered_count { nil }
    runtime_ucf        { nil }

    # Build the embedded document automatically
    after(:build) do |query|
      query.build_search_result if query.search_result.nil?
    end
  end
end
