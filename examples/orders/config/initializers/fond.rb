Fond.configure do |config|
  config.ssr_url = ENV["FOND_SSR_URL"] if ENV["FOND_SSR_URL"].present?
end
