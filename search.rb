require 'rakuten_web_service'

def lambda_handler(event:, context:)
  date = event['date'].to_s
  budget = event['budget']

  date = date.insert(4, '-').insert(7, '-')

  RakutenWebService.configure do |c|
    c.application_id = ENV['RAKUTEN_APPID']
    c.affiliate_id = ENV['RAKUTEN_AFID']
  end

  courses = RakutenWebService::Gora::Plan.search(maxPrice: budget, playDate: date, areaCode: '11,12,13,14', sort: 'evaluation', NGPlan: 'planHalfRound')

  matched_courses = []
  courses.each do |course|
    matched_courses.push(
      {
        name: course['golfCourseName'],
        caption: course['golfCourseCaption'],
        prefecture: course['prefecture'],
        image_url: course['golfCourseImageUrl'],
        evaluation: course['evaluation'],
        plan_name: course['planInfo'][0]['planName'],
        price: course['planInfo'][0]['price'],
        reserve_url_pc: course['planInfo'][0]['callInfo']['reservePageUrlPC'],
        reserve_url_mobile: course['planInfo'][0]['callInfo']['reservePageUrlMobile'],
      }
    )
  end

  { courses: matched_courses }
end
