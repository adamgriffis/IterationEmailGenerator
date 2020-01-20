require 'rest-client'
require 'YAML'
require 'JSON'
require "csv"

class Generator
  API_KEY = 'API_KEY'
  YEAR = '2019'
  PROACTIVE_LABEL_NAME = 'proactive'
  REACTIVE_LABEL_NAME = 'reactive'
  NON_PRODUCT_LABEL_NAME = 'Non-product'
  ACCOUNT_CUSTOMIZATION_LABEL_NAME = 'Account Customization'
  STORY_TYPE_BUG = 'bug'
  STORY_TYPE_CHORE = 'chore'
  IN_QA_NAME = 'In QA'
  COMPLETED_NAME = 'Completed'  


  BASE_URL = 'https://api.clubhouse.io/api/v3/'

  def api_key
    config = YAML::load(File.open('config/application.yml'))

    config[API_KEY]
  end

  def base_params
    {token: api_key}
  end

  def get_workflows
    response = RestClient::get BASE_URL + 'workflows', {params: base_params}

    JSON.parse(response.body)
  end

  def get_workflow_states
    get_workflows.find {|wf| wf['name'] == 'Development'}['states']
  end

  def workflow_states
    @states ||= get_workflow_states
  end

  def get_iterations
    response = RestClient::get BASE_URL + 'iterations', {params: base_params}

    JSON.parse(response.body)
  end

  def get_iteration(iteration_name)
    iterations = get_iterations

    iterations.find { |itr| itr['name'] == iteration_name}
  end

  def get_iteration_stories(iteration_name)
    iteration = get_iteration(iteration_name)

    iteration_id = iteration['id']

    params = base_params

    params.merge!({iteration_id: iteration_id})

    response = RestClient::post BASE_URL + 'stories/search', params

    JSON.parse(response.body)
  end

  def get_release_stories(release_name)
    params = base_params

    params.merge!({label_name: "Release #{release_name}"})

    response = RestClient::post BASE_URL + 'stories/search', params

    JSON.parse(response.body)
  end

  def workflow_state_string(story)
    state_id = story['workflow_state_id']

    state = workflow_states.find { |st| st['id'] == state_id}

    state['name']
  end

  def point_string(story)
    if story['story_type'] == STORY_TYPE_BUG 
      return '-'
    else
      return story['estimate']
    end
  end

  def includes_label?(story, label_name)
    story['labels'].map {|label| label['name'] }.include?(label_name)
  end

  def issue_type(story)
    if story['story_type'] == STORY_TYPE_CHORE
      if includes_label?(story, ACCOUNT_CUSTOMIZATION_LABEL_NAME)
        return "Account Customization"
      end

      return "Chore"
    elsif story['story_type'] == STORY_TYPE_BUG
      return "Bug"
    else

      if includes_label?(story, NON_PRODUCT_LABEL_NAME)
        return "Non-product Story"
      elsif includes_label?(story, REACTIVE_LABEL_NAME)
        return "Reactive Story"
      else
        return "Proactive Story"
      end
    end
  end

  def external_links(story)
    urls = story['external_tickets'].map { |ticket| ticket['external_url'] }

    urls.map { |link| "<a href='#{link}'>#{link}</a>" }.join("<br/>")
  end

  def external_links_plain(story)
    urls = story['external_tickets'].map { |ticket| ticket['external_url'] }

    urls.map { |link| link }.join("\n")
  end

  def generate_iteration_table_body(stories)
    result = ''

    stories.each do |story|
      result += <<-HTML
        <tr>
          <td>CH-#{story['id']}</td>
          <td>#{issue_type(story)}</td>
          <td>#{story['name']}</td>
          <td>#{workflow_state_string(story)}</td>
          <td>#{external_links(story)}</td>
          <td>#{point_string(story)}</td>
        </tr>
      HTML
    end

    return result
  end

  def generate_iteration_table(stories)


    result = <<-HTML
      <table class="table table-striped table-bordered table-sm text-left">
        <thead>
          <tr> 
            <th width="15%">
              Number
            </th>
            <th width="15%">
              Type
            </th>
            <th width="20%">
              Name
            </th>
            <th width="15%">
              Status
            </th>
            <th width="20%">
              External <br/>
              Tickets
            </th>
            <th width="15%">
              Points
            </th>
          </tr>
        </thead>
        <tbody>
          #{generate_iteration_table_body(stories)}
        </tbody>
      </table>
    HTML
  end

  def generate_iteration_email(sprint)
    
    stories = get_iteration_stories(sprint)

    result = <<-HTML
    <html>
      <head>
        <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css" integrity="sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO" crossorigin="anonymous">
      </head>
      <body>
        <p>This is the tentative story list for this iteration. Please do not treat this as an absolute list of features that will be in the next release, but instead a guide for what we are working on now and hope to have in the next release or two. If you have a hard deadline or an issue is a blocker, please talk to development in #product.</p>

        #{generate_iteration_table(stories)}
      </body>
    </html>

    HTML
  end

  def create_story_csv(release, stories)
    CSV.open("releases/#{release}-stories.csv", "wb",
      write_headers: true,
      headers: ["Link", "Story #", "Name", "Release", "External Tickets"]) do |csv|
        stories.each do |story|
          csv << [
            story['app_url'],
            "CH-#{story['id']}",
            story['name'],
            release,
            external_links_plain(story)
          ]
        end
    end

    puts "Stories CSV generated at releases/#{release}-stories.csv"
  end

  def create_bugs_csv(release, bugs)
    CSV.open("releases/#{release}-bugs.csv", "wb",
      write_headers: true,
      headers: ["link", "issue_number", "name", "release", "exeternal_tickets"]) do |csv|
        bugs.each do |story|
          csv << [
            story['app_url'],
            "CH-#{story['id']}",
            story['name'],
            release,
            external_links_plain(story)
          ]
        end
    end

    puts "Bugs CSV generated at releases/#{release}-bugs.csv"
  end

  def generate_release_csvs(release)
    all_stories = get_release_stories(release)

    stories = all_stories.select { |story| story['story_type'] != STORY_TYPE_BUG }
    bugs = all_stories.select { |story| story['story_type'] == STORY_TYPE_BUG }

    create_story_csv(release, stories)
    create_bugs_csv(release, bugs)
  end
end

command = ARGV[0]

if ARGV[0] == 'Sprint'
  sprint = "Sprint #{ARGV[1]}"
  generator = Generator.new
  path = "sprints/sprint-plan-#{ARGV[1]}.html"
  html = generator.generate_iteration_email(sprint)
  File.open(path, 'w') { |file| file.write(html) }
  system %{open "#{path}"} 
  puts "======================================================================================"
  puts "=                      Done Generating Sprint HTML                                   ="
  puts "======================================================================================"
end

if ARGV[0] == 'Release'
  release = ARGV[1]
  generator = Generator.new
  generator.generate_release_csvs(release)
  puts "======================================================================================"
  puts "=                      Done Generating Release CSVs                                  ="
  puts "======================================================================================"
end