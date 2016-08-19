require 'slack'

class ProjectMetricSlackTrends

  attr_reader :raw_data

  def initialize credentials
    @channel = credentials[:channel]
    @client = Slack::Web::Client.new(token: credentials[:token])
  end

  def refresh
    @raw_data = get_slack_trends_raw_data
    true
  end

  private

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
end