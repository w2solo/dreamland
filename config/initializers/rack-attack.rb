# frozen_string_literal: true

BLOCK_MESSAGE = ["你请求过快，超过了频率限制，暂时屏蔽一段时间。"]
Rack::Attack.cache.store = Rails.cache

### Throttle Spammy Clients ###
Rack::Attack.throttle("req/ip",
  limit: ->(_req) { Setting.rack_attack_limit },
  period: ->(_req) { Setting.rack_attack_period }) do |req|
  req.ip if Setting.rack_attack_limit > 0
end

# 固定黑名单
Rack::Attack.blocklist("blacklist/ip") do |req|
  ips = Setting.blacklist_ips
  ips.present? && !ips.index(req.ip).nil?
end

# 允许 localhost
# Rack::Attack.safelist("allow from localhost") do |req|
#   req.ip == "127.0.0.1" || req.ip == "::1"
# end

### Custom Throttle Response ###
Rack::Attack.throttled_response = lambda do |env|
  [503, {}, BLOCK_MESSAGE]
end

ActiveSupport::Notifications.subscribe("track.rack_attack") do |name, start, finish, request_id, payload|
  req = payload[:request]
  Rails.logger.info "  RackAttack: #{req.ip} #{request_id} blocked."
end
