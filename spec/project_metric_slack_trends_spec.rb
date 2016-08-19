require 'project_metric_slack_trends'

describe ProjectMetricSlackTrends, :vcr do

  let(:raw_data) {{"week_one" => {"an_ju"=>0, "armandofox"=>0, "francis"=>0, "intfrr"=>0, "mtc2013"=>19, "tansaku"=>0},
                   "week_three" => {"an_ju"=>0, "armandofox"=>10, "francis"=>0, "intfrr"=>0, "mtc2013"=>0, "tansaku"=>0},
                   "week_two" => {"an_ju"=>0, "armandofox"=>5, "francis"=>0, "intfrr"=>0, "mtc2013"=>2, "tansaku"=>10}}}
  context '#raw_data' do
    it 'fetches raw data' do
      metric = ProjectMetricSlackTrends.new(channel: 'projectscope', token: ENV["SLACK_API_TOKEN"])
      metric.refresh
      expect(metric.raw_data).to eq(raw_data)
    end
  end

end