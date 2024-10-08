module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CloudpaymentsGateway < Gateway

      self.live_url             = 'https://api.tiptoppay.kz/'
      self.default_currency     = 'RUB'
      self.supported_countries  = ['RU', 'AT', 'BE', 'BG', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'GI', 'DE', 'GR', 'HU', 'IS', 'IM', 'IE', 'IT', 'LV', 'LI', 'LT', 'LU', 'MT', 'MC', 'NL', 'NO', 'PL', 'PT', 'RO', 'SM', 'SK', 'SI', 'ES', 'SE', 'CH', 'TR', 'GB']
      self.homepage_url         = 'http://tiptoppay.kz/'
      self.display_name         = 'TipTop Pay'
      self.supported_cardtypes  = [:visa, :master, :american_express, :diners_club, :jcb]

      def initialize(options = {})
        requires!(options, :public_id, :api_secret)
        super
      end

      def authorize(token, amount, options={}, with_crypto=false)
        if with_crypto
          options.merge!(:CardCryptogramPacket => token, :Amount => amount)
          commit("payments/cards/auth", options)
        else
          options.merge!(:Token => token, :Amount => amount)
          commit("payments/tokens/auth", options)
        end
      end

      def purchase(token, amount, options={}, with_crypto=false)
        if with_crypto
          options.merge!(:CardCryptogramPacket => token, :Amount => amount)
          commit("payments/cards/charge", options)
        else
          options.merge!(:Token => token, :Amount => amount)
          commit("payments/tokens/charge", options)
        end
      end

      def capture(amount, transaction_id)
        commit("payments/confirm", {:TransactionId => transaction_id, :Amount => amount})
      end

      def refund(amount, transaction_id)
        commit('payments/refund', {:TransactionId => transaction_id, :Amount => amount})
      end

      def void(transaction_id)
        commit('payments/void', {:TransactionId => transaction_id})
      end

      def subscribe(token, amount, options={})
        options.merge!(:Token => token, :Amount => amount)
        commit('subscriptions/create', options)
      end

      def get_subscription(subscription_id)
        commit('subscriptions/get', {:Id => subscription_id})
      end

      def void_subscription(subscription_id)
        commit('subscriptions/cancel', {:Id => subscription_id})
      end

      def update_subscription subscription_id, options={}
        options.merge!(:Id => subscription_id)
        commit('subscriptions/update', options)
      end

      def check_3ds(transaction_id, pa_res)
        commit('payments/post3ds', {:TransactionId => transaction_id, :PaRes => pa_res})
      end

      private

      def commit(path, parameters)
        parameters = parameters.present? ? parameters.to_query : nil
        response = parse(ssl_post(live_url + path, parameters, headers) )
        @model = response['Model']


        msg = if success?(response)
                'Transaction approved'
              else
                if response['Message'].blank?
                  if @model['CardHolderMessage'].present?
                    @model['CardHolderMessage']
                  elsif @model['Reason'].present?
                    @model['Reason']
                  elsif @model['PaReq'].present?
                    '3ds'
                  end
                else
                  response['Message']
                end
              end

        Response.new(success?(response),
          msg,
          @model,
          authorization: auth_from(response),
          test: test?
        )
      end

      def success?(response)
        response['Success']
      end

      def auth_from response
        if success?(response)
          @model.present? ? @model['TransactionId'] || @model['Id'] : ''
        else
          @model.present? ? @model['TransactionId'] : ''
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def message_from(message)
        return 'Unspecified error' if message.blank?
        message.gsub(/[^\w]/, ' ').split.join(" ").capitalize
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.strict_encode64("#{options[:public_id]}:#{options[:api_secret]}")
        }
      end

    end
  end
end