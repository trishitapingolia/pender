module MediaFacebookEngagementMetrics
  extend ActiveSupport::Concern

  included do
    Media.declare_metrics('facebook')
  end

  def get_metrics_from_facebook
    self.class.get_metrics_from_facebook(self.original_url, ApiKey.current&.id, 0)
  end

  module ClassMethods
    def request_metrics_from_facebook(url, count = 0)
      facebook = PenderConfig.get('facebook', {})
      api = "https://graph.facebook.com/oauth/access_token?client_id=#{facebook.dig('app_id')}&client_secret=#{facebook.dig('app_secret')}&grant_type=client_credentials"
      response = Net::HTTP.get_response(URI(api))
      return unless verify_facebook_metrics_response(url, response, count)
      token = JSON.parse(response.body)['access_token']
      api = "https://graph.facebook.com/?id=#{url}&fields=engagement&access_token=#{token}"
      response = Net::HTTP.get_response(URI(URI.encode(api)))
      return unless verify_facebook_metrics_response(url, response, count)
      JSON.parse(response.body)['engagement']
    end

    def get_metrics_from_facebook(url, key_id, count)
      ApiKey.current = ApiKey.find_by(id: key_id)
      value = {}
      begin
        value = self.request_metrics_from_facebook(url, count)
      rescue StandardError => e
        PenderAirbrake.notify(e, url: url)
      end
      Media.notify_webhook_and_update_metrics_cache(url, 'facebook', value, key_id)
      self.delay_for(24.hours).get_metrics_from_facebook(url, key_id, count + 1) if count < 10 && value
    end

    def verify_facebook_metrics_response(url, response, count)
      return true if response.code.to_i == 200
      error = JSON.parse(response.body)['error']
      unless fb_metrics_permanent_error?(url, error)
        self.delay_for(1.hour).get_metrics_from_facebook(url, ApiKey.current&.id, count) if error['code'].to_i == 4 # Error code for 'Application request limit reached'
        PenderAirbrake.notify("Facebook metrics: #{error.dig('message')}", url: url, key_id: ApiKey.current&.id, error_code: response.code, error_message: response.message, error_body: error)
      end
      false
    end

    def fb_metrics_permanent_error?(url, response_error)
      permanent_error = {
        10 => 'Requires Facebook page permissions',
        100 => 'Unsupported get request. Facebook object ID does not support this operation',
        803 => 'The Facebook object ID is not correct or invalid'
      }.dig(response_error['code'].to_i)
      return unless permanent_error
      Rails.logger.warn level: 'WARN', message: "[Parser] Facebook metrics error: #{permanent_error}", url: url, key_id: ApiKey.current&.id, error: response_error
      true
    end
  end
end
