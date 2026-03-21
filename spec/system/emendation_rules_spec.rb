require 'rails_helper'

RSpec.describe 'EmendationRules Workflows', type: :system do
  before { sign_in create(:userid_detail) }

  describe 'Create workflow' do
    it 'allows user to create rule and see it in list' do
      visit '/emendation_rules'
      expect(page).to have_text('Emendation Rules')

      click_link('New Rule', match: :first) if page.has_link?('New Rule')
      click_button('New') if page.has_button?('New')

      fill_in 'Original', with: 'Eliz'
      fill_in 'Replacement', with: 'Elizabeth'
      select 'm', from: 'Gender'

      click_button 'Create'

      expect(page).to have_text('successfully created')
      expect(page).to have_text('Elizabeth')
      expect(page).to have_text('Eliz') if page.has_xpath?("//td[text()='Eliz']")
    end

    it 'shows validation errors for invalid submission' do
      visit '/emendation_rules/new'

      fill_in 'Replacement', with: 'Elizabeth'
      click_button 'Create'

      expect(page).to have_text('can\'t be blank')
    end
  end

  describe 'Edit workflow' do
    it 'allows user to edit and see changes in list' do
      rule = create(:emendation_rule, original: 'Elia', replacement: 'Elias')

      visit '/emendation_rules'
      expect(page).to have_text('Elias')

      click_link('Edit', href: "/emendation_rules/#{rule.id}") if page.has_link?('Edit', href: "/emendation_rules/#{rule.id}")

      fill_in 'Original', with: 'Elie'
      click_button 'Update'

      expect(page).to have_text('successfully updated')
      expect(page).to have_text('Elie')
    end
  end

  describe 'Delete workflow' do
    it 'allows user to delete rule' do
      rule = create(:emendation_rule, original: 'Aron', replacement: 'Aaron')

      visit '/emendation_rules'
      expect(page).to have_text('Aaron')

      click_link('Delete', href: "/emendation_rules/#{rule.id}") if page.has_link?('Delete', href: "/emendation_rules/#{rule.id}")

      expect(page).to have_text('successfully destroyed')
      expect(page).not_to have_text('Aaron')
    end
  end

  describe 'Filter workflow' do
    it 'filters rules by type and displays correct alphabet' do
      type1 = create(:emendation_type, name: 'Type 1')
      type2 = create(:emendation_type, name: 'Type 2')
      create(:emendation_rule, original: 'Elia', replacement: 'Elias', emendation_type: type1)
      create(:emendation_rule, original: 'Aron', replacement: 'Aaron', emendation_type: type2)

      visit "/emendation_rules?emendation_type_id=#{type1.id}"

      expect(page).to have_text('Elias')
      expect(page).not_to have_text('Aaron')
    end
  end

  describe 'Public forename abbreviations page' do
    it 'displays grouped abbreviations without login' do
      sign_out
      rule1 = create(:emendation_rule, original: 'Eliz', replacement: 'Elizabeth')
      rule2 = create(:emendation_rule, original: 'Liz', replacement: 'Elizabeth')
      rule3 = create(:emendation_rule, original: 'Aron', replacement: 'Aaron')

      visit '/emendation_rules/forename_abbreviations'

      expect(page).to have_text('Elizabeth')
      expect(page).to have_text('Aaron')
    end
  end
end
