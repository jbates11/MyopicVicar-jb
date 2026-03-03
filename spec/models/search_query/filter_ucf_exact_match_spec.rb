require "rails_helper"

RSpec.describe SearchQuery, type: :model do
  describe "#filter_ucf_records for exact match searches" do
    let(:place) { create(:place) }
    let(:search_query) do
      create(:search_query,
        chapman_codes: [place.chapman_code],
        record_type: RecordType::BAPTISM  # Match the record factory default
      )
    end

    context "exact match search (fuzzy=false, no wildcards)" do
      it "does NOT include unrelated UCF records" do
        # Setup: UCF record "do_e" in place
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name, 
          first_name: 'john', 
          last_name: 'do_e'  # Contains underscore (uncertain)
        )
        ucf_record.save

        # Setup: Search for exact "andover"
        search_query.update(
          fuzzy: false,
          last_name: 'andover',
          first_name: nil
        )

        # Execute: Filter UCF records
        # The "andover" search should NOT match "do_e" using logic:
        # 1. Exact match? "andover" != "do_e" → No
        # 2. Record has UCF? Yes, but search doesn't have wildcards (exact mode)
        #    Only include if search exactly equals name → No match
        # 3. Search has wildcards? No
        # Result: Not included (correct behavior)
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Record should NOT be included
        expect(filtered).to be_empty
      end

      it "DOES include matching UCF records with same base name" do
        # Setup: UCF record "Sus*n andover" (uncertainty in first name, not surname)
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name,
          first_name: 'Sus*n',  # Contains wildcard
          last_name: 'andover'
        )
        ucf_record.save

        # Setup: Search for exact "andover"
        search_query.update(
          fuzzy: false,
          last_name: 'andover',
          first_name: nil
        )

        # Execute: Filter UCF records  
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Record SHOULD be included (surname matches exactly)
        expect(filtered).to include(ucf_record.id)
      end

      it "correctly handles both first and last names" do
        # Setup: Exact match on both names
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name,
          first_name: 'susan',
          last_name: 'andover'
        )
        ucf_record.save

        # Setup: Search for exact match
        search_query.update(
          fuzzy: false,
          first_name: 'susan',
          last_name: 'andover'
        )

        # Execute
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Exact match should be included
        expect(filtered).to include(ucf_record.id)
      end
    end

    context "wildcard search (contains * _ ? or {)" do
      it "DOES include UCF records matching the wildcard pattern" do
        # Setup: UCF record "do_e"
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name,
          first_name: 'john',
          last_name: 'do_e'
        )
        ucf_record.save

        # Setup: Wildcard search "do*e"
        search_query.update(
          fuzzy: false,
          last_name: 'do*e',  # Wildcard pattern
          first_name: nil
        )

        # Execute
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Should match because search has wildcard
        expect(filtered).to include(ucf_record.id)
      end

      it "DOES include UCF records when search has wildcard" do
        # Setup: Normal record "andover" (no UCF)
        normal_record = create(:search_record, place: place)
        normal_record.search_names << build(:search_name,
          first_name: 'susan',
          last_name: 'andover'
        )
        normal_record.save

        # Setup: Wildcard search "and*ver"
        search_query.update(
          fuzzy: false,
          last_name: 'and*ver',  # User's search has wildcard
          first_name: nil
        )

        # Execute: Filter with search containing wildcard
        filtered = search_query.filter_ucf_records([normal_record.id])

        # Assert: Should match because search has wildcard (bidirectional regex)
        expect(filtered).to include(normal_record.id)
      end
    end

    context "fuzzy search (fuzzy=true)" do
      it "uses regex matching for UCF records" do
        # Setup: UCF record "do_e"
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name,
          first_name: 'john',
          last_name: 'do_e'
        )
        ucf_record.save

        # Setup: Fuzzy search "andover"
        search_query.update(
          fuzzy: true,  # Fuzzy enabled
          last_name: 'andover',
          first_name: nil
        )

        # Execute
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Uses regex matching (so "andover" can match "do_e" → /do.e/)
        # This is acceptable in fuzzy mode
        expect(filtered).to include(ucf_record.id)
      end
    end
  end
end
