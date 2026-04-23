# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageTemplate, type: :model do
  describe '#serialized' do
    let(:template) do
      described_class.new(
        name: 'ini_conversa',
        content: 'Olá, tudo bem?',
        language: 'pt_BR',
        category: 'UTILITY',
        template_type: 'text',
        components: [{ 'text' => 'Olá, tudo bem?', 'type' => 'BODY' }],
        variables: [],
        active: true
      )
    end

    it 'mirrors settings.status as a top-level status key when present' do
      template.settings = { 'status' => 'APPROVED' }
      expect(template.serialized['status']).to eq('APPROVED')
    end

    it 'returns nil for top-level status when settings is empty' do
      template.settings = {}
      expect(template.serialized).to have_key('status')
      expect(template.serialized['status']).to be_nil
    end

    it 'returns nil for top-level status when settings lacks the status key' do
      template.settings = { 'quality_score' => 'HIGH' }
      expect(template.serialized['status']).to be_nil
    end

    it 'does not raise when settings itself is nil' do
      template.settings = nil
      expect { template.serialized }.not_to raise_error
      expect(template.serialized['status']).to be_nil
    end

    it 'does not raise when settings is not a Hash (defensive guard)' do
      template.settings = 'malformed'
      expect { template.serialized }.not_to raise_error
      expect(template.serialized['status']).to be_nil
    end

    it 'still exposes the full settings hash alongside the mirrored status' do
      template.settings = { 'status' => 'PENDING', 'source' => 'meta_api' }
      serialized = template.serialized
      expect(serialized['status']).to eq('PENDING')
      expect(serialized['settings']).to eq({ 'status' => 'PENDING', 'source' => 'meta_api' })
    end
  end
end
