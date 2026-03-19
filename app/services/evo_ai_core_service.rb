# frozen_string_literal: true

class EvoAiCoreService
  include HTTParty

  # Use Core AI Service directly
  base_uri ENV.fetch('EVO_AI_CORE_SERVICE_URL', 'http://localhost:5555')

  class << self
    def build_headers(request_headers = nil)
      # Get current user and account from thread context or MCP thread storage
      current_user = Current.user || Thread.current[:mcp_authenticated_user]
      current_account = Current.account || Thread.current[:mcp_current_account]
      
      
      headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
      
      # Pass the current user's authentication token to Core AI Service
      if current_user && current_account
        if request_headers
          # Handle different types of headers (Rails request headers or simple hash from MCP tools)
          if request_headers.respond_to?(:env)
            # Rails request headers (ActionDispatch::Http::Headers)
            headers_hash = request_headers.env
            
            # Pass through OAuth headers
            ['Authorization', 'X-User-Id', 'X-Account-Id'].each do |header|
              value = headers_hash[header] || headers_hash[header.upcase] || headers_hash["HTTP_#{header.upcase.gsub('-', '_')}"]
              headers[header] = value if value.present?
            end
            
            # Also try Authorization header
            auth_header = headers_hash['Authorization'] || headers_hash['HTTP_AUTHORIZATION']
            headers['Authorization'] = auth_header if auth_header.present?
            
            # Try api_access_token headers for access token auth
            api_token = headers_hash['api_access_token'] || headers_hash['HTTP_API_ACCESS_TOKEN']
            headers['api_access_token'] = api_token if api_token.present?
          else
            # Simple hash from MCP tools - use directly
            request_headers.each do |key, value|
              headers[key] = value if value.present?
            end
          end
        end
        
        # Add X-Account-Id and X-User-Id if not already present from MCP headers
        headers['X-Account-Id'] ||= current_account.id.to_s
        headers['X-User-Id'] ||= current_user.id.to_s
      end
      
      headers.compact
    end
    
    # Legacy method for backward compatibility - renamed to avoid HTTParty conflicts
    def legacy_headers(request_headers = nil)
      build_headers(request_headers)
    end
    
    # HTTParty might be calling this automatically - redirect to build_headers
    def headers
      build_headers
    end
    
    def handle_response(response)
      # Return the complete response from evo-ai-core-service
      # The service already returns standardized format: { success, data, message, meta }
      parsed = response.parsed_response
      
      case response.code
      when 200, 201
        parsed = response.parsed_response
        # Extract payload if it exists (Evolution API format)
        parsed.dig('data') || parsed
      when 204
        nil
      when 400
        raise StandardError, response.parsed_response['error'] || 'Bad Request'
      when 401
        raise StandardError, 'Unauthorized'
      when 404
        raise ActiveRecord::RecordNotFound
      when 422
        raise StandardError, response.parsed_response['error'] || 'Unprocessable Entity'
      else
        raise StandardError, "Unexpected response: #{response.code}"
      end
    end
    
    # Agents endpoints (Core AI Service)
    def list_agents(params = {}, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      Rails.logger.info "EvoAiCoreService.list_agents - Current Account: #{current_account&.id}, Params: #{params}"
      return {} unless current_account

      url = "/api/v1/agents"
      Rails.logger.info "EvoAiCoreService.list_agents - Making request to: #{url}"
      
      response = get(url, {
        query: params.merge(account_id: current_account.id),
        headers: build_headers(request_headers)
      })
      
      Rails.logger.info "EvoAiCoreService.list_agents - Response code: #{response.code}, Body: #{response.body[0..500]}"
      handle_response(response)
    end
    
    def get_agent(agent_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/agents/#{agent_id}"
      response = get(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def create_agent(agent_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/agents"
      response = post(url, {
        body: agent_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def update_agent(agent_id, agent_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/agents/#{agent_id}"
      response = put(url, {
        body: agent_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def delete_agent(agent_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return unless current_account

      url = "/api/v1/agents/#{agent_id}"
      response = delete(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def sync_evolution_bot(agent_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/agents/#{agent_id}/sync_evolution"
      response = post(url, {
        body: { account_id: current_account.id }.to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def assign_folder(agent_id, folder_id)
      current_account = Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/accounts/#{current_account.id}/ai_agents/#{agent_id}/assign_folder"
      response = put(url, {
        body: { folder_id: folder_id }.to_json,
        headers: legacy_headers
      })
      handle_response(response)
    end
    
    def get_share_agent(agent_id)
      current_account = Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/accounts/#{current_account.id}/ai_agents/#{agent_id}/share"
      response = get(url, {
        headers: legacy_headers
      })
      handle_response(response)
    end
    
    def get_shared_agent(agent_id)
      current_account = Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/accounts/#{current_account.id}/ai_agents/#{agent_id}/shared"
      response = get(url, {
        headers: legacy_headers
      })
      handle_response(response)
    end
    
    # Folders endpoints (using Core AI Service)
    def list_folders(params = {}, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/folders"
      response = get(url, {
        query: params.merge(account_id: current_account.id),
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def get_folder(folder_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/folders/#{folder_id}"
      response = get(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def create_folder(folder_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/folders"
      response = post(url, {
        body: folder_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def update_folder(folder_id, folder_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/folders/#{folder_id}"
      response = put(url, {
        body: folder_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def delete_folder(folder_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return unless current_account

      url = "/api/v1/folders/#{folder_id}"
      response = delete(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    # API Keys endpoints (using Core AI Service)
    def list_api_keys(params = {}, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/agents/apikeys"
      response = get(url, {
        query: params.merge(account_id: current_account.id),
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def get_api_key(key_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/agents/apikeys/#{key_id}"
      response = get(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def create_api_key(api_key_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/agents/apikeys"
      response = post(url, {
        body: api_key_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def update_api_key(key_id, api_key_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/agents/apikeys/#{key_id}"
      response = put(url, {
        body: api_key_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def delete_api_key(key_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return unless current_account

      url = "/api/v1/agents/apikeys/#{key_id}"
      response = delete(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    # MCP Servers endpoints (using Core AI Service)
    def list_mcp_servers(params = {}, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/mcp-servers"
      response = get(url, {
        query: params.merge(account_id: current_account.id),
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def get_mcp_server(server_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/mcp-servers/#{server_id}"
      response = get(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def create_mcp_server(server_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/mcp-servers"
      response = post(url, {
        body: server_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def update_mcp_server(server_id, server_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/mcp-servers/#{server_id}"
      response = put(url, {
        body: server_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def delete_mcp_server(server_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return unless current_account

      url = "/api/v1/mcp-servers/#{server_id}"
      response = delete(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    # Custom Tools endpoints (using Core AI Service)
    def list_custom_tools(params = {}, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-tools"
      response = get(url, {
        query: params.merge(account_id: current_account.id),
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def get_custom_tool(tool_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-tools/#{tool_id}"
      response = get(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def create_custom_tool(tool_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-tools"
      response = post(url, {
        body: tool_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def update_custom_tool(tool_id, tool_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-tools/#{tool_id}"
      response = put(url, {
        body: tool_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def delete_custom_tool(tool_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return unless current_account

      url = "/api/v1/custom-tools/#{tool_id}"
      response = delete(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def test_custom_tool(tool_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-tools/#{tool_id}/test"
      response = get(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    # Custom MCP Servers endpoints (using Core AI Service)
    def list_custom_mcp_servers(params = {}, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-mcp-servers"
      response = get(url, {
        query: params.merge(account_id: current_account.id),
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def get_custom_mcp_server(server_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-mcp-servers/#{server_id}"
      response = get(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def create_custom_mcp_server(server_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-mcp-servers"
      response = post(url, {
        body: server_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def update_custom_mcp_server(server_id, server_data, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-mcp-servers/#{server_id}"
      response = put(url, {
        body: server_data.merge(account_id: current_account.id).to_json,
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def delete_custom_mcp_server(server_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return unless current_account

      url = "/api/v1/custom-mcp-servers/#{server_id}"
      response = delete(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
    
    def test_custom_mcp_server(server_id, request_headers = nil)
      current_account = Current.account || Thread.current[:mcp_current_account]
      return {} unless current_account

      url = "/api/v1/custom-mcp-servers/#{server_id}/test"
      response = get(url, {
        query: { account_id: current_account.id },
        headers: build_headers(request_headers)
      })
      handle_response(response)
    end
  end
end