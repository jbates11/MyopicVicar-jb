require 'rails_helper'

RSpec.describe SearchRecord, type: :model do
  describe "#populate_search_names" do
    let(:search_record) { build(:search_record, :marriage_transcript_names) }

    context "with valid transcript_names" do
      it "adds search_names for each transcript_name" do
        expect(search_record.search_names).to be_empty

        search_record.populate_search_names

        expect(search_record.search_names).not_to be_empty
        expect(search_record.search_names.size).to be >= 2

        # check that names were built correctly
        first = search_record.search_names.first
        expect(first.first_name.downcase).to eq("john")
        expect(first.last_name.downcase).to eq("smith")
      end
    end

    context "when names contain symbols" do
      let(:search_record) do
        build(:search_record,
          transcript_names: [
            { first_name: "John", last_name: "Smith", type: "primary", role: "father" },
            { first_name: "J@hn", last_name: "Sm!th", type: "primary", role: "father" }
          ]
        )
      end

      it "adds both raw and cleaned search_names" do
        search_record.populate_search_names

        names = search_record.search_names.map { |sn| [sn.first_name, sn.last_name] }

        expect(names).to include(["J@hn", "Sm!th"])
        expect(names).to include(["John", "Smith"])
      end
    end

    context "when transcript_names is empty" do
      let(:search_record) { build(:search_record, transcript_names: []) }

      it "does not add any search_names" do
        search_record.populate_search_names
        expect(search_record.search_names).to be_empty
      end
    end
  end
end
