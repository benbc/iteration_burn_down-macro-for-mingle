require "rspec"
require "../../lib/iteration_burn_down_macro"

describe "burn down parameter" do
  before do
    @parameters = {}
    @burn_down_macro = IterationBurnDownMacro.new(@parameters, nil, nil)
  end

  subject { @burn_down_macro }

  describe "date accepted property" do
    subject { @burn_down_macro.date_accepted_property }

    context "when using default" do
      it { should == 'date_accepted' }
    end

    context "when setting as parameter" do
      before { @parameters['date_accepted'] = 'accepted_on' }
      it { should == 'accepted_on' }
    end

  end

  describe "date accepted property" do
    subject { @burn_down_macro.estimate_property }

    context "when using default" do
      it { should == 'story_points' }
    end

    context "when setting as parameter" do
      before { @parameters['story_points'] = 'planning_estimate' }
      it { should == 'planning_estimate' }
    end

  end

  describe "field conversion" do
    subject { @burn_down_macro.parameter_to_field 'date_accepted' }
    it { should == 'Date Accepted'}
  end

end