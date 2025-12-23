require "rails_helper"

RSpec.describe UseridDetailsHelper, type: :helper do
  describe "#coordinator_display" do
    let!(:userid_detail) { create(:userid_detail, userid: "USER001", syndicate: "SYN001") }

    context "when the syndicate exists and coordinator user exists" do
      let!(:syndicate) do
        create(:syndicate,
          syndicate_code: "SYN001",
          syndicate_coordinator: "COORD001"
        )
      end

      let!(:coord_user) do
        create(:userid_detail,
          userid: "COORD001",
          person_forename: "Alice",
          person_surname: "Smith"
        )
      end

      it "returns the formatted coordinator name and code" do
        result = helper.coordinator_display(userid_detail)
        expect(result).to eq("Alice Smith (COORD001)")

        # Manual clean up since database_cleaner-mongoid bypasses callbacks and mysql
	      Refinery::Authentication::Devise::User.find_by(username: 'USER001')&.destroy!
	      Refinery::Authentication::Devise::User.find_by(username: 'COORD001')&.destroy!
      end

      it "returns a string that is HTML-safe" do
        result = helper.coordinator_display(userid_detail)
        expect(result.html_safe?).to be(true)

        # Manual clean up since database_cleaner-mongoid bypasses callbacks and mysql
	      Refinery::Authentication::Devise::User.find_by(username: 'USER001')&.destroy!
	      Refinery::Authentication::Devise::User.find_by(username: 'COORD001')&.destroy!
      end
    end

    context "when syndicate exists but coordinator user is missing" do
      let!(:syndicate) do
        create(:syndicate,
          syndicate_code: "SYN001",
          syndicate_coordinator: "MISSING001"
        )
      end

      it "returns the fallback message" do
        result = helper.coordinator_display(userid_detail)
        expect(result).to eq("Syndicate coordinator missing or unknown.")

        # Manual clean up since database_cleaner-mongoid bypasses callbacks and mysql
	      Refinery::Authentication::Devise::User.find_by(username: 'USER001')&.destroy!
      end
    end

    context "when syndicate does not exist" do
      it "returns the fallback message" do
        result = helper.coordinator_display(userid_detail)
        expect(result).to eq("Syndicate coordinator missing or unknown.")

        # Manual clean up since database_cleaner-mongoid bypasses callbacks and mysql
	      Refinery::Authentication::Devise::User.find_by(username: 'USER001')&.destroy!
      end
    end

    # JC NOT test due to syndicate  save callback
    # context "when syndicate exists but has nil coordinator" do
    #   let!(:syndicate) do
    #     create(:syndicate,
    #       syndicate_code: "SYN001",
    #       syndicate_coordinator: nil
    #     )
    #   end

    #   it "returns the fallback message" do
    #     result = helper.coordinator_display(userid_detail)
    #     expect(result).to eq("Syndicate coordinator missing or unknown.")

    #     # Manual clean up since database_cleaner-mongoid bypasses callbacks and mysql
	  #     Refinery::Authentication::Devise::User.find_by(username: 'USER001')&.destroy!
    #   end
    # end

  end
end
