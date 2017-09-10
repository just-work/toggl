require 'net/http'
require 'json'

# Responsible for fetching matching Toggl entries
class TogglAPIService

  def initialize(toggl_api_key, workspaces)
    @toggl_api_key = toggl_api_key
    @toggl_workspace = workspaces.split(',').map(&:strip) if workspaces.present?
  end

  def get_toggl_entries
    workspace_ids = []

    if @toggl_workspace.present?
      wid_response = get_latest_toggl_entries_api_response('workspaces')
      workspace_ids = wid_response.select{|k| @toggl_workspace.include?(k['name'])}.map{|k| k['id']}
    end

    # if user has setup workspace, use entries for those workspaces. If no workspace is setup, use all
    get_latest_toggl_entries_api_response('time_entries').map { |entry|
      if entry["description"] =~ /\s*#(\d+)\s*/ && !entry["stop"].nil? && !entry["stop"].empty? &&
      (@toggl_workspace.blank? || workspace_ids.include?(entry['wid']))
        
        activity_name = nil
        if entry.has_key?("tags") and not entry["tags"].empty?
          activity_name = entry["tags"].first
        end         

        TogglAPIEntry.new(entry["id"],
                          $1.to_i,
                          Time.parse(entry["start"]),
                          entry["duration"].to_f / 3600,
                          entry["description"].gsub(/\s*#\d+\s*/, ''),
                          activity_name
                          )
      else
        nil
      end
    }.compact
  end

protected

  def get_latest_toggl_entries_api_response(target)
    uri = URI.parse "https://www.toggl.com/api/v8/#{target}"
    uri.query = URI.encode_www_form({ :user_agent => 'Redmine Toggl Client' })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    req = Net::HTTP::Get.new(uri.request_uri)
    req.basic_auth @toggl_api_key, 'api_token'

    res = http.request(req)
    JSON.parse(res.body)
  end

end
