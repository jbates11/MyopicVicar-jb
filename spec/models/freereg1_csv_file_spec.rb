require 'rails_helper'

RSpec.describe Freereg1CsvFile, type: :model do
  describe "#search_record_ids_with_wildcard_ucf" do
    let(:file) { create(:freereg1_csv_file) }

    context "when entries have search records with wildcard UCFs" do
      it "returns the IDs of flagged search records" do
        entry  = create(:freereg1_csv_entry, freereg1_csv_file: file)
        record = create(:search_record, freereg1_csv_entry: entry, place: create(:place))

        # Attach a SearchName with a wildcard in first_name
        record.search_names << build(:search_name, first_name: "Jo*n", last_name: "Doe")

        ids = file.search_record_ids_with_wildcard_ucf

        expect(ids).to include(record.id)
      end

      it "returns the IDs of flagged search records" do
        entry  = create(:freereg1_csv_entry, freereg1_csv_file: file)
        record = create(:search_record, freereg1_csv_entry: entry)

        # Add embedded document correctly
        record.search_names.create!(first_name: "Jo*n", last_name: "Doe")

        ids = file.search_record_ids_with_wildcard_ucf

        # Convert to strings to ensure the comparison passes regardless of BSON/String types
        expect(ids.map(&:to_s)).to include(record.id.to_s)
      end
    end

    context "when entries have search records without wildcard UCFs" do
      it "returns an empty array" do
        entry  = create(:freereg1_csv_entry, freereg1_csv_file: file)
        record = create(:search_record, freereg1_csv_entry: entry, place: create(:place))

        # Attach a SearchName with no wildcards
        record.search_names << build(:search_name, first_name: "John", last_name: "Doe")

        ids = file.search_record_ids_with_wildcard_ucf

        expect(ids).to be_empty
      end
    end

    context "when entries have no search records" do
      it "returns an empty array" do
        create(:freereg1_csv_entry, freereg1_csv_file: file)
        # No SearchRecord created for this entry

        ids = file.search_record_ids_with_wildcard_ucf

        expect(ids).to be_empty
      end
    end
  end
end
