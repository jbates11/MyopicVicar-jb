require 'rails_helper'

# Define necessary factories for testing if they do not already exist.
# This ensures isolated, predictable test data without manual instantiation.
begin
  FactoryBot.define do
    factory :place do
      chapman_code { 'DEV' }
      place_name { 'Test Place' }
    end

    factory :church do
      place
      church_name { 'Test Church' }
    end

    factory :register do
      church
      register_type { 'PR' }
    end

    factory :freereg1_csv_file do
      register
      sequence(:file_name) { |n| "test_file_#{n}.csv" }
      userid { 'test_user' }
      record_type { 'ba' }
      locked_by_transcriber { false }
      locked_by_coordinator { false }
    end

    factory :freereg1_csv_entry do
      freereg1_csv_file
      person_forename { 'John' }
      person_surname { 'Doe' }
      record_type { 'ba' }
      year { '1800' }
    end

    factory :physical_file do
      userid { 'test_user' }
      sequence(:file_name) { |n| "test_file_#{n}.csv" }
      waiting_to_be_processed { true }
    end
  end
rescue FactoryBot::DuplicateDefinitionError
  # Factories already defined in the main suite
end

RSpec.describe Freereg1CsvEntriesController, type: :controller do
  describe 'DELETE #destroy' do
    # AAA Pattern: Arrange
    let(:file) { create(:freereg1_csv_file, userid: 'test_user') }
    let(:entry) { create(:freereg1_csv_entry, freereg1_csv_file: file) }

    before do
      # Set fallback location for redirect_back
      request.env['HTTP_REFERER'] = 'http://test.host/manage_resources/new'

      # Mock authentication/authorization for isolated controller testing
      allow(controller).to receive(:require_login).and_return(true)
      allow(controller).to receive(:current_authentication_devise_user).and_return(double('User', id: 1))

      # Session setup to mimic a logged-in transcriber
      session[:my_own] = true
    end

    context 'when parameters are invalid' do
      it 'redirects back with a missing ID notice' do
        # Act
        delete :destroy, params: { id: '' }

        # Assert
        expect(response).to redirect_to('http://test.host/manage_resources/new')
        expect(flash[:notice]).to eq('The entry ID was missing.')
      end

      it 'redirects back with an incorrectly linked notice when entry does not exist' do
        # Act
        delete :destroy, params: { id: 'nonexistent_id' }

        # Assert
        expect(response).to redirect_to('http://test.host/manage_resources/new')
        expect(flash[:notice]).to match(/not correctly linked/)
      end
    end

    context 'when the entry exists but file involves a locking condition preventing edits' do
      before do
        # Isolate and arrange a file state that fails `can_we_edit?`
        # We accomplish this by creating a physical file that is marked as waiting.
        allow_any_instance_of(Freereg1CsvFile).to receive(:can_we_edit?).and_return(false)
      end

      it 'redirects back with an uneditable notice and does not delete the entry' do
        # Arrange
        entry_id = entry.id

        # Act
        delete :destroy, params: { id: entry_id.to_s }

        # Assert
        expect(response).to redirect_to('http://test.host/manage_resources/new')
        expect(flash[:notice]).to match(/currently awaiting processing and should not be edited/)

        # Ensure entry was not deleted (fetch fresh instance)
        fresh_entry = Freereg1CsvEntry.find_by(id: entry_id)
        expect(fresh_entry).to be_present
      end
    end

    context 'when the entry is valid and file is editable' do
      it 'deletes the entry from the database' do
        # Arrange
        entry_id = entry.id
        expect(Freereg1CsvEntry.where(id: entry_id).exists?).to be true

        # Act
        delete :destroy, params: { id: entry_id.to_s }

        # Assert
        expect(Freereg1CsvEntry.where(id: entry_id).exists?).to be false
      end

      it 'removes the entry from the file association' do
        # Arrange
        file_id = file.id
        entry_id = entry.id

        # Act
        delete :destroy, params: { id: entry_id.to_s }

        # Assert
        fresh_file = Freereg1CsvFile.find_by(id: file_id)
        expect(fresh_file.freereg1_csv_entries.where(id: entry_id).exists?).to be false
      end

      it 'updates statistics and access on the parent file' do
        # Arrange / Assert (Expectation must be set before Act)
        expect_any_instance_of(Freereg1CsvFile).to receive(:update_statistics_and_access).with(true)

        # Act
        delete :destroy, params: { id: entry.id.to_s }
      end

      it 'redirects to the file view with a success notice' do
        # Act
        delete :destroy, params: { id: entry.id.to_s }

        # Assert
        expect(response).to redirect_to(freereg1_csv_file_path(file))
        expect(flash[:notice]).to eq('The deletion of the entry was successful and the batch is locked')
      end
    end

    context 'when an unexpected error occurs during deletion' do
      before do
        # Arrange: Force an error on the model to trigger rescue block
        allow_any_instance_of(Freereg1CsvEntry).to receive(:destroy).and_raise(StandardError, 'Database error')
      end

      it 'rescues the error, logs it, and redirects back gracefully' do
        # Arrange: Expect standard logger to receive an error
        expect(Rails.logger).to receive(:error).with(/Unexpected error deleting entry ID #{entry.id}/)

        # Act
        delete :destroy, params: { id: entry.id.to_s }

        # Assert
        expect(response).to redirect_to('http://test.host/manage_resources/new')
        expect(flash[:notice]).to eq('An unexpected error occurred while deleting the entry.')

        # Ensure entry was not actually deleted
        fresh_entry = Freereg1CsvEntry.find_by(id: entry.id)
        expect(fresh_entry).to be_present
      end
    end
  end
end
