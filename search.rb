require 'rakuten_web_service'
require 'aws-record'

class Duration
  include Aws::Record
  integer_attr :golf_course_id, hash_key: true
  integer_attr :duration1
  integer_attr :duration2
  integer_attr :duration3
  integer_attr :duration4
  integer_attr :duration5
  integer_attr :prefecture
end

def lambda_handler(event:, context:)
  date = event['date'].to_s
  budget = event['budget']
  departure = event['departure']
  duration = event['duration']

  date = date.insert(4, '-').insert(7, '-') # GORAで必要な形に直してる

  RakutenWebService.configure do |c|
    c.application_id = ENV['RAKUTEN_APPID']
    c.affiliate_id = ENV['RAKUTEN_AFID']
  end

  matched_plans = []
  1.upto(2) do |page| # API Gatewayが30秒でタイムアウトするからそれのギリギリの2ページまでにしてる(1ページ30件)
    plans = RakutenWebService::Gora::Plan.search(page: page, maxPrice: budget, playDate: date, areaCode: '8,11,12,13,14', NGPlan: 'planHalfRound,planLesson,planOpenCompe,planRegularCompe')

    plans.each do |plan|
      next if plan['golfCourseName'] =~ /.*(レッスン|ショート|7ホール|ナイター).*/ # 不要そうな文字が入ってたらスキップ
      plan_duration = Duration.find(golf_course_id: plan['golfCourseId']).send("duration#{departure}")
      next if plan_duration > duration # 希望の所要時間より長いものの場合はスキップ
      matched_plans.push(
        {
          name: plan['golfCourseName'],
          caption: plan['golfCourseCaption'],
          prefecture: plan['prefecture'],
          image_url: plan['golfCourseImageUrl'],
          evaluation: plan['evaluation'],
          plan_name: plan['planInfo'][0]['planName'],
          price: plan['planInfo'][0]['price'],
          duration: plan_duration,
          reserve_url_pc: plan['planInfo'][0]['callInfo']['reservePageUrlPC'],
          reserve_url_mobile: plan['planInfo'][0]['callInfo']['reservePageUrlMobile'],
        }
      )
    end

    break unless plans.has_next_page?
  end

  matched_plans.sort_by! {|plan| plan[:duration]}

  {
    count: matched_plans.count,
    plans: matched_plans
  }
end
