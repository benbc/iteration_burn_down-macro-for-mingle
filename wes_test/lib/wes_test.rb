require "date"

class WesTest
  MON = 1
  TUE = 2
  WED = 3
  THU = 4
  FRI = 5

  WEEKDAYS = [MON, TUE, WED, THU, FRI]

  def initialize(parameters, project, current_user)
    @parameters = parameters
    @project = project
    @current_user = current_user
  end

  def execute
#    @parameters.each {|key, value| html << "param: '#{key} = #{value}'<br>"}

    date_range = iteration_date_range
    weekdays = weekdays_for(date_range)
    stories = story_info
    total_story_points = calculate_total_story_points stories
    <<-HTML
    h2. Iteration ##{@parameters['current_iteration']} Burndown:

    weekdays = #{weekdays} <br>
    total story points #{total_story_points} <br>
    story info #{story_info.to_s}

    <img src='https://chart.googleapis.com/chart?cht=lxy&chs=600x400&chds=a&chtt=Iteration%20Burndown&chls=1,6,6&chxt=x,y&chxr=1,0,11,1&chma=50,0,0,50&chdl=Ideal%20Line|Burndown&chco=00FF00,FF0000&chd=t:0,1,2,3,4|11,8.25,5.5,2.75,0|0,1,2,3,4|11,11,6,3,0&chxl=0:|#{weekdays}|1:||1|2|3|4|'></img>
    HTML
  end

  def calculate_total_story_points(stories)
    stories.inject(0) {|total, hash| hash['planning_estimate'] ? total + hash['planning_estimate'].to_i : total}
  end

  def story_info
    begin
      iteration = /#\d+ (.*)/.match(current_iteration)[1]
      data_rows = @project.execute_mql(
          "SELECT 'Planning Estimate', 'Accepted On' WHERE type is Story AND Iteration = '#{iteration}'")
      data_rows.each {|hash| hash.update(hash) {|key, value| (key == 'accepted_on' && value) ? Date.parse(value) : value } }
    rescue Exception
      "[error retrieving story info for iteration '#{iteration}': #{$!}]"
    end
  end

  def iteration_date_range
    begin
      data_rows = @project.execute_mql("SELECT 'Start Date', 'End Date' WHERE Number = #{iteration}")
      throw "##{iteration} is not a valid iteration" if data_rows.empty?
      Date.parse(data_rows[0]['start_date'])..Date.parse(data_rows[0]['end_date'])
    rescue Exception
      throw "error getting data for iteration #{iteration}: #{$!}"
    end
  end

  def weekdays_for(date_range)
    weekdays = ((date_range.begin)..(date_range.end)).select { |day| WEEKDAYS.include? day.wday }
    weekdays.collect { |day| "#{day.month}-#{day.day}" }.join('|')
  end

  def current_iteration
    @project.value_of_project_variable('Current Iteration')
  end

  def iteration
    /#(\d+).*/.match(current_iteration)[1].to_i
  end

  def can_be_cached?
    false # if appropriate, switch to true once you move your macro to production
  end

end

