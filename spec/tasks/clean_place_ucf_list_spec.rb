require 'rails_helper'
require 'rake'

RSpec.describe 'freereg:clean_ucf_place_list' do
  let(:rake_task) { Rake::Task['freereg:clean_ucf_place_list'] }

  before do
    Rake.application.rake_require('tasks/clean_place_ucf_list')
    # Rake.application.rake_require('tasks/clean_place_ucf_list', [Rails.root.to_s])
    Rake::Task.define_task(:environment)
  end

  after do
    rake_task.reenable
  end

  describe 'task execution' do
    context 'when places have valid ucf_list entries' do
      let!(:county_code) { 'DEV' }
      let!(:place_name) { 'TestTown' }

      let!(:valid_file) do
        create(:freereg1_csv_file, county: county_code, place: place_name)
      end

      let!(:invalid_file) do
        create(:freereg1_csv_file, county: 'XX', place: 'WrongTown')
      end

      let!(:place) do
        create(:place,
               place_name: place_name,
               chapman_code: county_code,
               ucf_list: {
                 valid_file.id.to_s => { 'data' => 'value' },
                 invalid_file.id.to_s => { 'other' => 'data' }
               })
      end

      it 'removes invalid ucf_list entries' do
        expect {
          rake_task.invoke
        }.to change {
          (place.class.find(place.id)).ucf_list
        }.from(
          hash_including(valid_file.id.to_s, invalid_file.id.to_s)
        ).to(
          hash_including(valid_file.id.to_s)
        )
      end

      it 'preserves valid ucf_list entries matching place and county' do
        rake_task.invoke
        (place.class.find(place.id))

        expect(place.ucf_list).to include(valid_file.id.to_s)
        expect(place.ucf_list[valid_file.id.to_s]).to eq({ 'data' => 'value' })
      end

      it 'stores original ucf_list in old_ucf_list' do
        original_list = place.ucf_list.dup
        p "original_list: #{original_list}"

        rake_task.invoke
        (place.class.find(place.id))
        p "ucf_list: #{place.ucf_list}"  
        p "old_ucf_list: #{place.old_ucf_list}"  

        expect(place.old_ucf_list).to eq(original_list)
      end

      it 'removes entries for files with mismatched county' do
        rake_task.invoke
        (place.class.find(place.id))

        expect(place.ucf_list).not_to include(invalid_file.id.to_s)
      end
    end

    context 'when places have empty ucf_list' do
      let!(:place) do
        create(:place, ucf_list: {})
      end

      it 'handles empty ucf_list gracefully' do
        expect {
          rake_task.invoke
        }.not_to raise_error
      end

      it 'maintains empty ucf_list' do
        rake_task.invoke
        (place.class.find(place.id))

        expect(place.ucf_list).to be_empty
      end
    end

    context 'when ucf_list references non-existent files' do
      let!(:place) do
        create(:place,
               ucf_list: {
                 'nonexistent_id_1' => { 'data' => 'value' },
                 'nonexistent_id_2' => { 'other' => 'data' }
               })
      end

      it 'removes all entries for missing files' do
        rake_task.invoke
        (place.class.find(place.id))

        expect(place.ucf_list).to be_empty
      end
    end

    context 'with multiple places' do
      let!(:place1) do
        file1 = create(:freereg1_csv_file, county: 'DEV', place: 'Town1')
        create(:place,
               place_name: 'Town1',
               chapman_code: 'DEV',
               ucf_list: { file1.id.to_s => { 'data' => 'value' } })
      end

      let!(:place2) do
        file2 = create(:freereg1_csv_file, county: 'ESS', place: 'Town2')
        create(:place,
               place_name: 'Town2',
               chapman_code: 'ESS',
               ucf_list: { file2.id.to_s => { 'data2' => 'value2' } })
      end

      it 'processes all places' do
        rake_task.invoke
        
        (place1.class.find(place1.id))
        (place2.class.find(place2.id))

        expect(place1.ucf_list).not_to be_empty
        expect(place2.ucf_list).not_to be_empty
      end

      it 'preserves each place\'s valid entries independently' do
        file1 = Freereg1CsvFile.find(place1.ucf_list.keys.first)
        file2 = Freereg1CsvFile.find(place2.ucf_list.keys.first)

        rake_task.invoke
        (place1.class.find(place1.id))
        (place2.class.find(place2.id))

        expect(place1.ucf_list.keys).to include(file1.id.to_s)
        expect(place2.ucf_list.keys).to include(file2.id.to_s)
      end
    end

    context 'when files match place but not county' do
      let!(:county_code) { 'DEV' }
      let!(:place_name) { 'TestTown' }

      let!(:mismatched_file) do
        create(:freereg1_csv_file, county: 'XX', place: place_name)
      end

      let!(:place) do
        create(:place,
               place_name: place_name,
               chapman_code: county_code,
               ucf_list: { mismatched_file.id.to_s => { 'data' => 'value' } })
      end

      it 'removes entry when county does not match' do
        rake_task.invoke
        (place.class.find(place.id))

        expect(place.ucf_list).to be_empty
      end
    end

    context 'when files match county but not place' do
      let!(:county_code) { 'DEV' }
      let!(:place_name) { 'TestTown' }

      let!(:mismatched_file) do
        create(:freereg1_csv_file, county: county_code, place: 'WrongTown')
      end

      let!(:place) do
        create(:place,
               place_name: place_name,
               chapman_code: county_code,
               ucf_list: { mismatched_file.id.to_s => { 'data' => 'value' } })
      end

      it 'removes entry when place does not match' do
        rake_task.invoke
        (place.class.find(place.id))

        expect(place.ucf_list).to be_empty
      end
    end
  end
end
