require 'rails_helper'

RSpec.describe Freereg1CsvFile, type: :model do
  describe 'UCF list synchronization during CSV upload' do
    let(:place) { create(:place, ucf_list: {}) }
    let(:file) { create(:freereg1_csv_file, place_name: place.place_name) }

    describe 'file-level ucf_list type validation' do
      context 'when file is created' do
        it 'ucf_list is an Array' do
          expect(file.ucf_list).to be_a(Array)
        end
      end

      context 'when entries with UCF are added' do
        it 'maintains Array type for file.ucf_list' do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'Jo*n', last_name: 'Smith')
          record.save

          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to be_a(Array)
        end
      end
    end

    describe 'place-level ucf_list structure (Hash with Array values)' do
      context 'when file has UCF entries' do
        it 'place.ucf_list uses file_id.to_s as key' do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR001', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'Ma*y', last_name: 'Jones')
          record.save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list).to have_key(file.id.to_s)
        end

        it 'place.ucf_list values are Arrays, never Hashes' do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR002', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'To*m', last_name: 'Brown')
          record.save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          value = fresh_place.ucf_list[file.id.to_s]
          expect(value).to be_a(Array)
          expect(value).not_to be_a(Hash)
        end
      end
    end

    describe 'uploading CSV with no UCF entries' do
      context 'when all entries contain no wildcards' do
        before do
          create(:freereg1_csv_entry, freereg1_csv_file: file)
          create(:freereg1_csv_entry, freereg1_csv_file: file)
        end

        it 'file.ucf_list remains empty' do
          file.freereg1_csv_entries.each do |entry|
            next unless entry.search_record
            entry.search_record.search_names << build(:search_name, first_name: 'John', last_name: 'Smith')
            entry.search_record.save
          end

          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to be_empty
        end

        it 'place.ucf_list creates empty entry for file (no UCF records)' do
          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to eq([])
        end

        it 'file.ucf_list remains empty when no UCF found' do
          place.update_ucf_list(file)

          expect(file.ucf_list).to be_empty
        end
      end
    end

    describe 'uploading CSV with UCF entries' do
      context 'when entries contain wildcard character *' do
        before do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR001', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'Jo*n', last_name: 'Smith')
          record.save
        end

        it 'adds entry to file.ucf_list' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to include('SR001')
        end

        it 'creates entry in place.ucf_list' do
          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to include('SR001')
        end

        it 'place.ucf_list value is Array' do
          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to be_a(Array)
        end
      end

      context 'when entries contain wildcard character _' do
        before do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR002', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'Th_mas', last_name: 'Brown')
          record.save
        end

        it 'identifies as UCF' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to include('SR002')
        end
      end

      context 'when entries contain wildcard character ?' do
        before do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR003', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'Ma?y', last_name: 'Jones')
          record.save
        end

        it 'identifies as UCF' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to include('SR003')
        end
      end

      context 'when entries contain wildcard character {' do
        before do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR004', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'Al{xander', last_name: 'White')
          record.save
        end

        it 'identifies as UCF' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to include('SR004')
        end
      end

      context 'when entries contain wildcard character }' do
        before do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR005', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'Patr}cia', last_name: 'Green')
          record.save
        end

        it 'identifies as UCF' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to include('SR005')
        end
      end
    end

    describe 'synchronizing file and place UCF lists' do
      context 'when file has multiple UCF entries' do
        before do
          entry1 = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record1 = create(:search_record, id: 'SR001', freereg1_csv_entry: entry1, place: place)
          record1.search_names << build(:search_name, first_name: 'Jo*n', last_name: 'Smith')
          record1.save

          entry2 = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record2 = create(:search_record, id: 'SR002', freereg1_csv_entry: entry2, place: place)
          record2.search_names << build(:search_name, first_name: 'Ma_y', last_name: 'Jones')
          record2.save
        end

        it 'adds all UCF record IDs to file.ucf_list' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to contain_exactly('SR001', 'SR002')
        end

        it 'adds all UCF record IDs to place.ucf_list[file_id]' do
          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly('SR001', 'SR002')
        end
      end

      context 'when file already has UCF list and new entries are added' do
        it 'appends new record IDs to existing list' do
          entry1 = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record1 = create(:search_record, id: 'SR001', freereg1_csv_entry: entry1, place: place)
          record1.search_names << build(:search_name, first_name: 'Jo*n', last_name: 'Smith')
          record1.save

          place.update_ucf_list(file)

          entry2 = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record2 = create(:search_record, id: 'SR002', freereg1_csv_entry: entry2, place: place)
          record2.search_names << build(:search_name, first_name: 'Ma_y', last_name: 'Jones')
          record2.save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly('SR001', 'SR002')
        end
      end

      context 'when multiple files reference same place' do
        let(:file2) { create(:freereg1_csv_file, place_name: place.place_name) }

        before do
          entry1 = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record1 = create(:search_record, id: 'FILE1_SR001', freereg1_csv_entry: entry1, place: place)
          record1.search_names << build(:search_name, first_name: 'Jo*n', last_name: 'Smith')
          record1.save

          entry2 = create(:freereg1_csv_entry, freereg1_csv_file: file2)
          record2 = create(:search_record, id: 'FILE2_SR001', freereg1_csv_entry: entry2, place: place)
          record2.search_names << build(:search_name, first_name: 'Ma_y', last_name: 'Jones')
          record2.save
        end

        it 'maintains separate UCF lists for each file in place' do
          place.update_ucf_list(file)
          place.update_ucf_list(file2)

          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly('FILE1_SR001')
          expect(fresh_place.ucf_list[file2.id.to_s]).to contain_exactly('FILE2_SR001')
        end

        it 'place.ucf_list has one entry per file' do
          place.update_ucf_list(file)
          place.update_ucf_list(file2)

          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list.keys).to contain_exactly(file.id.to_s, file2.id.to_s)
        end
      end
    end

    describe 'handling entries with and without search records' do
      context 'when entry has no search record (not yet processed)' do
        before do
          create(:freereg1_csv_entry, freereg1_csv_file: file)
        end

        it 'file.search_record_ids_with_wildcard_ucf returns empty array' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to be_empty
        end

        it 'place.ucf_list creates empty entry for file (no search records)' do
          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to eq([])
        end
      end

      context 'when some entries have search records and some do not' do
        before do
          entry1 = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record1 = create(:search_record, id: 'SR001', freereg1_csv_entry: entry1, place: place)
          record1.search_names << build(:search_name, first_name: 'Jo*n', last_name: 'Smith')
          record1.save

          create(:freereg1_csv_entry, freereg1_csv_file: file)
        end

        it 'includes only UCF entries from search records' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to contain_exactly('SR001')
        end
      end
    end

    describe 'FactoryBot integration for UCF testing' do
      context 'when using Place factory with_ucf_records trait' do
        let(:place_with_ucf) { create(:place, :with_ucf_records, record_groups_count: 2) }

        it 'creates place with ucf_list Hash' do
          expect(place_with_ucf.ucf_list).to be_a(Hash)
        end

        it 'ucf_list values are Arrays' do
          place_with_ucf.ucf_list.each_value do |group|
            expect(group).to be_a(Array)
          end
        end

        it 'ucf_list contains ObjectIds' do
          place_with_ucf.ucf_list.each_value do |group|
            group.each do |record_id|
              expect(record_id).to be_a(BSON::ObjectId)
            end
          end
        end
      end
    end

    describe 'place counters tracking UCF updates' do
      let(:file_with_entries) do
        f = create(:freereg1_csv_file, place_name: place.place_name)
        3.times do |i|
          entry = create(:freereg1_csv_entry, freereg1_csv_file: f)
          if i.even?
            record = create(:search_record, id: "SR#{i}", freereg1_csv_entry: entry, place: place)
            record.search_names << build(:search_name, first_name: "Na*e#{i}", last_name: 'Test')
            record.save
          end
        end
        f
      end

      it 'place.ucf_list_record_count reflects total records' do
        place.update_ucf_list(file_with_entries)
        fresh_place = Place.find(place.id)

        expected_count = place.ucf_list[file_with_entries.id.to_s]&.count || 0
        expect(fresh_place.ucf_list_record_count).to eq(expected_count)
      end

      it 'place.ucf_list_file_count reflects file count' do
        place.update_ucf_list(file_with_entries)
        fresh_place = Place.find(place.id)

        expected_count = fresh_place.ucf_list.keys.count
        expect(fresh_place.ucf_list_file_count).to eq(expected_count)
      end

      it 'place.ucf_list_updated_at is set' do
        place.update_ucf_list(file_with_entries)
        fresh_place = Place.find(place.id)

        expect(fresh_place.ucf_list_updated_at).to be_a(DateTime)
      end
    end

    describe 'mixed wildcard scenarios' do
      context 'when single name has multiple wildcard characters' do
        before do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR001', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'J*h_?o{n', last_name: 'Smith')
          record.save
        end

        it 'identifies as UCF' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to include('SR001')
        end
      end

      context 'when last_name has UCF but first_name does not' do
        before do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR002', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'John', last_name: 'Sm*th')
          record.save
        end

        it 'identifies as UCF' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to include('SR002')
        end
      end

      context 'when first_name has UCF but last_name does not' do
        before do
          entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
          record = create(:search_record, id: 'SR003', freereg1_csv_entry: entry, place: place)
          record.search_names << build(:search_name, first_name: 'Jo_n', last_name: 'Smith')
          record.save
        end

        it 'identifies as UCF' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to include('SR003')
        end
      end
    end
  end
end
