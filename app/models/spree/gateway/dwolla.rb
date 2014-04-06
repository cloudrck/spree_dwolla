require 'dwolla'
require 'money'
module Spree
  class Gateway::Dwolla < Gateway
    preference :dwolla_id, :string
    preference :key, :string
    preference :secret, :string
    preference :oauth_scope, :string, default: 'Send|Funding|AccountInfoFull'
    preference :default_funding_source, :string, default: 'Balance'
    preference :allow_funding_sources, :boolean, :default => false
    preference :allow_ach, :boolean, :default => false
    preference :your_oauth_token, :string
    preference :your_pin, :string
    preference :sandbox, :boolean, :default => false
    preference :enable_debug, :boolean, :default => false


    def supports?(source)
      true
    end

    def payment_profiles_supported?
      true
    end

    def auto_capture?
      true
    end

    def method_type
      'dwolla'
    end

    def provider_class
      ::Dwolla
    end

    def provider
      ::Dwolla::api_key = preferred_key
      ::Dwolla::api_secret = preferred_secret
      ::Dwolla::token = preferred_your_oauth_token
      ::Dwolla::scope = preferred_oauth_scope
      ::Dwolla::sandbox = preferred_sandbox
      ::Dwolla::debug = preferred_sandbox

      provider_class
    end

    def purchase(amount, dwolla_checkout, gateway_options={})
      begin
        order_id = gateway_options[:order_id].split('-')[0]
        payment_id = gateway_options[:order_id].split('-')[1]
        @payment = Spree::Payment.find_by_identifier(payment_id)
        #money = Money::new(amount, "USD")
        transaction_id = provider::Transactions.send(
          {
            :destinationId => preferred_dwolla_id,
            :amount => amount / 100.0, # amount is given in cents; expected in dollars
            :pin => dwolla_checkout.pin,
            :fundsSource => dwolla_checkout.funding_source_id,
            :notes => gateway_options[:order_id]
          }, dwolla_checkout.oauth_token)

        dwolla_checkout.update_column(:transaction_id, transaction_id)

        # Auto clear "instant" payments
        if dwolla_checkout.funding_source_id == 'Credit' or dwolla_checkout.funding_source_id == 'Balance'
          @payment.complete!
          @payment.log_entries.create(:details => "Instant-type Dwolla transaction. Payment marked as completed.")
        end

        ActiveMerchant::Billing::Response.new(
          true,
          Spree.t(:checkout_success, :scope => :dwolla)
        )
      rescue ::Dwolla::APIError => exception
        @payment.failure!

        @payment.log_entries.create(:details => "Oops. Something went wrong. Dwolla said: #{exception}")

        ActiveMerchant::Billing::Response.new(
          false,
          Spree.t(:checkout_failure, :scope => :dwolla),
          { :message => "Dwolla failed: #{exception}" }
        )
      rescue => exception
        @payment.log_entries.create(:details => "Oops. Something went wrong. Spree said: #{exception}")

        ActiveMerchant::Billing::Response.new(
          false,
          Spree.t(:checkout_failure, :scope => :dwolla),
          { :message => "Something went wrong: #{exception}" }
        )
      end
    end
  end
end
