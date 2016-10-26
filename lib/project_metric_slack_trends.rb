require 'slack'
require 'rasem'

class ProjectMetricSlackTrends

  attr_reader :raw_data

  def initialize credentials, raw_data = nil
    @raw_data = raw_data
    @channel = credentials[:channel]
    @client = Slack::Web::Client.new(token: credentials[:token])
    Time.zone = 'UTC'
  end

  def refresh
    @raw_data = get_slack_trends_raw_data
    @score = @scores = @image = nil
    true
  end

  def score
    refresh unless @raw_data
    @scores ||= calculate_scores
    @score ||= @scores["week_one"]
  end

  def raw_data= new
    @raw_data = new
    @score = @scores = @image = nil
  end

  def image
    refresh unless @raw_data
    @score = calculate_scores["week_one"] unless @scores && @score

    max_y = 15
    min_y = 95
    y_positions = calculate_positions_of_scores_on_graph(max_y, min_y)

    unless @image
      image = Rasem::SVGImage.new(120, 100) do
        group :class => "grid y-grid" do
          line(20, 0, 20, 95)
        end
        group :class => "grid x-grid" do
          line(20, 95, 120, 95)
        end
        group do
          text 0, max_y, "100", "font-size" => "10px"
          text 0, 35, "75", "font-size" => "10px"
          text 0, 55, "50", "font-size" => "10px"
          text 0, 75, "25", "font-size" => "10px"
          text 0, min_y, "0", "font-size" => "10px"
        end
        group do
          circle 25, y_positions[0], 4, "fill" => "green"
          line(25, y_positions[0], 70, y_positions[1])
          circle 70, y_positions[1], 4, "fill" => "green"
          line(70, y_positions[1], 115, y_positions[2])
          circle 115, y_positions[2], 4, "fill" => "green"
        end
      end
      #File.open(File.join(File.dirname(__FILE__), 'sample.svg'), 'w'){|f| f.write image.output.lines.to_a[3..-1].join}
      return @image = image.output.lines.to_a[3..-1].join
    end
    #File.open(File.join(File.dirname(__FILE__), 'sample.svg'), 'w'){|f| f.write img.output.lines.to_a[3..-1].join}
    @image
  end

  def self.credentials
    [:token,:channel]
  end

  private

  def calculate_positions_of_scores_on_graph max_y, min_y
    y_positions = []
    y_positions.push(min_y-@scores["week_three"]*(min_y-max_y))
    y_positions.push(min_y-@scores["week_two"]*(min_y-max_y))
    y_positions.push(min_y-@scores["week_one"]*(min_y-max_y))
  end

  def calculate_scores
    @scores = {}
    participation_total = 20.to_f # Max score for rating participation (Based on Gini Coefficient)
    msg_frequency_total = 50.to_f # Max score for msg frequency (At least 3 msgs per day)
    num_messages_total = 30.to_f # Max score for total of messages sent
    num_message_threshhold = 100 # Number of messages need to get MAX num_messages_total
    total_points_possible = participation_total+msg_frequency_total+num_messages_total # Decided on "out of 100" for simplicity

    ["week_one", "week_two", "week_three"].each do |week|
      total_score = 0
      num_user_messages_array = @raw_data[week].select { |k, _| !["0", "1", "2", "3", "4", "5", "6"].include?(k) }.map { |_, v| v }
      num_messages_score = num_user_messages_array.reduce(:+)
      if num_messages_score >= num_message_threshhold # Rates the total amount messages
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
    @scores
  end

  def get_slack_trends_raw_data
    member_names = get_member_names_for_channel
    raw_data = {}
    (1..3).each do |week_number|
      raw_data[["week_one", "week_two", "week_three"][week_number-1]] = get_week_of_slack_data(week_number, member_names)
    end
    raw_data
  end

  def get_week_of_slack_data week_number, member_names
    start_date = (Time.zone.now - (7*week_number+Time.zone.now.wday+1).days).to_date
    end_date = (Time.zone.now - (7*(week_number-1)+Time.zone.now.wday).days).to_date
    member_names_by_id = get_member_names_by_id
    id = @client.channels_list['channels'].detect { |c| c['name'] == @channel }.id
    history = @client.channels_history(channel: id, count: 1000)
    slack_message_totals = history.messages.inject(Hash.new(0)) do |slack_message_totals, message|
      add_to_total = 0
      add_to_total = 1 if start_date < Time.at(message.ts.to_i).utc.to_date && Time.at(message.ts.to_i).utc.to_date < end_date
      slack_message_totals.merge member_names_by_id[message.user] => (slack_message_totals[member_names_by_id[message.user]]||0) + add_to_total
    end
    (1..7).each do |day_of_week|
      day = (Time.zone.now - (7*(week_number-1)+Time.zone.now.wday+day_of_week).days).to_date
      slack_message_totals[(day_of_week-1).to_s] = history.messages.select{|message| Time.at(message.ts.to_i).utc.to_date == day}.length
    end
    slack_message_totals
  end

  def get_member_names_for_channel
    members = @client.channels_list['channels'].detect { |c| c['name']== @channel }.members
    @client.users_list.members.select { |u| members.include? u.id }.map { |u| u.name }
  end

  def get_member_names_by_id
    members = @client.users_list.members
    members.inject({}) do |collection, member|
      collection.merge member.id => member.name
    end
  end

  def gini_coefficient(array)
    return 0.0 if array.all? { |v| v == 0 }
    sorted = array.sort
    temp = 0.0
    n = sorted.length
    array_sum = array.inject(0) { |sum, x| sum + x }
    (0..(n-1)).each do |i|
      temp += (n-i)*sorted[i]
    end
    return (n+1).to_f/ n - 2.0 * temp / ((array_sum)* n)
  end
end