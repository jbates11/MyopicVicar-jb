require "rails_helper"

RSpec.describe Freereg1CsvEntry, type: :model do
  describe '#compute_ucf_change' do
    let(:place) { FactoryBot.create(:place) }

    # Use the trait here:
    let(:search_record) { FactoryBot.create(:search_record, :with_wildcard_name, place: place) }
    
    let(:entry) { FactoryBot.create(:freereg1_csv_entry, search_record: search_record) }
    let(:file) { entry.freereg1_csv_file }

    context 'when SearchRecord has wildcard UCF and not yet in list' do
      it 'returns action: :add' do
        result = entry.compute_ucf_change(place, file, nil)
        expect(result[:action]).to eq(:add)
        expect(result[:id]).to eq(search_record.id)
      end
    end

    context 'when SearchRecord already in Place UCF list' do
      before do
        place.update(ucf_list: { file.id.to_s => [search_record.id] })
      end

      it 'returns no action (already listed)' do
        result = entry.compute_ucf_change(place, file, nil)
        expect(result[:action]).to be_nil
        expect(result[:reason]).to eq('already_listed')
      end
    end

    context 'when SearchRecord has no wildcard UCF' do
      let(:entry) { FactoryBot.create(:freereg1_csv_entry, search_record: search_record) }
      
      before do
        allow(search_record).to receive(:contains_wildcard_ucf).and_return(false)
      end

      it 'returns no action' do
        result = entry.compute_ucf_change(place, file, nil)
        expect(result[:action]).to be_nil
        expect(result[:reason]).to eq('no_wildcard')
      end
    end

    context 'when entry has no SearchRecord' do
      let(:entry) { FactoryBot.create(:freereg1_csv_entry, search_record: nil) }

      it 'returns no action' do
        result = entry.compute_ucf_change(place, file, nil)
        expect(result[:action]).to be_nil
        expect(result[:reason]).to eq('no_search_record')
      end
    end

    context 'when error occurs during computation' do
      before do
        allow(entry).to receive(:search_record).and_raise(StandardError.new("DB error"))
      end

      it 'returns error reason and does not raise' do
        result = entry.compute_ucf_change(place, file, nil)
        expect(result[:action]).to be_nil
        expect(result[:reason]).to eq('error')
      end
    end

    # duplicate test
    context 'when SearchRecord has wildcard UCF' do
      let(:search_record) { FactoryBot.create(:search_record, :with_wildcard_name, place: place) }
      let(:entry) { FactoryBot.create(:freereg1_csv_entry, search_record: search_record) }

      it 'returns action: :add' do
        result = entry.compute_ucf_change(place, file, nil)
        expect(result[:action]).to eq(:add)
      end
    end

    # duplicate test
    context 'when SearchRecord does NOT have wildcard UCF' do
      # Use the negative trait here
      let(:search_record) { FactoryBot.create(:search_record, :with_standard_name, place: place) }
      let(:entry) { FactoryBot.create(:freereg1_csv_entry, search_record: search_record) }

      it 'returns reason: "no_wildcard" and no action' do
        result = entry.compute_ucf_change(place, file, nil)
        
        expect(result[:action]).to be_nil
        expect(result[:reason]).to eq('no_wildcard')
      end
    end
    
  end
end