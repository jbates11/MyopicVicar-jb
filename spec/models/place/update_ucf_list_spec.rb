require "rails_helper"

RSpec.describe Place, type: :model do
  describe "#update_ucf_list" do
    # ---------------------------------------------------------
    # SETUP
    # ---------------------------------------------------------

    let(:place) do
      create(:place,
        chapman_code: "YKS",
        place_name: "York",
        ucf_list: {}
      )
    end

    let(:file) do
      create(:freereg1_csv_file,
        place: "York",
        county: "YKS"
      )
    end

    # ---------------------------------------------------------
    # GUARD CLAUSE: file is nil
    # ---------------------------------------------------------

    context "when file is nil" do
      it "returns early without raising error" do
        expect { place.update_ucf_list(nil) }.not_to raise_error
      end

      it "leaves place.ucf_list unchanged" do
        place.update_ucf_list(nil)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list).to eq({})
      end
    end

    # ---------------------------------------------------------
    # BEHAVIOR: No wildcard records exist
    # ---------------------------------------------------------

    context "when no wildcard records exist for the file" do
      it "stores empty hash in place.ucf_list for this file" do
        place.update_ucf_list(file)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list[file.id.to_s]).to eq([])
      end

      it "sets file.ucf_list to empty array" do
        place.update_ucf_list(file)

        fresh_file = Freereg1CsvFile.find(file.id)
        expect(fresh_file.ucf_list).to eq([])
      end

      it "records today's date in file.ucf_updated" do
        place.update_ucf_list(file)

        fresh_file = Freereg1CsvFile.find(file.id)
        expect(fresh_file.ucf_updated).to eq(Date.today)
      end

      it "updates place.ucf_list_updated_at timestamp" do
        place.update_ucf_list(file)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list_updated_at).to be_a(DateTime)
      end

      it "sets ucf_list_record_count based on all records" do
        place.update_ucf_list(file)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list_record_count).to be_an(Integer)
      end

      it "counts file as one entry in ucf_list_file_count" do
        place.update_ucf_list(file)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list_file_count).to eq(1)
      end

      it "ensures all values in ucf_list are Arrays (never Hash)" do
        place.update_ucf_list(file)
        
        place.ucf_list.each_value do |value|
          expect(value).to be_an(Array), "Expected Array but got #{value.class}"
        end
      end
    end

    # ---------------------------------------------------------
    # BEHAVIOR: Multiple files accumulate state
    # ---------------------------------------------------------

    context "when updating multiple files sequentially" do
      let!(:file2) do
        create(:freereg1_csv_file, place: "York", county: "YKS")
      end

      it "accumulates file entries in place.ucf_list" do
        place.update_ucf_list(file)
        place.update_ucf_list(file2)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list).to have_key(file.id.to_s)
        expect(fresh_place.ucf_list).to have_key(file2.id.to_s)
      end

      it "increments ucf_list_file_count for each file" do
        place.update_ucf_list(file)
        place.update_ucf_list(file2)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list_file_count).to eq(2)
      end

      it "updates timestamp on each call" do
        time_before_1 = DateTime.now
        place.update_ucf_list(file)
        fresh_place_1 = Place.find(place.id)
        first_timestamp = fresh_place_1.ucf_list_updated_at

        time_before_2 = DateTime.now
        place.update_ucf_list(file2)
        fresh_place_2 = Place.find(place.id)
        second_timestamp = fresh_place_2.ucf_list_updated_at

        expect(second_timestamp).to be > first_timestamp
      end
    end

    # ---------------------------------------------------------
    # EDGE CASE: File ID field name storage
    # ---------------------------------------------------------

    context "when storing file references as hash keys" do
      it "converts file.id to string for hash key" do
        place.update_ucf_list(file)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list).to have_key(file.id.to_s)
      end

      it "does not use file.id as integer key" do
        place.update_ucf_list(file)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list).not_to have_key(file.id)
      end
    end

    # ---------------------------------------------------------
    # PERSISTENCE: MongoDB data persisted correctly
    # ---------------------------------------------------------

    context "database persistence to MongoDB" do
      it "persists place.ucf_list changes to database" do
        place.update_ucf_list(file)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list).to be_a(Hash)
        expect(fresh_place.ucf_list).to have_key(file.id.to_s)
      end

      it "persists file.ucf_list changes to database" do
        place.update_ucf_list(file)

        fresh_file = Freereg1CsvFile.find(file.id)
        expect(fresh_file.ucf_list).to be_a(Array)
      end

      it "persists place timestamps to database" do
        place.update_ucf_list(file)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list_updated_at).to be_present
      end

      it "persists place counters to database" do
        place.update_ucf_list(file)

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list_record_count).to be_a(Integer)
        expect(fresh_place.ucf_list_file_count).to be_a(Integer)
      end
    end

    # ---------------------------------------------------------
    # STATE ISOLATION: Each test uses fresh instances
    # ---------------------------------------------------------

    context "state isolation between calls" do
      it "does not mutate in-memory place without persistence" do
        place.update_ucf_list(file)

        fresh_place_1 = Place.find(place.id)
        original_count = fresh_place_1.ucf_list_file_count

        place.update_ucf_list(file)

        fresh_place_2 = Place.find(place.id)
        updated_count = fresh_place_2.ucf_list_file_count

        expect(updated_count).to eq(original_count)
      end
    end
  end
end
