require "date"

class ReleaseMetrics
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
    @parameter_defaults = Hash.new { |h, k| h[k]=k }
    @parameter_defaults['iteration'] = lambda { @project.value_of_project_variable('Current Iteration') }
    @parameter_defaults['release'] = lambda { @project.value_of_project_variable('Current Release') }
  end

  def execute
    begin
      iterations = completed_iterations

      average_velocity = average_velocity last_3_iterations(iterations)
      all_iter_velocity = average_velocity iterations
      best_velocity = best_velocity_for iterations
      worst_velocity = worst_velocity_for iterations

      remaining_stories = incomplete_stories iterations
      remaining_story_points = story_points_for remaining_stories
      last_end_date = last_iteration_end_date iterations[0]
      iter_length = iteration_length_in_days iterations[0]

      remaining_iters_for_avg = remaining_iterations(average_velocity, remaining_story_points)
      remaining_iter_for_all_velocity = remaining_iterations(all_iter_velocity, remaining_story_points)
      remaining_iters_for_best = remaining_iterations(best_velocity, remaining_story_points)
      remaining_iters_for_worst = remaining_iterations(worst_velocity, remaining_story_points)

      avg_end_date = expected_completion_date_for last_end_date, iter_length, remaining_iters_for_avg
      all_avg_end_date = expected_completion_date_for last_end_date, iter_length, remaining_iter_for_all_velocity
      best_end_date = expected_completion_date_for last_end_date, iter_length, remaining_iters_for_best
      worst_end_date = expected_completion_date_for last_end_date, iter_length, remaining_iters_for_worst

      empty_column_header = "%{color:#EEEEEE}-%"

      <<-HTML
    h2. Metrics for #{release_parameter}

    |_. Current Iteration | #{iteration_parameter} |_. #{empty_column_header} |_. Estimated Completion <br> of #{release_parameter} <br> Based on ... |_. Required <br> Iterations |_. Calculated End Date <br> Based on #{iter_length} Day Iterations |
    |_. Average Velocity <br> (last 3 iterations) | #{"%.2f" % average_velocity} |_. #{empty_column_header}  | Average velocity of <br> last 3 iterations (#{"%.2f" % average_velocity}) | #{remaining_iters_for_avg} | #{avg_end_date} |
    |_. Completed Iterations | #{iterations.length} |_. #{empty_column_header}  |Average velocity of <br> all iterations (#{all_iter_velocity}) | #{remaining_iter_for_all_velocity} | #{all_avg_end_date} |
    |_. Remaining Story Points <br> (includes all stories not <br> in a past iteration) | #{remaining_story_points} |_. #{empty_column_header}  | Best velocity (#{best_velocity}) | #{remaining_iters_for_best} | #{best_end_date} |
    |_. Iteration Length <br> (calculated based on <br> last iteration completed) | #{iter_length} days |_. #{empty_column_header}  | Worst velocity (#{worst_velocity}) | #{remaining_iters_for_worst} | #{worst_end_date} |

    <br>
      HTML
    rescue Exception => e
      <<-ERROR
    h2. Release Metrics:

    "An Error occurred: #{e}"

      ERROR
    end
  end

  def remaining_iterations(velocity, remaining_story_points)
    (remaining_story_points/velocity).ceil
  end

  def expected_completion_date_for(last_end_date, iter_length, remaining_iterations)
    last_end_date + (iter_length * remaining_iterations - 1)
  end

  def story_points_for(stories)
    stories.inject(0) { |total, story| story["#{story_points_parameter}"] ? total + story["#{story_points_parameter}"].to_i : total }
  end

  def last_iteration_end_date(most_recent_iter)
    Date.parse(most_recent_iter[end_date_parameter])
  end

  def iteration_length_in_days(most_recent_iter)
    start_date = Date.parse(most_recent_iter[start_date_parameter])
    end_date = last_iteration_end_date(most_recent_iter)
    (end_date - start_date) + 1
  end

  def iteration_names(iterations)
    iterations.collect { |iter| "'#{iter['name']}'" }.join ","
  end

  def last_3_iterations(iterations)
    iterations.first(3)
  end

  def best_velocity_for(iterations)
    iterations.inject(1) { |best, iter| iter[velocity_parameter] && iter[velocity_parameter].to_i > best ? iter[velocity_parameter].to_i : best }.to_f
  end

  def worst_velocity_for(iterations)
    iterations.inject(best_velocity_for(iterations)) do |worst, iter|
      iter_velocity = iter[velocity_parameter].to_i
      iter_velocity && iter_velocity < worst && iter_velocity > 0 ? iter_velocity : worst
    end.to_f
  end

  def average_velocity(iterations)
    total_velocity = iterations.inject(0) { |total, hash| hash[velocity_parameter] ? total + hash[velocity_parameter].to_i : total }
    total_velocity / (iterations.length * 1.0)
  end

  def completed_iterations
    begin
      data_rows = @project.execute_mql(
          "SELECT name, '#{start_date_field}', '#{end_date_field}', #{velocity_field} WHERE Type = iteration AND '#{end_date_field}' < today AND release = '#{release_name}' ORDER BY '#{end_date_field}' desc")
      raise "##{release_parameter} is not a valid release" if data_rows.empty?
      data_rows
    rescue Exception => e
      raise "[error retrieving completed iterations for #{release_parameter}: #{e}]"
    end
  end

  def incomplete_stories(iterations)
    iter_names = iteration_names iterations
    begin
      @project.execute_mql(
          "SELECT '#{story_points_field}' WHERE Type = story AND release = '#{release_name}' AND NOT iteration in (#{iter_names})")
    rescue Exception => e
      raise "[error retrieving stories for release '#{release_parameter}': #{e}]"
    end
  end

  def release_name
    match_data = /#\d+ (.*)/.match(release_parameter)
    if  match_data
      match_data[1]
    else
      'Unknown'
    end
  end

  def release_number
    match_data = /#(\d+).*/.match(release_parameter)
    if  match_data
      match_data[1].to_i
    else
      'Unknown'
    end
  end

  def parameter_to_field(param)
    param.gsub('_', ' ').scan(/\w+/).collect { |word| word.capitalize }.join(' ')
  end

  def can_be_cached?
    false # if appropriate, switch to true once you move your macro to production
  end

  #noinspection RubyUnusedLocalVariable
  def method_missing(method_sym, *arguments, &block)
    if method_sym.to_s =~ /^(.*)_field$/
      parameter_to_field(send "#{$1}_parameter".to_s)
    elsif  method_sym.to_s =~ /^(.*)_parameter$/
      param = @parameters[$1] || @parameter_defaults[$1]
      if param.respond_to? :call
        param.call
      else
        param
      end
    else
      super
    end
  end

  def respond_to?(method_sym, include_private = false)
    puts 'in respond to'
    if method_sym.to_s =~ /^(.*)_field$/
      true
    elsif method_sym.to_s =~ /^(.*)_parameter$/
      true
    else
      super
    end
  end

end

