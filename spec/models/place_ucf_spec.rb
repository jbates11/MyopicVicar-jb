require 'rails_helper'

RSpec.describe Place, type: :model do
  describe "#update_ucf_list" do
    let(:place) { create(:place) }
    let(:file)  { create(:freereg1_csv_file) }

    context "when search records contain wildcard UCFs" do
      it "updates both place and file ucf_list with flagged IDs" do
        entry  = create(:freereg1_csv_entry, freereg1_csv_file: file)
        record = create(:search_record,
                        freereg1_csv_entry: entry,
                        place: place)

        # Attach a SearchName with a wildcard
        record.search_names << build(:search_name, first_name: "Jo*n", last_name: "Doe")

        place.update_ucf_list(file)

        expect(place.ucf_list[file.id.to_s]).to include(record.id)
        expect(file.ucf_list).to include(record.id)
        expect(file.ucf_updated).to eq(DateTime.now.to_date)
      end
    end

    context "when search records do not contain wildcard UCFs" do
      it "does not update ucf_list but stamps update date" do
        entry  = create(:freereg1_csv_entry, freereg1_csv_file: file)
        record = create(:search_record,
                        freereg1_csv_entry: entry,
                        place: place)

        # Attach a SearchName without wildcards
        record.search_names << build(:search_name, first_name: "John", last_name: "Doe")

        place.update_ucf_list(file)

        expect(place.ucf_list[file.id.to_s]).to eq({})
        expect(file.ucf_list).to eq([])
        expect(file.ucf_updated).to eq(DateTime.now.to_date)
      end
    end

    context "when there are no search records" do
      it "does not update ucf_list but stamps update date" do
        create(:freereg1_csv_entry, freereg1_csv_file: file)
        # No SearchRecord created

        place.update_ucf_list(file)

        expect(place.ucf_list[file.id.to_s]).to eq({})
        expect(file.ucf_list).to eq([])
        expect(file.ucf_updated).to eq(DateTime.now.to_date)
      end
    end
  end
end
