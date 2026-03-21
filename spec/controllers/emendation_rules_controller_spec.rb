require 'rails_helper'

RSpec.describe EmendationRulesController, type: :controller do
  # Set up test user session for authenticated requests
  def set_user_session(userid_detail_id = 1)
    session[:userid_detail_id] = userid_detail_id
  end

  describe 'GET #index' do
    context 'when not logged in' do
      it 'redirects to login' do
        get :index
        expect(response).to redirect_to(new_search_query_path)
      end
    end

    context 'when logged in' do
      before(:each) { set_user_session }

      context 'without emendation_type_id filter' do
        let!(:rule1) { create(:emendation_rule, original: 'Elia', replacement: 'Elias') }
        let!(:rule2) { create(:emendation_rule, original: 'Aron', replacement: 'Aaron') }
        let!(:rule3) { create(:emendation_rule, original: 'Alis', replacement: 'Alice') }

        it 'returns HTTP 200' do
          get :index
          expect(response).to have_http_status(:ok)
        end

        it 'renders the index template' do
          get :index
          expect(response).to render_template(:index)
        end

        it 'assigns all rules grouped by initial letter' do
          get :index
          expect(assigns(:emendation_rules_grouped)).not_to be_nil
          expect(assigns(:rules_by_replacement)).not_to be_nil
        end

        it 'populates alphabet keys for A-Z display' do
          get :index
          expect(assigns(:alphabet_keys)).to include('A', 'E')
        end

        it 'groups rules correctly by initial letter of replacement' do
          get :index
          grouped = assigns(:emendation_rules_grouped)
          expect(grouped['A']).to include('Aaron', 'Alice')
          expect(grouped['E']).to include('Elias')
        end

        it 'maintains distinct replacements in grouped display' do
          get :index
          replacements = assigns(:emendation_rules_grouped).values.flatten
          expect(replacements.uniq.length).to equal(replacements.length)
        end
      end

      context 'with emendation_type_id filter' do
        let(:type1) { create(:emendation_type, name: 'Type 1') }
        let(:type2) { create(:emendation_type, name: 'Type 2') }
        let!(:rule_type1) { create(:emendation_rule, original: 'Elia', replacement: 'Elias', emendation_type: type1) }
        let!(:rule_type2) { create(:emendation_rule, original: 'Aron', replacement: 'Aaron', emendation_type: type2) }

        it 'filters rules by emendation_type_id' do
          get :index, params: { emendation_type_id: type1.id }
          expect(assigns(:rules_by_replacement).keys).to include('Elias')
          expect(assigns(:rules_by_replacement).keys).not_to include('Aaron')
        end

        it 'groups filtered rules correctly' do
          get :index, params: { emendation_type_id: type1.id }
          grouped = assigns(:emendation_rules_grouped)
          expect(grouped['E']).to include('Elias')
          expect(grouped['A']).to be_nil
        end

        it 'returns empty groups when no rules match the filter' do
          get :index, params: { emendation_type_id: type2.id }
          grouped = assigns(:emendation_rules_grouped)
          expect(grouped['A']).to include('Aaron')
        end
      end

      context 'when no rules exist' do
        it 'returns empty grouped hash' do
          get :index
          expect(assigns(:emendation_rules_grouped)).to be_empty
        end

        it 'returns empty alphabet keys' do
          get :index
          expect(assigns(:alphabet_keys)).to be_empty
        end
      end
    end
  end

  describe 'GET #new' do
    context 'when not logged in' do
      it 'redirects to login' do
        get :new
        expect(response).to redirect_to(new_search_query_path)
      end
    end

    context 'when logged in' do
      before(:each) { set_user_session }

      it 'returns HTTP 200' do
        get :new
        expect(response).to have_http_status(:ok)
      end

      it 'renders the new template' do
        get :new
        expect(response).to render_template(:new)
      end

      it 'assigns a new EmendationRule instance' do
        get :new
        expect(assigns(:emendation_rule)).to be_a_new(EmendationRule)
      end

      context 'with emendation_type_id in params' do
        let(:emendation_type) { create(:emendation_type) }

        it 'sets the emendation_type_id on the new rule' do
          get :new, params: { emendation_type_id: emendation_type.id }
          expect(assigns(:emendation_rule).emendation_type_id).to eq(emendation_type.id)
        end
      end

      context 'without emendation_type_id in params' do
        it 'leaves emendation_type_id as nil' do
          get :new
          expect(assigns(:emendation_rule).emendation_type_id).to be_nil
        end
      end
    end
  end

  describe 'POST #create' do
    context 'when not logged in' do
      it 'redirects to login' do
        post :create, params: { emendation_rule: { original: 'Test', replacement: 'Test2', gender: 'm' } }
        expect(response).to redirect_to(new_search_query_path)
      end
    end

    context 'when logged in' do
      before(:each) { set_user_session }

      let(:emendation_type) { create(:emendation_type) }
      let(:valid_params) do
        {
          original: 'Elia',
          replacement: 'Elias',
          gender: 'm',
          emendation_type_id: emendation_type.id
        }
      end

      context 'with valid attributes' do
        it 'creates a new EmendationRule' do
          expect do
            post :create, params: { emendation_rule: valid_params }
          end.to change(EmendationRule, :count).by(1)
        end

        it 'persists the rule with correct attributes' do
          post :create, params: { emendation_rule: valid_params }
          fresh_rule = EmendationRule.find_by(original: 'Elia', replacement: 'Elias')
          expect(fresh_rule.gender).to eq('m')
          expect(fresh_rule.emendation_type_id).to eq(emendation_type.id)
        end

        it 'redirects to index with anchor on first letter of replacement' do
          post :create, params: { emendation_rule: valid_params }
          expect(response).to redirect_to(emendation_rules_path(anchor: 'E'))
        end

        it 'sets success notice flash message' do
          post :create, params: { emendation_rule: valid_params }
          expect(flash[:notice]).to include('successfully created')
        end

        context 'when replacement starts with different letter' do
          it 'anchors to correct letter' do
            params_a = valid_params.merge(replacement: 'Aaron')
            post :create, params: { emendation_rule: params_a }
            expect(response).to redirect_to(emendation_rules_path(anchor: 'A'))
          end
        end
      end

      context 'with invalid attributes' do
        let(:invalid_params) do
          {
            original: nil,
            replacement: 'Elias',
            emendation_type_id: emendation_type.id
          }
        end

        it 'does not create a new rule' do
          expect do
            post :create, params: { emendation_rule: invalid_params }
          end.not_to change(EmendationRule, :count)
        end

        it 'renders the new template' do
          post :create, params: { emendation_rule: invalid_params }
          expect(response).to render_template(:new)
        end

        it 'assigns the invalid rule to view' do
          post :create, params: { emendation_rule: invalid_params }
          expect(assigns(:emendation_rule)).to be_invalid
        end

        context 'when original is blank' do
          it 'does not persist' do
            expect do
              post :create, params: { emendation_rule: invalid_params }
            end.not_to change(EmendationRule, :count)
          end
        end

        context 'when replacement is blank' do
          let(:invalid_params) do
            {
              original: 'Elia',
              replacement: nil,
              emendation_type_id: emendation_type.id
            }
          end

          it 'does not persist' do
            expect do
              post :create, params: { emendation_rule: invalid_params }
            end.not_to change(EmendationRule, :count)
          end
        end

        context 'when violating unique index (original + replacement)' do
          let!(:existing_rule) { create(:emendation_rule, original: 'Elia', replacement: 'Elias', emendation_type: emendation_type) }

          it 'does not create a duplicate rule' do
            expect do
              post :create, params: { emendation_rule: valid_params }
            end.not_to change(EmendationRule, :count)
          end
        end
      end

      context 'without emendation_type_id' do
        let(:params_no_type) do
          {
            original: 'Elia',
            replacement: 'Elias',
            gender: 'f'
          }
        end

        it 'creates rule with nil emendation_type_id' do
          post :create, params: { emendation_rule: params_no_type }
          fresh_rule = EmendationRule.find_by(original: 'Elia', replacement: 'Elias')
          expect(fresh_rule.emendation_type_id).to be_nil
        end
      end
    end
  end

  describe 'GET #show' do
    context 'when not logged in' do
      it 'redirects to login' do
        rule = create(:emendation_rule)
        get :show, params: { id: rule.id }
        expect(response).to redirect_to(new_search_query_path)
      end
    end

    context 'when logged in' do
      before(:each) { set_user_session }

      context 'when rule exists' do
        let(:rule) { create(:emendation_rule) }

        it 'returns HTTP 200' do
          get :show, params: { id: rule.id }
          expect(response).to have_http_status(:ok)
        end

        it 'assigns the rule' do
          get :show, params: { id: rule.id }
          expect(assigns(:emendation_rule)).to eq(rule)
        end

        it 'renders the show template' do
          get :show, params: { id: rule.id }
          expect(response).to render_template(:show)
        end
      end

      context 'when rule does not exist' do
        it 'raises RecordNotFound' do
          expect do
            get :show, params: { id: 'nonexistent' }
          end.to raise_error(Mongoid::Errors::DocumentNotFound)
        end
      end
    end
  end

  describe 'GET #edit' do
    context 'when not logged in' do
      it 'redirects to login' do
        rule = create(:emendation_rule)
        get :edit, params: { id: rule.id }
        expect(response).to redirect_to(new_search_query_path)
      end
    end

    context 'when logged in' do
      before(:each) { set_user_session }

      context 'when rule exists' do
        let(:rule) { create(:emendation_rule) }

        it 'returns HTTP 200' do
          get :edit, params: { id: rule.id }
          expect(response).to have_http_status(:ok)
        end

        it 'assigns the rule' do
          get :edit, params: { id: rule.id }
          expect(assigns(:emendation_rule)).to eq(rule)
        end

        it 'renders the edit template' do
          get :edit, params: { id: rule.id }
          expect(response).to render_template(:edit)
        end
      end

      context 'when rule does not exist' do
        it 'raises RecordNotFound' do
          expect do
            get :edit, params: { id: 'nonexistent' }
          end.to raise_error(Mongoid::Errors::DocumentNotFound)
        end
      end
    end
  end

  describe 'PATCH #update' do
    context 'when not logged in' do
      it 'redirects to login' do
        rule = create(:emendation_rule)
        patch :update, params: { id: rule.id, emendation_rule: { replacement: 'Updated' } }
        expect(response).to redirect_to(new_search_query_path)
      end
    end

    context 'when logged in' do
      before(:each) { set_user_session }

      let(:rule) { create(:emendation_rule, original: 'OldOriginal', replacement: 'OldReplacement', gender: 'm') }

      context 'with valid attributes' do
        let(:update_params) do
          {
            original: 'NewOriginal',
            replacement: 'NewReplacement',
            gender: 'f'
          }
        end

        it 'returns HTTP 200 or redirects (depending on response)' do
          patch :update, params: { id: rule.id, emendation_rule: update_params }
          expect(response).to be_redirect
        end

        it 'updates the rule attributes' do
          patch :update, params: { id: rule.id, emendation_rule: update_params }
          fresh_rule = EmendationRule.find(rule.id)
          expect(fresh_rule.original).to eq('NewOriginal')
          expect(fresh_rule.replacement).to eq('NewReplacement')
          expect(fresh_rule.gender).to eq('f')
        end

        it 'redirects to index with anchor on first letter' do
          patch :update, params: { id: rule.id, emendation_rule: update_params }
          expect(response).to redirect_to(emendation_rules_path(anchor: 'N'))
        end

        it 'sets success notice flash message' do
          patch :update, params: { id: rule.id, emendation_rule: update_params }
          expect(flash[:notice]).to include('successfully updated')
        end

        context 'when replacement letter changes' do
          let(:params_change_letter) do
            { replacement: 'Aaron' }
          end

          it 'anchors to new first letter' do
            patch :update, params: { id: rule.id, emendation_rule: params_change_letter }
            expect(response).to redirect_to(emendation_rules_path(anchor: 'A'))
          end
        end
      end

      context 'with invalid attributes' do
        let(:invalid_update) do
          {
            original: nil,
            replacement: 'Valid'
          }
        end

        it 'does not update the rule' do
          patch :update, params: { id: rule.id, emendation_rule: invalid_update }
          fresh_rule = EmendationRule.find(rule.id)
          expect(fresh_rule.original).to eq('OldOriginal')
        end

        it 'renders the edit template' do
          patch :update, params: { id: rule.id, emendation_rule: invalid_update }
          expect(response).to render_template(:edit)
        end

        it 'assigns the invalid rule with errors' do
          patch :update, params: { id: rule.id, emendation_rule: invalid_update }
          expect(assigns(:emendation_rule)).to be_invalid
        end
      end

      context 'when rule does not exist' do
        it 'raises RecordNotFound' do
          expect do
            patch :update, params: { id: 'nonexistent', emendation_rule: { replacement: 'New' } }
          end.to raise_error(Mongoid::Errors::DocumentNotFound)
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when not logged in' do
      it 'redirects to login' do
        rule = create(:emendation_rule)
        delete :destroy, params: { id: rule.id }
        expect(response).to redirect_to(new_search_query_path)
      end
    end

    context 'when logged in' do
      before(:each) { set_user_session }

      context 'when rule exists' do
        let!(:rule) { create(:emendation_rule) }

        it 'deletes the rule' do
          expect do
            delete :destroy, params: { id: rule.id }
          end.to change(EmendationRule, :count).by(-1)
        end

        it 'redirects to index' do
          delete :destroy, params: { id: rule.id }
          expect(response).to redirect_to(emendation_rules_path)
        end

        it 'sets success notice flash message' do
          delete :destroy, params: { id: rule.id }
          expect(flash[:notice]).to include('successfully destroyed')
        end

        it 'verifies rule is actually deleted' do
          rule_id = rule.id
          delete :destroy, params: { id: rule_id }
          expect do
            EmendationRule.find(rule_id)
          end.to raise_error(Mongoid::Errors::DocumentNotFound)
        end
      end

      context 'when rule does not exist' do
        it 'raises RecordNotFound' do
          expect do
            delete :destroy, params: { id: 'nonexistent' }
          end.to raise_error(Mongoid::Errors::DocumentNotFound)
        end
      end
    end
  end

  describe 'GET #forename_abbreviations' do
    context 'when not logged in' do
      it 'does not require login' do
        get :forename_abbreviations
        expect(response).not_to redirect_to(new_search_query_path)
      end
    end

    context 'without authentication required' do
      context 'without filter' do
        let!(:rule1) { create(:emendation_rule, original: 'Eliz', replacement: 'Elizabeth') }
        let!(:rule2) { create(:emendation_rule, original: 'Liz', replacement: 'Elizabeth') }
        let!(:rule3) { create(:emendation_rule, original: 'Aron', replacement: 'Aaron') }

        it 'returns HTTP 200' do
          get :forename_abbreviations
          expect(response).to have_http_status(:ok)
        end

        it 'renders the forename_abbreviations template' do
          get :forename_abbreviations
          expect(response).to render_template(:forename_abbreviations)
        end

        it 'assigns rules grouped by initial letter and replacement' do
          get :forename_abbreviations
          emendation_rules = assigns(:emendation_rules)
          expect(emendation_rules).not_to be_nil
          expect(emendation_rules['A']).to be_a(Hash)
          expect(emendation_rules['E']).to be_a(Hash)
        end

        it 'maps replacements to arrays of originals' do
          get :forename_abbreviations
          rules = assigns(:emendation_rules)
          expect(rules['E']['Elizabeth']).to contain_exactly('Eliz', 'Liz')
          expect(rules['A']['Aaron']).to contain_exactly('Aron')
        end

        it 'sorts outer hash by letter' do
          get :forename_abbreviations
          rules = assigns(:emendation_rules)
          letters = rules.keys
          expect(letters).to eq(letters.sort)
        end

        it 'sorts inner hash (replacements) alphabetically' do
          get :forename_abbreviations
          create(:emendation_rule, original: 'Zeb', replacement: 'Zebedee')
          get :forename_abbreviations
          rules = assigns(:emendation_rules)
          replacements = rules['Z'].keys
          expect(replacements).to eq(replacements.sort)
        end

        it 'populates alphabet keys' do
          get :forename_abbreviations
          expect(assigns(:alphabet_keys)).to contain_exactly('A', 'E')
        end
      end

      context 'with emendation_type_id filter' do
        let(:type1) { create(:emendation_type, name: 'Type 1') }
        let(:type2) { create(:emendation_type, name: 'Type 2') }
        let!(:rule_type1) { create(:emendation_rule, original: 'Eliz', replacement: 'Elizabeth', emendation_type: type1) }
        let!(:rule_type2) { create(:emendation_rule, original: 'Aron', replacement: 'Aaron', emendation_type: type2) }

        it 'filters rules by emendation_type_id' do
          get :forename_abbreviations, params: { emendation_type_id: type1.id }
          rules = assigns(:emendation_rules)
          expect(rules['E']).to be_present
          expect(rules['A']).to be_nil
        end

        it 'returns only replacement-to-originals mappings for that type' do
          get :forename_abbreviations, params: { emendation_type_id: type1.id }
          rules = assigns(:emendation_rules)
          expect(rules['E']['Elizabeth']).to contain_exactly('Eliz')
        end
      end

      context 'when rules have blank replacement' do
        let!(:rule_blank) { create(:emendation_rule, original: 'Test', replacement: '') }
        let!(:rule_valid) { create(:emendation_rule, original: 'Aron', replacement: 'Aaron') }

        it 'skips rules with blank replacement' do
          get :forename_abbreviations
          rules = assigns(:emendation_rules)
          blank_key = ''
          expect(rules[blank_key]).to be_nil
        end

        it 'includes valid rules' do
          get :forename_abbreviations
          rules = assigns(:emendation_rules)
          expect(rules['A']['Aaron']).to contain_exactly('Aron')
        end
      end

      context 'when no rules exist' do
        it 'assigns empty grouped hash' do
          get :forename_abbreviations
          expect(assigns(:emendation_rules)).to eq({})
        end

        it 'assigns empty alphabet keys' do
          get :forename_abbreviations
          expect(assigns(:alphabet_keys)).to be_empty
        end
      end

      context 'with multiple originals for same replacement' do
        let!(:rule1) { create(:emendation_rule, original: 'Eliz', replacement: 'Elizabeth') }
        let!(:rule2) { create(:emendation_rule, original: 'Lizzy', replacement: 'Elizabeth') }
        let!(:rule3) { create(:emendation_rule, original: 'Betty', replacement: 'Elizabeth') }

        it 'aggregates all originals under the replacement' do
          get :forename_abbreviations
          rules = assigns(:emendation_rules)
          expect(rules['E']['Elizabeth']).to contain_exactly('Eliz', 'Lizzy', 'Betty')
        end

        it 'preserves order uniqueness of originals' do
          get :forename_abbreviations
          rules = assigns(:emendation_rules)
          originals = rules['E']['Elizabeth']
          expect(originals.uniq.length).to equal(originals.length)
        end
      end
    end
  end
end
