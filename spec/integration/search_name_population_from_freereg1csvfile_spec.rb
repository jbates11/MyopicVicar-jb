require 'rails_helper'
require Rails.root.join('lib/freereg1_translator')

RSpec.describe 'SearchName population from Freereg1CsvFile' do
  let(:trace_id) { SecureRandom.uuid }
  let(:timestamp) { Time.now.utc.iso8601 }

  before do
    Rails.logger.info("[#{timestamp}] TRACE=#{trace_id} Starting SearchName tests")
  end

  after do
    Rails.logger.info("[#{timestamp}] TRACE=#{trace_id} Completed SearchName tests")
  end

  # ============================================================================
  # BAPTISM RECORD TESTS (record_type = 'ba')
  # ============================================================================

  describe 'Baptism Records (record_type: ba)' do
    let(:file) { create(:freereg1_csv_file, record_type: 'ba') }

    describe 'Primary person with all fields' do
      let(:entry) do
        create(:freereg1_csv_entry,
               freereg1_csv_file: file,
               record_type: 'ba',
               person_forename: 'John',
               person_surname: 'Smith',
               father_forename: 'Thomas',
               father_surname: 'Smith',
               mother_forename: 'Mary',
               mother_surname: 'Jones')
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end
      
      it 'creates primary SearchName with person_forename and person_surname' do
        search_record.save! # must make record persistent for count method to work
        
        # ap search_record.search_names
        # puts "Count:#{search_record.search_names.count.ai}"

        expect(search_record.search_names.count).to be >= 1
        primary = search_record.search_names.detect { |n| n.role == 'ba' && n.type == SearchRecord::PersonType::PRIMARY }

        expect(primary).to be_present
        expect(primary.first_name).to eq('john') # downcase by transform
        expect(primary.last_name).to eq('smith')
      end

      it 'creates father SearchName with father_forename and father_surname' do
        father = search_record.search_names.detect { |n| n.role == 'f' }

        expect(father).to be_present
        expect(father.first_name).to eq('thomas')
        expect(father.last_name).to eq('smith')
        expect(father.type).to eq(SearchRecord::PersonType::FAMILY)
        expect(father.gender).to eq('m')
      end

      it 'creates mother SearchName with mother_forename and mother_surname' do
        mother = search_record.search_names.detect { |n| n.role == 'm' }

        expect(mother).to be_present
        expect(mother.first_name).to eq('mary')
        expect(mother.last_name).to eq('jones')
        expect(mother.type).to eq(SearchRecord::PersonType::FAMILY)
        expect(mother.gender).to eq('f')
      end

      it 'sets correct origin for all names' do
        search_record.search_names.each do |name|
          expect(name.origin).to eq(SearchRecord::Source::TRANSCRIPT)
        end
      end
    end

    describe 'Primary person without surname, with father_surname' do
      let(:entry) do
        create(:freereg1_csv_entry,
               :baptism_father_only,
               freereg1_csv_file: file,
               person_forename: 'John',
               person_surname: nil,
               father_forename: 'Thomas',
               father_surname: 'Smith',
               mother_forename: 'Mary',
               mother_surname: 'Jones')
              #  mother_surname: nil)
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end

      it 'uses father_surname as primary last_name' do
        primary = search_record.search_names.detect { |n| n.role == 'ba' && n.type == SearchRecord::PersonType::PRIMARY }

        expect(primary).to be_present
        expect(primary.first_name).to eq('john')
        expect(primary.last_name).to eq('smith') # fallback to father
      end

      it 'does not create duplicate surnames' do
        surnames = search_record.search_names.map(&:last_name).uniq
        # ap surnames

        expect(surnames).to contain_exactly('smith', 'jones')
      end
    end

    describe 'Primary person without surname, with mother_surname' do
      let(:entry) do
        create(:freereg1_csv_entry,
               :baptism_mother_only,
               freereg1_csv_file: file,
               person_forename: 'John',
               person_surname: nil,
               father_forename: 'Thomas',
               father_surname: nil,
               mother_forename: 'Mary',
               mother_surname: 'Jones')
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end

      it 'uses mother_surname as primary last_name' do
        primary = search_record.search_names.detect { |n| n.role == 'ba' && n.type == SearchRecord::PersonType::PRIMARY }

        expect(primary).to be_present
        expect(primary.first_name).to eq('john')
        expect(primary.last_name).to eq('jones')
      end
    end

    describe 'Primary person without surname, with both parent surnames' do
      let(:entry) do
        create(:freereg1_csv_entry,
               :baptism_both_parents,
               freereg1_csv_file: file,
               person_forename: 'John',
               person_surname: nil,
               father_surname: 'Smith',
               mother_surname: 'Jones')
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end

      it 'creates two primary SearchNames, one for each surname' do
        primaries = search_record.search_names.select { |n| n.role == 'ba' && n.type == SearchRecord::PersonType::PRIMARY }

        expect(primaries.count).to be >= 2
        surnames = primaries.map(&:last_name)
        expect(surnames).to include('smith', 'jones')
      end

      it 'both primary names have same first_name' do
        primaries = search_record.search_names.select { |n| n.role == 'ba' && n.type == SearchRecord::PersonType::PRIMARY }
        first_names = primaries.map(&:first_name)

        expect(first_names).to all(eq('john'))
      end
    end

    describe 'Witnesses in baptism' do
      let(:entry) do
        create(:freereg1_csv_entry,
               :baptism_with_witnesses,
               freereg1_csv_file: file,
               person_forename: 'John',
               person_surname: 'Smith')
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end

      it 'creates SearchName for each witness' do
        witnesses = search_record.search_names.select { |n| n.role == 'wt' }

        expect(witnesses.count).to eq(2)
      end

      it 'sets witness type correctly' do
        witnesses = search_record.search_names.select { |n| n.role == 'wt' }

        witnesses.each do |witness|
          expect(witness.type).to eq(SearchRecord::PersonType::WITNESS)
        end
      end

      it 'populates witness first_name and last_name' do
        witness_jane = search_record.search_names.detect { |n| n.role == 'wt' && n.first_name == 'jane' }
        witness_robert = search_record.search_names.detect { |n| n.role == 'wt' && n.first_name == 'robert' }

        expect(witness_jane.last_name).to eq('brown')
        expect(witness_robert.last_name).to eq('green')
      end
    end
  end

  # ============================================================================
  # BURIAL RECORD TESTS (record_type = 'bu')
  # ============================================================================

  describe 'Burial Records (record_type: bu)' do
    let(:file) { create(:freereg1_csv_file, record_type: 'bu') }

    describe 'Primary person with burial_person_surname' do
      let(:entry) do
        create(:freereg1_csv_entry,
               :burial,
               freereg1_csv_file: file,
               burial_person_forename: 'William',
               burial_person_surname: 'Johnson',
               relative_surname: 'Johnson')
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end

      it 'creates primary SearchName with burial_person_forename and burial_person_surname' do
        primary = search_record.search_names.detect { |n| n.role == 'bu' && n.type == SearchRecord::PersonType::PRIMARY }

        expect(primary).to be_present
        expect(primary.first_name).to eq('william')
        expect(primary.last_name).to eq('johnson')
      end
    end

    describe 'Primary person without surname, with relative_surname' do
      let(:entry) do
        create(:freereg1_csv_entry,
               :burial_no_surname,
               freereg1_csv_file: file)
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end

      it 'uses relative_surname as fallback' do
        primary = search_record.search_names.detect { |n| n.role == 'bu' && n.type == SearchRecord::PersonType::PRIMARY }

        expect(primary).to be_present
        expect(primary.last_name).to eq('johnson')
      end
    end

    describe 'Female and male relatives' do
      let(:entry) do
        create(:freereg1_csv_entry,
               :burial,
               freereg1_csv_file: file,
               burial_person_forename: 'William',
               burial_person_surname: 'Johnson',
               female_relative_forename: 'Sarah',
               female_relative_surname: 'Smith',
               male_relative_forename: 'George',
               relative_surname: 'Johnson')
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end

      it 'creates female_relative SearchName' do
        female = search_record.search_names.detect { |n| n.role == 'fr' }

        expect(female).to be_present
        expect(female.first_name).to eq('sarah')
        expect(female.last_name).to eq('smith')
        expect(female.type).to eq(SearchRecord::PersonType::FAMILY)
        expect(female.gender).to eq('f')
      end

      it 'creates male_relative SearchName' do
        male = search_record.search_names.detect { |n| n.role == 'mr' }

        expect(male).to be_present
        expect(male.first_name).to eq('george')
        expect(male.last_name).to eq('johnson')
        expect(male.type).to eq(SearchRecord::PersonType::FAMILY)
        expect(male.gender).to eq('m')
      end
    end
  end

  # ============================================================================
  # MARRIAGE RECORD TESTS (record_type = 'ma')
  # ============================================================================

  describe 'Marriage Records (record_type: ma)' do
    let(:file) { create(:freereg1_csv_file, record_type: 'ma') }

    describe 'Bride and Groom as primary' do
      let(:entry) do
        create(:freereg1_csv_entry,
               :marriage,
               freereg1_csv_file: file,
               bride_forename: 'Elizabeth',
               bride_surname: 'Brown',
               groom_forename: 'John',
               groom_surname: 'Smith')
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end

      it 'creates bride SearchName as primary' do
        bride = search_record.search_names.detect { |n| n.role == 'b' }

        expect(bride).to be_present
        expect(bride.first_name).to eq('elizabeth')
        expect(bride.last_name).to eq('brown')
        expect(bride.type).to eq(SearchRecord::PersonType::PRIMARY)
        expect(bride.gender).to eq('f')
      end

      it 'creates groom SearchName as primary' do
        groom = search_record.search_names.detect { |n| n.role == 'g' }

        expect(groom).to be_present
        expect(groom.first_name).to eq('john')
        expect(groom.last_name).to eq('smith')
        expect(groom.type).to eq(SearchRecord::PersonType::PRIMARY)
        expect(groom.gender).to eq('m')
      end
    end

    describe 'Parents in marriage' do
      let(:entry) do
        create(:freereg1_csv_entry,
               :marriage,
               freereg1_csv_file: file,
               bride_forename: 'Elizabeth',
               bride_surname: 'Brown',
               groom_forename: 'John',
               groom_surname: 'Smith',
               bride_father_forename: 'Robert',
               bride_father_surname: 'Brown',
               groom_father_forename: 'Thomas',
               groom_father_surname: 'Smith',
               bride_mother_forename: 'Anne',
               bride_mother_surname: 'White',
               groom_mother_forename: 'Jane',
               groom_mother_surname: 'Davis')
      end

      let(:search_record) do
        search_params = Freereg1Translator.translate(file, entry)
        record = SearchRecord.new(search_params)
        record.freereg1_csv_entry = entry
        record.transform
        record
      end

      it 'creates bride_father SearchName' do
        bf = search_record.search_names.detect { |n| n.role == 'bf' }

        expect(bf).to be_present
        expect(bf.first_name).to eq('robert')
        expect(bf.last_name).to eq('brown')
        expect(bf.type).to eq(SearchRecord::PersonType::FAMILY)
      end

      it 'creates groom_father SearchName' do
        gf = search_record.search_names.detect { |n| n.role == 'gf' }

        expect(gf).to be_present
        expect(gf.first_name).to eq('thomas')
        expect(gf.last_name).to eq('smith')
        expect(gf.type).to eq(SearchRecord::PersonType::FAMILY)
      end

      it 'creates bride_mother SearchName' do
        bm = search_record.search_names.detect { |n| n.role == 'bm' }

        expect(bm).to be_present
        expect(bm.first_name).to eq('anne')
        expect(bm.last_name).to eq('white')
        expect(bm.type).to eq(SearchRecord::PersonType::FAMILY)
        expect(bm.gender).to eq('f')
      end

      it 'creates groom_mother SearchName' do
        gm = search_record.search_names.detect { |n| n.role == 'gm' }

        expect(gm).to be_present
        expect(gm.first_name).to eq('jane')
        expect(gm.last_name).to eq('davis')
        expect(gm.type).to eq(SearchRecord::PersonType::FAMILY)
        expect(gm.gender).to eq('f')
      end
    end
  end

  # ============================================================================
  # SYMBOL CLEANING TESTS
  # ============================================================================

  describe 'Symbol cleaning in SearchNames' do
    let(:file) { create(:freereg1_csv_file, record_type: 'ba') }

    let(:entry) do
      create(:freereg1_csv_entry,
             freereg1_csv_file: file,
             person_forename: "John's",
             person_surname: "Smith-Jones",
             father_forename: 'Thomas.',
             father_surname: 'O\'Brien')
    end

    let(:search_record) do
      search_params = Freereg1Translator.translate(file, entry)
      record = SearchRecord.new(search_params)
      record.freereg1_csv_entry = entry
      record.transform
      record
    end

    it 'creates both raw and cleaned name variants' do
      # Should have raw + cleaned versions
      primary_names = search_record.search_names.select { |n| n.role == 'ba' && n.type == SearchRecord::PersonType::PRIMARY }
      # ap primary_names
      expect(primary_names.count).to be >= 2
    end

    it 'cleans symbols from names' do
      cleaned = search_record.search_names.detect { |n| n.first_name == 'johns' && n.origin == SearchRecord::Source::TRANSCRIPT }

      expect(cleaned).to be_present
    end

    it 'includes SYMBOLS_TO_CLEAN constant' do
      expect(SearchRecord::SYMBOLS_TO_CLEAN).to include('.', ':', ';', "'", '-', '`', '"')
    end
  end

  # ============================================================================
  # DOWNCASE TRANSFORMATION TESTS
  # ============================================================================

  describe 'Downcase transformation' do
    let(:file) { create(:freereg1_csv_file, record_type: 'ba') }

    let(:entry) do
      create(:freereg1_csv_entry,
             freereg1_csv_file: file,
             person_forename: 'JOHN',
             person_surname: 'SMITH',
             father_forename: 'THOMAS',
             father_surname: 'SMITH')
    end

    let(:search_record) do
      search_params = Freereg1Translator.translate(file, entry)
      record = SearchRecord.new(search_params)
      record.freereg1_csv_entry = entry
      record.transform
      record
    end

    it 'downcases all search_names' do
      search_record.search_names.each do |name|
        expect(name.first_name).to eq(name.first_name.downcase) if name.first_name.present?
        expect(name.last_name).to eq(name.last_name.downcase) if name.last_name.present?
      end
    end
  end

  # ============================================================================
  # GENDER ASSIGNMENT TESTS
  # ============================================================================

  describe 'Gender assignment in SearchNames' do
    let(:file) { create(:freereg1_csv_file, record_type: 'ba') }

    let(:entry) do
      create(:freereg1_csv_entry,
             freereg1_csv_file: file,
             person_forename: 'John',
             person_surname: 'Smith',
             person_sex: 'm',
             father_forename: 'Thomas',
             father_surname: 'Smith',
             mother_forename: 'Mary',
             mother_surname: 'Jones')
    end

    let(:search_record) do
      search_params = Freereg1Translator.translate(file, entry)
      record = SearchRecord.new(search_params)
      record.freereg1_csv_entry = entry
      record.transform
      record
    end

    it 'assigns male gender to father' do
      father = search_record.search_names.detect { |n| n.role == 'f' }
      expect(father.gender).to eq('m')
    end

    it 'assigns female gender to mother' do
      mother = search_record.search_names.detect { |n| n.role == 'm' }
      expect(mother.gender).to eq('f')
    end

    it 'assigns primary gender from person_sex if available' do
      primary = search_record.search_names.detect { |n| n.role == 'ba' && n.type == SearchRecord::PersonType::PRIMARY }
      expect(primary.gender).to eq('m')
    end
  end

  # ============================================================================
  # INTEGRATION TESTS
  # ============================================================================

  describe 'Full integration: File → Entry → SearchRecord → SearchNames' do
    let(:place) { create(:place, place_name: 'Guildford', chapman_code: 'ESS') }
    let(:church) { create(:church, place: place, church_name: 'St. Mary') }
    let(:register) { create(:register, church: church, register_type: 'Baptism') }
    let(:file) { create(:freereg1_csv_file, register: register, record_type: 'ba') }

    let(:entry) do
      create(:freereg1_csv_entry,
             :baptism_with_witnesses,
             freereg1_csv_file: file,
             person_forename: 'John',
             person_surname: 'Smith',
             father_forename: 'Thomas',
             father_surname: 'Smith',
             mother_forename: 'Mary',
             mother_surname: 'Jones')
    end

    it 'creates complete record chain with all SearchNames' do
      search_params = Freereg1Translator.translate(file, entry)
      record = SearchRecord.new(search_params)
      record.freereg1_csv_entry = entry
      record.place = place
      record.transform
      record.save

      retrieved = SearchRecord.find(record.id)

      # ap retrieved

      expect(retrieved.search_names.count).to be >= 5 # primary + father + mother + 2 witnesses
      expect(retrieved.record_type).to eq('ba')
      expect(retrieved.chapman_code).to eq('SUR')
    end
  end
end
