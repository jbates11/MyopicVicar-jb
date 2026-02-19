require 'rails_helper'

RSpec.describe Freereg1CsvFile, type: :model do
  describe 'UCF list synchronization during CSV file replacement' do
    let(:place) { create(:place, ucf_list: {}) }
    let(:file) do
      create(:freereg1_csv_file,
             place_name: place.place_name)
    end

    def create_entry_with_ucf(file, id_suffix, first_name_pattern)
      entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
      record = create(:search_record,
                      id: "SR_#{id_suffix}",
                      freereg1_csv_entry: entry,
                      place: place)
      record.search_names << build(:search_name,
                                    first_name: first_name_pattern,
                                    last_name: 'Test')
      record.save
      entry
    end

    def create_entry_without_ucf(file, id_suffix, first_name)
      entry = create(:freereg1_csv_entry, freereg1_csv_file: file)
      record = create(:search_record,
                      id: "SR_#{id_suffix}",
                      freereg1_csv_entry: entry,
                      place: place)
      record.search_names << build(:search_name,
                                    first_name: first_name,
                                    last_name: 'Test')
      record.save
      entry
    end

    describe 'initial upload with mixed entries' do
      context 'when uploading CSV with some UCF and some non-UCF entries' do
        before do
          create_entry_with_ucf(file, 'INITIAL_UCF_1', 'Jo*n')
          create_entry_without_ucf(file, 'INITIAL_NO_UCF_1', 'Alice')
          create_entry_with_ucf(file, 'INITIAL_UCF_2', 'Ma_y')
          create_entry_without_ucf(file, 'INITIAL_NO_UCF_2', 'Bob')

          place.update_ucf_list(file)
        end

        it 'adds only UCF entries to file.ucf_list' do
          ucf_ids = file.search_record_ids_with_wildcard_ucf
          expect(ucf_ids).to contain_exactly('SR_INITIAL_UCF_1', 'SR_INITIAL_UCF_2')
        end

        it 'adds only UCF entries to place.ucf_list[file_id]' do
          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly(
            'SR_INITIAL_UCF_1',
            'SR_INITIAL_UCF_2'
          )
        end

        it 'does not add non-UCF entries to lists' do
          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s]).not_to include(
            'SR_INITIAL_NO_UCF_1',
            'SR_INITIAL_NO_UCF_2'
          )
        end
      end
    end

    describe 'replace with new UCF entries added' do
      context 'when replacing file with original entries plus new UCF entries' do
        before do
          original_ucf_entry = create_entry_with_ucf(file, 'ORIGINAL_UCF', 'To*m')
          original_no_ucf_entry = create_entry_without_ucf(file, 'ORIGINAL_NO_UCF', 'Charlie')

          place.update_ucf_list(file)

          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly('SR_ORIGINAL_UCF')
        end

        it 'adds new UCF entries to file.ucf_list' do
          create_entry_with_ucf(file, 'NEW_UCF_1', 'Ja*es')
          create_entry_with_ucf(file, 'NEW_UCF_2', 'Mar?a')

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly(
            'SR_ORIGINAL_UCF',
            'SR_NEW_UCF_1',
            'SR_NEW_UCF_2'
          )
        end

        it 'maintains existing UCF entries in list' do
          create_entry_with_ucf(file, 'NEW_UCF', 'Su*an')
          place.update_ucf_list(file)

          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s]).to include('SR_ORIGINAL_UCF')
        end

        it 'keeps non-UCF entries out of lists' do
          create_entry_with_ucf(file, 'NEW_UCF', 'Pat_ick')
          create_entry_without_ucf(file, 'NEW_NO_UCF', 'Diana')

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).not_to include('SR_NEW_NO_UCF')
        end
      end
    end

    describe 'replace with existing non-UCF entries edited' do
      context 'when non-UCF entry is edited to contain UCF' do
        before do
          @original_entry = create_entry_without_ucf(file, 'ENTRY_1', 'Original')
          place.update_ucf_list(file)

          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s]).to be_empty
        end

        it 'adds entry to UCF lists after edit' do
          search_record = SearchRecord.find('SR_ENTRY_1')
          search_record.search_names.first.update(first_name: 'Edit*d')
          search_record.save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to include('SR_ENTRY_1')
        end
      end

      context 'when non-UCF entry remains non-UCF after edit' do
        before do
          @original_entry = create_entry_without_ucf(file, 'ENTRY_2', 'Original')
          place.update_ucf_list(file)
        end

        it 'keeps entry out of UCF lists' do
          search_record = SearchRecord.find('SR_ENTRY_2')
          search_record.search_names.first.update(first_name: 'Edited')
          search_record.save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).not_to include('SR_ENTRY_2')
        end
      end
    end

    describe 'replace with existing UCF entries edited' do
      context 'when UCF entry is edited to remove wildcard' do
        before do
          @original_entry = create_entry_with_ucf(file, 'UCF_ENTRY_1', 'Ori*nal')
          place.update_ucf_list(file)

          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s]).to include('SR_UCF_ENTRY_1')
        end

        it 'removes entry from UCF lists after wildcard removal' do
          search_record = SearchRecord.find('SR_UCF_ENTRY_1')
          search_record.search_names.first.update(first_name: 'Original')
          search_record.save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).not_to include('SR_UCF_ENTRY_1')
        end

        it 'clears entry from file.ucf_list' do
          search_record = SearchRecord.find('SR_UCF_ENTRY_1')
          search_record.search_names.first.update(first_name: 'Original')
          search_record.save

          fresh_file = Freereg1CsvFile.find(file.id)
          ucf_ids = fresh_file.search_record_ids_with_wildcard_ucf

          expect(ucf_ids).not_to include('SR_UCF_ENTRY_1')
        end
      end

      context 'when UCF entry is edited with different wildcard pattern' do
        before do
          @original_entry = create_entry_with_ucf(file, 'UCF_ENTRY_2', 'Ori*nal')
          place.update_ucf_list(file)
        end

        it 'maintains entry in UCF lists with new wildcard' do
          search_record = SearchRecord.find('SR_UCF_ENTRY_2')
          search_record.search_names.first.update(first_name: 'Or_ginal')
          search_record.save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to include('SR_UCF_ENTRY_2')
        end
      end
    end

    describe 'replace with entries added and modified' do
      context 'when adding new entries and modifying existing entries' do
        before do
          @original_ucf = create_entry_with_ucf(file, 'ORIG_UCF', 'Pat*rn')
          @original_no_ucf = create_entry_without_ucf(file, 'ORIG_NO_UCF', 'NoWild')

          place.update_ucf_list(file)

          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly('SR_ORIG_UCF')
        end

        it 'correctly handles additions and modifications together' do
          create_entry_with_ucf(file, 'NEW_UCF_1', 'Ad?ed')
          create_entry_without_ucf(file, 'NEW_NO_UCF_1', 'Added')

          search_record = SearchRecord.find('SR_ORIG_NO_UCF')
          search_record.search_names.first.update(first_name: 'Now_Wild')
          search_record.save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly(
            'SR_ORIG_UCF',
            'SR_NEW_UCF_1',
            'SR_ORIG_NO_UCF'
          )
        end

        it 'adds new non-UCF entries but not to UCF lists' do
          create_entry_without_ucf(file, 'NEW_NO_UCF', 'PlainName')

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).not_to include('SR_NEW_NO_UCF')
        end
      end
    end

    describe 'complex replacement scenarios' do
      context 'when replacing file with multiple changes in single operation' do
        before do
          @entry1_ucf = create_entry_with_ucf(file, 'E1', 'Pat*1')
          @entry2_no_ucf = create_entry_without_ucf(file, 'E2', 'NoWild2')
          @entry3_ucf = create_entry_with_ucf(file, 'E3', 'Pat*3')

          place.update_ucf_list(file)
        end

        it 'handles remove UCF + add UCF + add non-UCF + modify non-UCF to UCF' do
          search_record_e1 = SearchRecord.find('SR_E1')
          search_record_e1.search_names.first.update(first_name: 'NoWildcard')
          search_record_e1.save

          search_record_e2 = SearchRecord.find('SR_E2')
          search_record_e2.search_names.first.update(first_name: 'Now_Wild')
          search_record_e2.save

          create_entry_with_ucf(file, 'E4', 'Pat*4')
          create_entry_without_ucf(file, 'E5', 'NoWild5')

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly(
            'SR_E3',
            'SR_E2',
            'SR_E4'
          )
        end

        it 'maintains correct count after complex replacement' do
          search_record_e1 = SearchRecord.find('SR_E1')
          search_record_e1.search_names.first.update(first_name: 'RemoveWild')
          search_record_e1.save

          create_entry_with_ucf(file, 'E4', 'New*Wild')
          create_entry_with_ucf(file, 'E5', 'Another?')

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expected_count = fresh_place.ucf_list[file.id.to_s]&.count || 0
          expect(fresh_place.ucf_list_record_count).to eq(expected_count)
        end
      end

      context 'when replacing entire file with different UCF distribution' do
        before do
          5.times { |i| create_entry_with_ucf(file, "ORIG_UCF_#{i}", "Pat*_#{i}") }
          5.times { |i| create_entry_without_ucf(file, "ORIG_NO_UCF_#{i}", "Plain_#{i}") }

          place.update_ucf_list(file)
        end

        it 'correctly updates when most entries change UCF status' do
          file.freereg1_csv_entries.each_with_index do |entry, idx|
            sr = entry.search_record
            next unless sr

            if idx.even?
              sr.search_names.first.update(first_name: "Changed_#{idx}")
            else
              sr.search_names.first.update(first_name: "Changed?_#{idx}")
            end
            sr.save
          end

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s].count).to be > 0
        end
      end
    end

    describe 'edge cases during replacement' do
      context 'when replacing file where all entries become non-UCF' do
        before do
          create_entry_with_ucf(file, 'E1', 'Pat*1')
          create_entry_with_ucf(file, 'E2', 'Pat*2')

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s].count).to eq(2)
        end

        it 'clears UCF list from place' do
          SearchRecord.find('SR_E1').search_names.first.update(first_name: 'Plain1')
          SearchRecord.find('SR_E1').save
          SearchRecord.find('SR_E2').search_names.first.update(first_name: 'Plain2')
          SearchRecord.find('SR_E2').save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to eq([])
        end
      end

      context 'when replacing file where all entries become UCF' do
        before do
          create_entry_without_ucf(file, 'E1', 'Plain1')
          create_entry_without_ucf(file, 'E2', 'Plain2')

          place.update_ucf_list(file)
        end

        it 'populates UCF list from empty state' do
          SearchRecord.find('SR_E1').search_names.first.update(first_name: 'Pat*1')
          SearchRecord.find('SR_E1').save
          SearchRecord.find('SR_E2').search_names.first.update(first_name: 'Pat*2')
          SearchRecord.find('SR_E2').save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly('SR_E1', 'SR_E2')
        end
      end

      context 'when wildcard characters appear in different positions' do
        it 'handles * at start, middle, and end' do
          create_entry_with_ucf(file, 'E1', '*tarted')
          create_entry_with_ucf(file, 'E2', 'Mid*dle')
          create_entry_with_ucf(file, 'E3', 'Ended*')

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly('SR_E1', 'SR_E2', 'SR_E3')
        end

        it 'handles multiple wildcard characters in single name' do
          create_entry_with_ucf(file, 'MULTI', 'P*t*rn?')

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to include('SR_MULTI')
        end
      end
    end

    describe 'synchronization between file and place lists' do
      context 'when file list and place list get out of sync (recovery scenario)' do
        before do
          create_entry_with_ucf(file, 'E1', 'Pat*1')
          create_entry_without_ucf(file, 'E2', 'NoWild2')

          place.update_ucf_list(file)
        end

        it 'resynchronizes lists after re-update' do
          SearchRecord.find('SR_E2').search_names.first.update(first_name: 'Now?Wild')
          SearchRecord.find('SR_E2').save

          place.update_ucf_list(file)
          place.update_ucf_list(file)

          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s]).to contain_exactly('SR_E1', 'SR_E2')
        end
      end

      context 'when multiple files reference same place' do
        let(:file2) do
          create(:freereg1_csv_file,
                 place_name: place.place_name)
        end

        before do
          create_entry_with_ucf(file, 'FILE1_E1', 'Pat*1')
          create_entry_with_ucf(file2, 'FILE2_E1', 'Pat*2')

          place.update_ucf_list(file)
          place.update_ucf_list(file2)
        end

        it 'maintains separate UCF lists for each file' do
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list[file.id.to_s]).to include('SR_FILE1_E1')
          expect(fresh_place.ucf_list[file2.id.to_s]).to include('SR_FILE2_E1')
        end

        it 'allows independent replacement of files' do
          SearchRecord.find('SR_FILE1_E1').search_names.first.update(first_name: 'Plain')
          SearchRecord.find('SR_FILE1_E1').save

          place.update_ucf_list(file)

          fresh_place = Place.find(place.id)
          expect(fresh_place.ucf_list[file.id.to_s]).not_to include('SR_FILE1_E1')
          expect(fresh_place.ucf_list[file2.id.to_s]).to include('SR_FILE2_E1')
        end
      end
    end

    describe 'place counter accuracy during replacement' do
      context 'when updating counters after complex replacement' do
        before do
          5.times { |i| create_entry_with_ucf(file, "UCF_#{i}", "Pat*_#{i}") }
          5.times { |i| create_entry_without_ucf(file, "NO_UCF_#{i}", "Plain_#{i}") }

          place.update_ucf_list(file)
        end

        it 'maintains accurate record count after removal' do
          SearchRecord.find('SR_UCF_0').search_names.first.update(first_name: 'Plain0')
          SearchRecord.find('SR_UCF_0').save
          SearchRecord.find('SR_UCF_1').search_names.first.update(first_name: 'Plain1')
          SearchRecord.find('SR_UCF_1').save

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expected = fresh_place.ucf_list[file.id.to_s]&.count || 0
          expect(fresh_place.ucf_list_record_count).to eq(expected)
        end

        it 'maintains accurate record count after addition' do
          3.times { |i| create_entry_with_ucf(file, "NEW_UCF_#{i}", "New*_#{i}") }

          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expected = fresh_place.ucf_list[file.id.to_s]&.count || 0
          expect(fresh_place.ucf_list_record_count).to eq(expected)
        end

        it 'updates timestamp on replacement' do
          before_time = DateTime.now
          place.update_ucf_list(file)
          fresh_place = Place.find(place.id)

          expect(fresh_place.ucf_list_updated_at).to be >= before_time
        end
      end
    end
  end
end
