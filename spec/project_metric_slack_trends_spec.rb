require 'project_metric_slack_trends'

describe ProjectMetricSlackTrends, :vcr do

  let(:raw_data) { nil }
  let(:svg) { File.read './spec/data/sample.svg' }
  let(:subject) { ProjectMetricSlackTrends.new({channel: 'projectscope', token: ENV["SLACK_API_TOKEN"]}, raw_data) }
  let(:svg_wso) { File.read './spec/data/wso_sample.svg' }

  before {Time.stub_chain(:zone, :now){Time.new(2016,9,7,1,12,39,0)}}

  describe '::credentials' do
    it 'contains exactly token and channel' do
      expect(described_class.credentials).to contain_exactly('token','channel')
    end
  end

  describe '#refresh' do

    context 'meaningful raw_data' do
      let(:raw_data) { {"week_one"=>{"mtc2013"=>8, "tansaku"=>9, "jinksy"=>0, "marouen"=>2, "ksteph"=>1, "an_ju"=>2, "armandofox"=>2,
                                     "marianmosley"=>0, "nickn"=>0, "arun1595"=>0, "intfrr"=>0, "slackbot"=>0, "0"=>0, "1"=>0, "2"=>3,
                                     "3"=>5, "4"=>15, "5"=>1, "6"=>0},
                        "week_two"=>{"mtc2013"=>34, "tansaku"=>41, "jinksy"=>0, "marouen"=>0, "ksteph"=>0, "an_ju"=>0, "armandofox"=>0,
                                     "marianmosley"=>1, "nickn"=>0, "arun1595"=>0, "intfrr"=>0, "slackbot"=>0, "0"=>0, "1"=>0, "2"=>2,
                                     "3"=>1, "4"=>32, "5"=>41, "6"=>0},
                        "week_three"=>{"mtc2013"=>119, "tansaku"=>128, "jinksy"=>0, "marouen"=>0, "ksteph"=>0, "an_ju"=>2, "armandofox"=>15,
                                       "marianmosley"=>0, "nickn"=>1, "arun1595"=>2, "intfrr"=>1, "slackbot"=>1, "0"=>0, "1"=>144, "2"=>67,
                                       "3"=>2, "4"=>17, "5"=>38, "6"=>1}} }
      it 'fetches raw data' do
        subject.refresh
        expect(subject.raw_data).to eq(raw_data)
      end
    end

    context 'made up raw_data' do
      let(:raw_data) { {"week_one" => {"an_ju" => 10, "armandofox" => 20, "francis" => 20, "intfrr" => 5, "mtc2013" => 19, "tansaku" => 0, "0" => 0, "1" => 10, "2" => 40, "3" => 0, "4" => 1, "5" => 0, "6" => 0},
                        "week_three" => {"an_ju" => 0, "armandofox" => 10, "francis" => 0, "intfrr" => 12, "mtc2013" => 0, "tansaku" => 0, "0" => 0, "1" => 0, "2" => 0, "3" => 8, "4" => 0, "5" => 0, "6" => 0},
                        "week_two" => {"an_ju" => 0, "armandofox" => 5, "francis" => 0, "intfrr" => 0, "mtc2013" => 2, "tansaku" => 10, "0" => 1, "1" => 0, "2" => 0, "3" => 0, "4" => 15, "5" => 1, "6" => 0}} }

      let(:svg_two) { File.read './spec/data/sample_two.svg' }

      it 'unsets score' do
        expect(subject.score).to eq 0.42148777348777344
        subject.refresh
        expect(subject.score).to eq 0.32200793650793647
      end

      it 'unsets image' do
        expect(subject.image).to eq svg_two
        subject.refresh
        expect(subject.image).to eq svg
      end
    end
  end

  describe '#raw_data' do
    let(:raw_data) { {"week_one" => {"an_ju" => 0, "armandofox" => 0, "francis" => 0, "intfrr" => 0, "mtc2013" => 19, "tansaku" => 0, "0" => 0, "1" => 0, "2" => 0, "3" => 0, "4" => 1, "5" => 0, "6" => 0},
                      "week_three" => {"an_ju" => 0, "armandofox" => 10, "francis" => 0, "intfrr" => 0, "mtc2013" => 0, "tansaku" => 0, "0" => 0, "1" => 0, "2" => 0, "3" => 8, "4" => 0, "5" => 0, "6" => 0},
                      "week_two" => {"an_ju" => 0, "armandofox" => 5, "francis" => 0, "intfrr" => 0, "mtc2013" => 2, "tansaku" => 10, "0" => 1, "1" => 0, "2" => 0, "3" => 0, "4" => 5, "5" => 1, "6" => 0}} }
    it 'sets raw_data in constructor' do
      expect(ProjectMetricSlackTrends.new({channel: 'projectscope', token: ENV["SLACK_API_TOKEN"]}, raw_data).raw_data).to eq raw_data
    end
  end

  describe '#score' do
    it 'computes a score' do
      expect(ProjectMetricSlackTrends.new(channel: 'projectscope', token: ENV["SLACK_API_TOKEN"]).score).to eq 0.32200793650793647
    end
  end

  describe '#image' do
    it 'constructs a graph' do
      expect(ProjectMetricSlackTrends.new(channel: 'projectscope', token: ENV["SLACK_API_TOKEN"]).image).to eq svg
    end
  end

  describe "#raw_data=" do
    let(:raw_data_outside_constructor) { {"week_one" => {"an_ju" => 10, "armandofox" => 20, "francis" => 20, "intfrr" => 5, "mtc2013" => 19, "tansaku" => 0, "0" => 0, "1" => 10, "2" => 40, "3" => 0, "4" => 1, "5" => 0, "6" => 0},
                                          "week_three" => {"an_ju" => 0, "armandofox" => 10, "francis" => 0, "intfrr" => 12, "mtc2013" => 0, "tansaku" => 0, "0" => 0, "1" => 0, "2" => 0, "3" => 8, "4" => 0, "5" => 0, "6" => 0},
                                          "week_two" => {"an_ju" => 0, "armandofox" => 5, "francis" => 0, "intfrr" => 0, "mtc2013" => 2, "tansaku" => 10, "0" => 1, "1" => 0, "2" => 0, "3" => 0, "4" => 15, "5" => 1, "6" => 0}} }
    let(:svg_two) { File.read './spec/data/sample_two.svg' }

    it 'sets raw_data when setter is called' do
      subject.raw_data = raw_data_outside_constructor
      expect(subject.raw_data).to eq raw_data_outside_constructor
    end

    it 'unsets score when called' do
      subject.raw_data = raw_data_outside_constructor
      expect(subject.score).to eq 0.42148777348777344
    end

    it 'unsets image when called' do
      subject.raw_data = raw_data_outside_constructor
      expect(subject.image).to eq svg_two
    end
  end

  context 'WebSiteOne' do
    it 'can handle the websiteone data' do
      metric = ProjectMetricSlackTrends.new(channel: 'websiteone', token: ENV["SLACK_API_TOKEN"])
      metric.refresh
      expect(metric.image).to eq(svg_wso)
    end
    it 'computes a proper score' do
      metric = ProjectMetricSlackTrends.new(channel: 'websiteone', token: ENV["SLACK_API_TOKEN"])
      metric.refresh
      expect(metric.score).to eq(0.4637265745007681)
    end
  end

end