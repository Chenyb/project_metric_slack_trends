require 'project_metric_slack_trends'

describe ProjectMetricSlackTrends, :vcr do

  let(:raw_data) {{"week_one" => {"an_ju"=>0, "armandofox"=>0, "francis"=>0, "intfrr"=>0, "mtc2013"=>19, "tansaku"=>0,"0"=>0, "1"=>0, "2"=>0, "3"=>0, "4"=>1, "5"=>0, "6"=>0},
                   "week_three" => {"an_ju"=>0, "armandofox"=>10, "francis"=>0, "intfrr"=>0, "mtc2013"=>0, "tansaku"=>0,"0"=>0, "1"=>0, "2"=>0, "3"=>8, "4"=>0, "5"=>0, "6"=>0},
                   "week_two" => {"an_ju"=>0, "armandofox"=>5, "francis"=>0, "intfrr"=>0, "mtc2013"=>2, "tansaku"=>10,"0"=>1, "1"=>0, "2"=>0, "3"=>0, "4"=>5, "5"=>1, "6"=>0}}}
  context '#refresh' do
    it 'fetches raw data' do
      metric = ProjectMetricSlackTrends.new(channel: 'projectscope', token: ENV["SLACK_API_TOKEN"])
      metric.refresh
      expect(metric.raw_data).to eq(raw_data)
    end
  end

  context '#score' do
    it 'computes a score' do
      expect(ProjectMetricSlackTrends.new(channel: 'projectscope', token: ENV["SLACK_API_TOKEN"]).score).to eq 0.0713333333333333
    end
  end

end