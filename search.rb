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

  matched_courses = []
  1.upto(2) do |page| # API Gatewayが30秒でタイムアウトするからそれのギリギリの2ページまでにしてる(1ページ30件)
    courses = RakutenWebService::Gora::Plan.search(page: page, maxPrice: budget, playDate: date, areaCode: '8,11,12,13,14', NGPlan: 'planHalfRound,planLesson,planOpenCompe,planRegularCompe')

    courses.each do |course|
      next if course['golfCourseName'] =~ /.*(レッスン|ショート|7ホール|ナイター).*/ # 不要そうな文字が入ってたらスキップ
      course_duration = Duration.find(golf_course_id: course['golfCourseId']).send("duration#{departure}")
      next if course_duration > duration # 希望の所要時間より長いものの場合はスキップ
      matched_courses.push(
        {
          name: course['golfCourseName'],
          caption: course['golfCourseCaption'],
          prefecture: course['prefecture'],
          image_url: course['golfCourseImageUrl'],
          evaluation: course['evaluation'],
          plan_name: course['planInfo'][0]['planName'],
          price: course['planInfo'][0]['price'],
          duration: course_duration,
          reserve_url_pc: course['planInfo'][0]['callInfo']['reservePageUrlPC'],
          reserve_url_mobile: course['planInfo'][0]['callInfo']['reservePageUrlMobile'],
        }
      )
    end

    break unless courses.has_next_page?
  end

  matched_courses.sort_by! {|course| course[:duration]}

  { courses: matched_courses }
end
