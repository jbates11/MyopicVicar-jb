require "rails_helper"

RSpec.describe Freereg1CsvFile, type: :model do
  describe "#clean_up_place_ucf_list" do
    let(:file)  { create(:freereg1_csv_file) }
    let(:place) { create(:place, ucf_list: initial_place_list) }

    before do
      # Stub the location lookup so we control the behavior
      allow(file).to receive(:location_from_file)
        .and_return([proceed, place, nil, nil])
    end

    context "when proceed=false" do
      let(:proceed) { false }
      let(:initial_place_list) { {} }

      it "does nothing and does not modify the place or file" do
        file.clean_up_place_ucf_list

        fresh_file  = Freereg1CsvFile.find(file.id)
        fresh_place = Place.find(place.id)

        expect(fresh_place.ucf_list).to eq({})
        expect(fresh_file.ucf_list).to be_blank
      end
    end

    context "when no place is returned" do
      let(:proceed) { true }
      let(:place)   { nil }
      let(:initial_place_list) { {} }

      it "does nothing" do
        file.clean_up_place_ucf_list

        fresh_file = Freereg1CsvFile.find(file.id)
        expect(fresh_file.ucf_list).to be_blank
      end
    end

    context "when place exists and contains this file's ID" do
      let(:proceed) { true }
      let(:initial_place_list) do
        {
          file.id.to_s => { "dummy" => "data" },
          "other_file" => { "something" => "else" }
        }
      end

      it "updates place counters atomically" do
        place.update(
          ucf_list: {
            file.id.to_s => ["SR1", "SR2"],
            "other_id" => ["SR3"]
          }
        )

        file.clean_up_place_ucf_list

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list_record_count).to eq(1)  # Only SR3 remains
        expect(fresh_place.ucf_list_file_count).to eq(1)    # Only other file
      end

      it "removes this file's entry from the place ucf_list" do
        file.clean_up_place_ucf_list

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list.keys).not_to include(file.id.to_s)
        expect(fresh_place.ucf_list.keys).to include("other_file")
      end

      it "clears this file's own ucf_list" do
        file.update(ucf_list: ["something"])

        file.clean_up_place_ucf_list

        fresh_file = Freereg1CsvFile.find(file.id)
        expect(fresh_file.ucf_list).to eq([])
      end

      it "is idempotent (running twice produces same result)" do
        file.clean_up_place_ucf_list
        file.clean_up_place_ucf_list

        fresh_place = Place.find(place.id)
        fresh_file  = Freereg1CsvFile.find(file.id)

        expect(fresh_place.ucf_list.keys).not_to include(file.id.to_s)
        expect(fresh_file.ucf_list).to eq([])
      end
    end

    context "when place exists but does NOT contain this file's ID" do
      let(:proceed) { true }
      let(:initial_place_list) do
        {
          "other_file" => { "something" => "else" }
        }
      end

      it "does not modify the place ucf_list" do
        file.clean_up_place_ucf_list

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list).to eq(initial_place_list)
      end

      it "still clears this file's own ucf_list" do
        file.update(ucf_list: ["x"])

        file.clean_up_place_ucf_list

        fresh_file = Freereg1CsvFile.find(file.id)
        expect(fresh_file.ucf_list).to eq([])
      end
    end

    context "when file ucf_list is already empty" do
      let(:proceed) { true }
      let(:initial_place_list) { {} }

      it "does not raise and remains empty" do
        file.clean_up_place_ucf_list

        fresh_file = Freereg1CsvFile.find(file.id)
        expect(fresh_file.ucf_list).to eq([])
      end
    end
  end
end
