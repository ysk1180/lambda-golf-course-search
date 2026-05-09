require 'net/http'
require 'uri'
require 'json'

# 楽天ウェブサービス GORA系API のクライアント。
# 2026年の楽天APIインフラ移行（openapi.rakuten.co.jp / accessKeyヘッダ / Origin・Referer必須）
# に対応するため、rakuten_web_service gem から自前実装に切替。
#
# このLambdaではPlan Search のみ利用する。
class RakutenGoraAPIService
  class Error < StandardError; end
  class NotFound < Error; end
  class ServiceUnavailable < Error; end

  # 楽天 Allowed websites に登録したドメインと一致させる必要がある
  REFERER = 'https://rakuraku-golf.com/'.freeze

  class << self
    # 旧: RakutenWebService::Gora::Plan.search(...)
    # 任意のクエリパラメータをそのままAPIに渡す
    def search_plans(**params)
      PaginatedResult.new(client.get('GoraPlanSearch/20170623', **params))
    end

    private

    def client
      @client ||= Client.new(
        application_id: ENV.fetch('RWS_APPLICATION_ID'),
        access_key: ENV.fetch('RWS_ACCESS_KEY'),
        affiliate_id: ENV['RWS_AFFILIATE_ID'],
        referer: REFERER
      )
    end
  end

  # rakuten_web_service gem 互換の薄いページネーション結果ラッパー
  # search.rb 側で each / has_next_page? を使っているのでそれを満たす
  class PaginatedResult
    include Enumerable

    def initialize(raw)
      @raw = raw
      @items = raw['Items'] || []
    end

    def each(&block)
      @items.each(&block)
    end

    def first
      @items.first
    end

    def has_next_page?
      @raw['page'].to_i < @raw['pageCount'].to_i
    end
  end

  class Client
    BASE_URL = 'https://openapi.rakuten.co.jp/engine/api/Gora'.freeze

    def initialize(application_id:, access_key:, affiliate_id:, referer:)
      @application_id = application_id
      @access_key = access_key
      @affiliate_id = affiliate_id
      @referer = referer
    end

    def get(path, **params)
      uri = URI("#{BASE_URL}/#{path}")
      uri.query = URI.encode_www_form(default_params.merge(params))

      request = Net::HTTP::Get.new(uri)
      request['accessKey'] = @access_key
      request['Origin'] = @referer.chomp('/')
      request['Referer'] = @referer

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.request(request)
      end

      handle_response(response)
    end

    private

    def default_params
      {
        applicationId: @application_id,
        affiliateId: @affiliate_id,
        format: 'json',
        formatVersion: 2
      }.compact
    end

    def handle_response(response)
      case response.code.to_i
      when 200
        JSON.parse(response.body)
      when 404
        raise NotFound, "Rakuten GORA API NotFound: #{response.body}"
      when 429, 503
        # 429(レート制限) と 503 はどちらも一時的なエラー
        raise ServiceUnavailable, "Rakuten GORA API ServiceUnavailable (#{response.code}): #{response.body}"
      else
        raise Error, "Rakuten GORA API error #{response.code}: #{response.body}"
      end
    end
  end
end
