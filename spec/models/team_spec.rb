# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Team, type: :model do
  let(:account) { Account.create!(name: 'Test Account') }

  describe 'name casing preservation' do
    it 'preserves mixed-case name on create' do
      team = Team.create!(account: account, name: 'Marketing Team')
      expect(team.reload.name).to eq('Marketing Team')
    end

    it 'preserves uppercase name on create' do
      team = Team.create!(account: account, name: 'VIP SUPPORT')
      expect(team.reload.name).to eq('VIP SUPPORT')
    end

    it 'preserves mixed-case name on update' do
      team = Team.create!(account: account, name: 'old name')
      team.update!(name: 'New Team Name')
      expect(team.reload.name).to eq('New Team Name')
    end

    it 'strips whitespace but preserves casing' do
      team = Team.create!(account: account, name: '  Sales Team  ')
      expect(team.reload.name).to eq('Sales Team')
    end
  end

  describe 'case-insensitive uniqueness' do
    it 'rejects duplicate name with different casing in same account' do
      Team.create!(account: account, name: 'Support')
      duplicate = Team.new(account: account, name: 'support')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it 'allows same name in different accounts' do
      other_account = Account.create!(name: 'Other Account')
      Team.create!(account: account, name: 'Support')
      team = Team.new(account: other_account, name: 'Support')
      expect(team).to be_valid
    end
  end
end
