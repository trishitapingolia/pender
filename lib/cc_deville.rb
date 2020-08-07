class CcDeville
  def self.clear_cache_for_url(url)
    cloudflare = PenderConfig.get('cloudflare')
    if cloudflare['auth_email']
      # https://api.cloudflare.com/#zone-purge-files-by-url
      uri = URI("https://api.cloudflare.com/client/v4/zones/#{cloudflare['zone']}/purge_cache")
      req = Net::HTTP::Post.new(uri.path)
      req['X-Auth-Email'] = cloudflare['auth_email']
      req['X-Auth-Key'] = cloudflare['auth_key']
      req['Content-Type'] = 'application/json'
      req.body = {
        'files': [url]
      }.to_json
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == 'https'
      begin
        res = JSON.parse(http.request(req).body)
        raise StandardError.new "#{res['errors'][0]['code']} #{res['errors'][0]['message']}" if !res['success']
      rescue StandardError => e
        Rails.logger.error "[Cloudflare] #{e.message}"
        Airbrake.notify(e, params: { url: url }) if Airbrake.configured?
      end
    end
  end
end
