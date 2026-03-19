# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account::ContactsExportJob, type: :job do
  let(:account) { Account.create!(name: 'Export Test Account') }

  before do
    account.contacts_export.attach(
      io: StringIO.new("id,name\n1,Test Contact"),
      filename: 'contacts.csv',
      content_type: 'text/csv'
    )
  end

  describe '#account_contact_export_url' do
    context 'when default_url_options has a host configured' do
      around do |example|
        original_url_options = Rails.application.routes.default_url_options.dup
        Rails.application.routes.default_url_options = {
          host: 'api.example.com',
          protocol: 'https',
          port: 443
        }
        example.run
      ensure
        Rails.application.routes.default_url_options = original_url_options
      end

      it 'builds a blob url with configured route host in background job context' do
        job = described_class.new
        job.instance_variable_set(:@account, account)

        file_url = job.send(:account_contact_export_url)

        expect(file_url).to start_with('https://api.example.com')
        expect(file_url).to include('/rails/active_storage')
      end
    end

    context 'when default_url_options has no host' do
      around do |example|
        original_url_options = Rails.application.routes.default_url_options.dup
        Rails.application.routes.default_url_options = {}
        example.run
      ensure
        Rails.application.routes.default_url_options = original_url_options
      end

      it 'raises an error instead of falling back to localhost' do
        job = described_class.new
        job.instance_variable_set(:@account, account)

        expect { job.send(:account_contact_export_url) }
          .to raise_error(RuntimeError, /Missing host in default_url_options/)
      end
    end
  end

  describe '#send_mail' do
    around do |example|
      original_url_options = Rails.application.routes.default_url_options.dup
      Rails.application.routes.default_url_options = {
        host: 'api.example.com',
        protocol: 'https',
        port: 443
      }
      example.run
    ensure
      Rails.application.routes.default_url_options = original_url_options
    end

    it 'invokes the mailer with the generated blob url' do
      user = User.create!(name: 'Export Test User', email: "export-test-#{SecureRandom.hex(4)}@example.com")
      AccountUser.create!(account: account, user: user)

      job = described_class.new
      job.instance_variable_set(:@account, account)
      job.instance_variable_set(:@account_user, user)

      mailer_instance = instance_double(AdministratorNotifications::AccountNotificationMailer)
      mail_message = instance_double(ActionMailer::MessageDelivery)

      allow(AdministratorNotifications::AccountNotificationMailer)
        .to receive(:with).with(account: account).and_return(mailer_instance)
      allow(mailer_instance)
        .to receive(:contact_export_complete).and_return(mail_message)
      allow(mail_message).to receive(:deliver_later)

      job.send(:send_mail)

      expect(mailer_instance).to have_received(:contact_export_complete) do |url, email|
        expect(url).to start_with('https://api.example.com')
        expect(url).to include('/rails/active_storage')
        expect(email).to eq(user.email)
      end
      expect(mail_message).to have_received(:deliver_later)
    end
  end
end
