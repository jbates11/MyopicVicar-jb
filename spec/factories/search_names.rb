FactoryBot.define do
  factory :search_name do
    first_name { 'John' }
    last_name { 'Smith' }
    origin { SearchRecord::Source::TRANSCRIPT }
    role { 'ba' }
    gender { 'm' }
    type { SearchRecord::PersonType::PRIMARY }

    # Prevent FactoryBot from trying to persist this standalone (embedded document)
    to_create { |instance| instance }

    trait :primary do
      type { SearchRecord::PersonType::PRIMARY }
    end

    trait :family do
      type { SearchRecord::PersonType::FAMILY }
    end

    trait :witness do
      type { SearchRecord::PersonType::WITNESS }
    end

    # Baptism-specific traits
    trait :baptism_primary do
      role { 'ba' }
      type { SearchRecord::PersonType::PRIMARY }
      gender { 'm' }
    end

    trait :baptism_father do
      role { 'f' }
      type { SearchRecord::PersonType::FAMILY }
      gender { 'm' }
      first_name { 'Thomas' }
      last_name { 'Smith' }
    end

    trait :baptism_mother do
      role { 'm' }
      type { SearchRecord::PersonType::FAMILY }
      gender { 'f' }
      first_name { 'Mary' }
      last_name { 'Jones' }
    end

    trait :baptism_witness do
      role { 'wt' }
      type { SearchRecord::PersonType::WITNESS }
      first_name { 'Jane' }
      last_name { 'Brown' }
    end

    # Burial-specific traits
    trait :burial_primary do
      role { 'bu' }
      type { SearchRecord::PersonType::PRIMARY }
      first_name { 'William' }
      last_name { 'Johnson' }
    end

    trait :burial_female_relative do
      role { 'fr' }
      type { SearchRecord::PersonType::FAMILY }
      gender { 'f' }
      first_name { 'Sarah' }
      last_name { 'Smith' }
    end

    trait :burial_male_relative do
      role { 'mr' }
      type { SearchRecord::PersonType::FAMILY }
      gender { 'm' }
      first_name { 'George' }
      last_name { 'Johnson' }
    end

    # Marriage-specific traits
    trait :marriage_bride do
      role { 'b' }
      type { SearchRecord::PersonType::PRIMARY }
      gender { 'f' }
      first_name { 'Elizabeth' }
      last_name { 'Brown' }
    end

    trait :marriage_groom do
      role { 'g' }
      type { SearchRecord::PersonType::PRIMARY }
      gender { 'm' }
      first_name { 'John' }
      last_name { 'Smith' }
    end

    trait :marriage_bride_father do
      role { 'bf' }
      type { SearchRecord::PersonType::FAMILY }
      gender { 'm' }
      first_name { 'Robert' }
      last_name { 'Brown' }
    end

    trait :marriage_groom_father do
      role { 'gf' }
      type { SearchRecord::PersonType::FAMILY }
      gender { 'm' }
      first_name { 'Thomas' }
      last_name { 'Smith' }
    end

    trait :marriage_bride_mother do
      role { 'bm' }
      type { SearchRecord::PersonType::FAMILY }
      gender { 'f' }
      first_name { 'Anne' }
      last_name { 'White' }
    end

    trait :marriage_groom_mother do
      role { 'gm' }
      type { SearchRecord::PersonType::FAMILY }
      gender { 'f' }
      first_name { 'Jane' }
      last_name { 'Davis' }
    end

    # Symbol-related traits
    trait :with_apostrophe do
      first_name { "John's" }
      last_name { "O'Brien" }
    end

    trait :with_hyphen do
      first_name { 'Mary-Anne' }
      last_name { 'Smith-Jones' }
    end

    trait :with_period do
      first_name { 'Jno.' }
      last_name { 'Smth.' }
    end

    trait :cleaned do
      origin { SearchRecord::Source::TRANSCRIPT }
    end
  end
end
