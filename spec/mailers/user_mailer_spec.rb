require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  describe '#batch_processing_success' do
    let(:syndicate_coordinator) do
      create(:userid_detail, userid: 'sync_coord', email_address: 'sync@example.com', syndicate: 'SyndicateA')
    end
    
    let(:county_coordinator) do
      create(:userid_detail, userid: 'county_coord', email_address: 'county@example.com', syndicate: 'SyndicateB')
    end

    let!(:syndicate) do
      create(:syndicate, syndicate_code: 'SyndicateA', syndicate_coordinator: syndicate_coordinator.userid)
    end

    let!(:county) do
      create(:county, chapman_code: 'DEV', county_coordinator: county_coordinator.userid)
    end

    let(:transcriber) do
      create(:userid_detail, userid: 'transcriber1', email_address: 'transcriber@example.com', 
             syndicate: 'SyndicateA', county_groups: county_groups)
    end

    let(:csv_file) do
      create(:freereg1_csv_file, file_name: 'DEVbap.csv', userid: transcriber.userid, county: 'DEV',
             error: 2, datemin: '1800', datemax: '1900')
    end

    let(:message_file) do
      file = Tempfile.new('upload_log')
      file.write("Log line 1\nLog line 2")
      file.close
      file
    end

    after do
      message_file.unlink
    end

    before do
      allow(MyopicVicar::Application.config).to receive(:template_set).and_return('freereg')
    end

    context 'Scenario 1: Uploaded file county matches transcriber county_groups' do
      let(:county_groups) { ['DEV', 'SOM'] }
      let(:mail) { UserMailer.batch_processing_success(message_file.path, transcriber.userid, csv_file.file_name) }

      it 'sends the email to the transcriber with SC and CC in cc' do
        expect(mail.to).to eq([transcriber.email_address])
        expect(mail.cc).to contain_exactly(syndicate_coordinator.email_address, county_coordinator.email_address)
      end

      it 'formats the subject correctly without an alert' do
        expect(mail.subject).to eq("#{transcriber.userid}/#{csv_file.file_name} processed with 2 errors over period 1800-1900")
      end

      it 'does not prepend an alert to the body' do
        expect(mail.body.encoded).to include("Log line 1")
        expect(mail.body.encoded).not_to include("ALERT! This file was uploaded to your county")
      end
    end

    context 'Scenario 2: Uploaded file county does not match transcriber county_groups (Cross-County Upload)' do
      let(:county_groups) { ['YKS', 'SOM'] }
      let(:mail) { UserMailer.batch_processing_success(message_file.path, transcriber.userid, csv_file.file_name) }

      it 'sends the email to the transcriber with SC and CC in cc' do
        expect(mail.to).to eq([transcriber.email_address])
        expect(mail.cc).to contain_exactly(syndicate_coordinator.email_address, county_coordinator.email_address)
      end

      it 'formats the subject with an ALERT' do
        expect(mail.subject).to match(/\* \* \* ALERT! Data was uploaded to your county from: transcriber1\/DEVbap\.csv processed at .*\* \* \*/)
      end

      it 'prepends an alert to the body' do
        expect(mail.body.encoded).to include("ALERT! This file was uploaded to your county by a UserID from a county group not associated with your county")
        expect(mail.body.encoded).to include("Log line 1")
      end
    end
    
    context 'when the transcriber has missing county_groups' do
      let(:county_groups) { nil }
      let(:mail) { UserMailer.batch_processing_success(message_file.path, transcriber.userid, csv_file.file_name) }

      it 'treats it as a cross-county upload (Scenario 2)' do
        expect(mail.subject).to match(/\* \* \* ALERT!/)
      end
    end
    
    context 'when syndicate coordinator is also the county coordinator' do
      let(:county_groups) { ['DEV'] }
      let(:county_coordinator) { syndicate_coordinator }
      
      let(:mail) { UserMailer.batch_processing_success(message_file.path, transcriber.userid, csv_file.file_name) }

      it 'does not duplicate the cc email address' do
        expect(mail.cc).to eq([syndicate_coordinator.email_address])
      end
    end
  end
end
