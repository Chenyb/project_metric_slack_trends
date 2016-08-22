require 'slack'
require 'rasem'

class ProjectMetricSlackTrends

  attr_reader :raw_data

  def initialize credentials
    @channel = credentials[:channel]
    @client = Slack::Web::Client.new(token: credentials[:token])
  end

  def refresh
    @raw_data = get_slack_trends_raw_data
    @score = @scores = nil
    true
  end

  def score
    refresh unless @raw_data
    calculate_scores
    @score = @scores["week_one"]
  end

  def image
    refresh unless @raw_data
    calculate_scores unless @scores && @score
    y_positions = []
    max_y = 10
    min_y = 90
    y_positions.push(min_y-@scores["week_three"]*(min_y-max_y))
    y_positions.push(min_y-@scores["week_two"]*(min_y-max_y))
    y_positions.push(min_y-@scores["week_one"]*(min_y-max_y))
    img = Rasem::SVGImage.new(120,110) do
      group :class => "grid y-grid" do
        line(20,0,20,90)
      end
      group :class => "grid x-grid" do
        line(20,90,100,90)
      end
      group do
        text 0,max_y,"100", "font-size" => "10px"
        text 0,30,"75","font-size" => "10px"
        text 0,50,"50","font-size" => "10px"
        text 0,70,"25","font-size" => "10px"
        text 0,min_y,"0", "font-size" => "10px"
      end
      group do
        circle 25,y_positions[0],4,"fill"=> "green"
        line(25,y_positions[0],70,y_positions[1])
        circle 70,y_positions[1],4,"fill"=> "green"
        line(70,y_positions[1],115,y_positions[2])
        circle 115,y_positions[2],4,"fill"=> "green"
      end
    end
    #File.open(File.join(File.dirname(__FILE__), 'sample.svg'), 'w'){|f| f.write img.output.lines.to_a[3..-1].join}

    img.output.lines.to_a[3..-1].join
  end

  private

  def calculate_scores
    @scores = {}
    participation_total = 20.to_f # Max score for rating participation (Based on Gini Coefficient)
    msg_frequency_total = 50.to_f # Max score for msg frequency (At least 3 msgs per day)
    num_messages_total = 30.to_f # Max score for total of messages sent
    num_message_threshhold = 100 # Number of messages need to get MAX num_messages_total
    total_points_possible = participation_total+msg_frequency_total+num_messages_total # Decided on "out of 100" for simplicity

    ["week_one", "week_two", "week_three"].each do |week|
      total_score = 0
      num_user_messages_array = @raw_data[week].select{|k,_| !["0","1","2","3","4","5","6"].include?(k)}.map{|_,v| v}
      num_messages_score = num_user_messages_array.reduce(:+)
      if num_messages_score >= num_message_threshhold  # Rates the total amount messages
        total_score += num_messages_total
      else
        total_score += num_messages_score*(participation_total/num_message_threshhold)
      end

      #Grade frequency of messages
      (0..6).each do |day_of_week|
        num_msgs_that_day = @raw_data[week][day_of_week.to_s]
        if num_msgs_that_day >= 3
          total_score += msg_frequency_total/7
        end
      end

      #Grade how equal were the messages distrubuted
      total_score += participation_total*(1-gini_coefficient(num_user_messages_array))

      total_score_normalized = (total_score.to_f/total_points_possible.to_f)
      if total_score_normalized > 1.0
        @scores[week] = 1.0
      else
        @scores[week] = total_score_normalized
      end
    end
  end

  def get_slack_trends_raw_data
    member_names = get_member_names_for_channel
    raw_data = {}
    (1..3).each do |week_number|
      raw_data[["week_one", "week_two", "week_three"][week_number-1]] = get_week_of_slack_data(week_number,member_names)
    end
    raw_data
  end

  def get_week_of_slack_data week_number, member_names
    start_time = (Time.now - (7*week_number+Time.now.wday+1).days).to_s[0,10]
    end_time = (Time.now - (7*(week_number-1)+Time.now.wday).days).to_s[0,10]
    slack_message_totals = member_names.inject({}) do |slack_message_totals, user_name|
      num_messages = @client.search_all(query: "from:#{user_name} after:#{start_time} before:#{end_time}").messages.matches.select { |m| m.channel.name == @channel }.length
      slack_message_totals.merge user_name => num_messages
    end
    (0..6).each do |day_of_week|
      day = (Time.now - (7*week_number+Time.now.wday+day_of_week).days).to_s[0,10]
      slack_message_totals[day_of_week.to_s] = @client.search_all(query: "on:#{day}").messages.matches.select { |m| m.channel.name == @channel }.length
    end
    slack_message_totals
  end

  def get_member_names_for_channel
    members = @client.channels_list['channels'].detect { |c| c['name']== @channel }.members
    @client.users_list.members.select { |u| members.include? u.id }.map { |u| u.name }
  end

  def gini_coefficient(array)
    sorted = array.sort
    temp = 0.0
    n = sorted.length
    array_sum = array.inject(0){|sum,x| sum + x }
    (0..(n-1)).each do |i|
      temp += (n-i)*sorted[i]
    end
    return (n+1).to_f/ n - 2.0 * temp / ((array_sum)*n)
  end
end